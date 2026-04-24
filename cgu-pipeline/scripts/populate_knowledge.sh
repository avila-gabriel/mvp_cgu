#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
knowledge_dir="${KNOWLEDGE_DIR:-"$repo_root/../.knowledge"}"
cache_dir="$knowledge_dir/.cache"
cache_key_file="$cache_dir/packages.sha256"
cache_targets_file="$cache_dir/targets.txt"
gleam_docs_repo="https://github.com/gleam-lang/website.git"
gleam_docs_target_name="gleam"
gleam_docs_cache_key="gleam-website-documentation-v1"

mkdir -p "$knowledge_dir"
mkdir -p "$cache_dir"

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT INT TERM

packages_file="$tmp_dir/packages.txt"
package_versions_file="$tmp_dir/package_versions.tsv"

find "$repo_root" -mindepth 2 -maxdepth 2 -name gleam.toml -print \
  | sort \
  | while IFS= read -r gleam_toml; do
      awk '
        /^\[dependencies\]$/ { in_deps = 1; next }
        /^\[dev_dependencies\]$/ { in_deps = 1; next }
        /^\[/ { in_deps = 0; next }
        in_deps && /^[[:space:]]*#/ { next }
        in_deps && /^[[:space:]]*$/ { next }
        in_deps && $0 ~ /=/ && $0 !~ /path[[:space:]]*=/ {
          line = $0
          sub(/=.*/, "", line)
          gsub(/[[:space:]"]/, "", line)
          if (line != "") print line
        }
      ' "$gleam_toml"
    done \
  | sort -u > "$packages_file"

package_count="$(wc -l < "$packages_file" | tr -d ' ')"
echo "Found $package_count package names from first-level Gleam projects."

version_for_package() {
  local package="$1"
  local version=""

  while IFS= read -r manifest; do
    version="$(
      awk -v package="$package" '
        $0 ~ "name = \"" package "\"" && $0 ~ /version = "/ {
          line = $0
          sub(/.*version = "/, "", line)
          sub(/".*/, "", line)
          print line
          exit
        }
      ' "$manifest"
    )"

    if [ -n "$version" ]; then
      printf '%s\n' "$version"
      return 0
    fi
  done < <(find "$repo_root" -mindepth 2 -maxdepth 2 -name manifest.toml -print | sort)
}

while IFS= read -r package; do
  [ -n "$package" ] || continue
  version="$(version_for_package "$package")"
  printf '%s\t%s\n' "$package" "${version:-unknown}"
done < "$packages_file" > "$package_versions_file"

cache_key="$(
  {
    cat "$package_versions_file"
    printf '%s\t%s\n' "$gleam_docs_target_name" "$gleam_docs_cache_key"
  } | sha256sum | awk '{ print $1 }'
)"

cache_is_valid() {
  [ -f "$cache_key_file" ] || return 1
  [ -f "$cache_targets_file" ] || return 1
  [ "$(cat "$cache_key_file")" = "$cache_key" ] || return 1

  while IFS= read -r target_name; do
    [ -n "$target_name" ] || continue
    [ -d "$knowledge_dir/$target_name" ] || return 1
  done < "$cache_targets_file"

  return 0
}

if cache_is_valid; then
  echo "Knowledge cache is current at $knowledge_dir"
  exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
  echo "curl is required" >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "git is required" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required" >&2
  exit 1
fi

repository_url() {
  local package="$1"
  curl -fsS "https://hex.pm/api/packages/$package" \
    | jq -r '
        [
          .meta.links.GitHub,
          .meta.links.github,
          .meta.links.Repository,
          .meta.links.repository,
          .meta.links.Source,
          .meta.links.source,
          .meta.links.Homepage,
          .meta.links.homepage
        ]
        | map(select(type == "string" and test("^https://github.com/")))
        | .[0] // empty
      '
}

repo_basename() {
  local repo_url="$1"
  local name="${repo_url%/}"
  name="${name##*/}"
  name="${name%.git}"
  printf '%s\n' "$name"
}

prune_clone() {
  local package_dir="$1"
  find "$package_dir" -mindepth 1 -maxdepth 1 \
    ! -name src \
    ! -iname 'README.md' \
    ! -name docs \
    ! -name doc \
    ! -name pages \
    ! -name examples \
    ! -name example \
    ! -name gleam.toml \
    -exec rm -rf {} +
}

populate_gleam_docs() {
  local target="$knowledge_dir/$gleam_docs_target_name"
  local clone_dir="$tmp_dir/gleam-website"

  if [ -d "$target" ]; then
    echo "Skipping Gleam documentation: already exists at $target"
    printf '%s\n' "$gleam_docs_target_name" >> "$tmp_dir/targets.txt"
    return 0
  fi

  echo "Cloning Gleam documentation from $gleam_docs_repo"
  git clone --depth 1 "$gleam_docs_repo" "$clone_dir" >/dev/null 2>&1

  if [ ! -d "$clone_dir/documentation" ]; then
    echo "Gleam website clone did not contain documentation/" >&2
    return 1
  fi

  mkdir -p "$target"
  find "$clone_dir/documentation" -mindepth 1 -maxdepth 1 \
    -exec mv {} "$target/" \;
  printf '%s\n' "$gleam_docs_target_name" >> "$tmp_dir/targets.txt"
}

populate_gleam_docs

while IFS= read -r package; do
  [ -n "$package" ] || continue

  echo "Resolving $package"
  repo_url="$(repository_url "$package")"
  if [ -z "$repo_url" ]; then
    echo "Could not find a GitHub repository link for $package on Hex" >&2
    continue
  fi

  target_name="$(repo_basename "$repo_url")"
  target="$knowledge_dir/$target_name"
  legacy_target="$knowledge_dir/$package"

  if [ -d "$target" ]; then
    echo "Skipping $package: already exists at $target"
    printf '%s\n' "$target_name" >> "$tmp_dir/targets.txt"
    continue
  fi

  if [ "$legacy_target" != "$target" ] && [ -d "$legacy_target" ]; then
    echo "Migrating $legacy_target to $target"
    mv "$legacy_target" "$target"
    printf '%s\n' "$target_name" >> "$tmp_dir/targets.txt"
    continue
  fi

  clone_dir="$tmp_dir/$package"
  echo "Cloning $package from $repo_url"
  git clone --depth 1 "$repo_url" "$clone_dir" >/dev/null 2>&1
  rm -rf "$clone_dir/.git"
  prune_clone "$clone_dir"
  mv "$clone_dir" "$target"
  printf '%s\n' "$target_name" >> "$tmp_dir/targets.txt"
done < "$packages_file"

sort -u "$tmp_dir/targets.txt" > "$cache_targets_file"
printf '%s\n' "$cache_key" > "$cache_key_file"

echo "Knowledge directory populated at $knowledge_dir"
