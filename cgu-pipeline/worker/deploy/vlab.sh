#!/usr/bin/env bash
set -e

mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

for shellrc in "$HOME/.bashrc" "$HOME/.profile" "$HOME/.bash_profile" "$HOME/.zshrc"; do
    if [ -f "$shellrc" ]; then
        if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$shellrc"; then
            echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$shellrc"
        fi
    fi
done


LESS_URL="http://archive.ubuntu.com/ubuntu/pool/main/l/less/less_590-1ubuntu0.22.04.3_amd64.deb"
TMP=$(mktemp -d)
wget -qO "$TMP/less.deb" "$LESS_URL"
dpkg -i "$TMP/less.deb" || true
rm -rf "$TMP"


FZF_URL="https://github.com/junegunn/fzf/releases/download/0.46.1/fzf-0.46.1-linux_amd64.tar.gz"
TMP=$(mktemp -d)
wget -qO "$TMP/fzf.tar.gz" "$FZF_URL"
tar -xzf "$TMP/fzf.tar.gz" -C "$TMP"
mv "$TMP"/fzf "$HOME/.local/bin/fzf"
chmod +x "$HOME/.local/bin/fzf"
rm -rf "$TMP"


GH_URL="https://github.com/cli/cli/releases/download/v2.83.1/gh_2.83.1_linux_amd64.tar.gz"
TMP=$(mktemp -d)
wget -qO "$TMP/gh.tar.gz" "$GH_URL"
tar -xzf "$TMP/gh.tar.gz" -C "$TMP"
mv "$TMP"/gh_*/bin/gh "$HOME/.local/bin/gh"
chmod +x "$HOME/.local/bin/gh"
rm -rf "$TMP"


JJ_URL="https://github.com/jj-vcs/jj/releases/download/v0.35.0/jj-v0.35.0-x86_64-unknown-linux-musl.tar.gz"
TMP=$(mktemp -d)
wget -qO "$TMP/jj.tar.gz" "$JJ_URL"
tar -xzf "$TMP/jj.tar.gz" -C "$TMP"
mv "$TMP/jj" "$HOME/.local/bin/jj"
chmod +x "$HOME/.local/bin/jj"
rm -rf "$TMP"


RG_URL="https://github.com/BurntSushi/ripgrep/releases/download/14.1.0/ripgrep-14.1.0-x86_64-unknown-linux-musl.tar.gz"
TMP=$(mktemp -d)
wget -qO "$TMP/rg.tar.gz" "$RG_URL"
tar -xzf "$TMP/rg.tar.gz" -C "$TMP"
mv "$TMP"/ripgrep-*/rg "$HOME/.local/bin/rg"
chmod +x "$HOME/.local/bin/rg"
rm -rf "$TMP"


curl -fsSL https://deb.nodesource.com/setup_lts.x | bash -
apt install -y nodejs erlang rebar3
npm i -g @openai/codex


DIRENV_DEB="http://archive.ubuntu.com/ubuntu/pool/universe/d/direnv/direnv_2.25.2-2_amd64.deb"
TMP=$(mktemp -d)
wget -qO "$TMP/direnv.deb" "$DIRENV_DEB"
dpkg -x "$TMP/direnv.deb" "$TMP/extracted"
mv "$TMP/extracted/usr/bin/direnv" "$HOME/.local/bin/direnv"
chmod +x "$HOME/.local/bin/direnv"
rm -rf "$TMP"
if ! grep -q 'eval "$(direnv hook bash)"' "$HOME/.bashrc"; then
    echo 'eval "$(direnv hook bash)"' >> "$HOME/.bashrc"
fi


GLEAM_VERSION="v1.16.0"
GLEAM_ARCHIVE="gleam-${GLEAM_VERSION}-x86_64-unknown-linux-musl.tar.gz"
GLEAM_URL="https://github.com/gleam-lang/gleam/releases/download/${GLEAM_VERSION}/${GLEAM_ARCHIVE}"
TMP=$(mktemp -d)
wget -qO "$TMP/$GLEAM_ARCHIVE" "$GLEAM_URL"
wget -qO "$TMP/$GLEAM_ARCHIVE.sha256" "$GLEAM_URL.sha256"
(cd "$TMP" && sha256sum -c "$GLEAM_ARCHIVE.sha256")
tar -xzf "$TMP/$GLEAM_ARCHIVE" -C "$TMP"
mv "$TMP/gleam" "$HOME/.local/bin/gleam"
chmod +x "$HOME/.local/bin/gleam"
rm -rf "$TMP"


NVIM_URL="https://github.com/neovim/neovim/releases/download/v0.8.3/nvim-linux64.tar.gz"
TMP=$(mktemp -d)
wget -qO "$TMP/nvim.tar.gz" "$NVIM_URL"
tar -xzf "$TMP/nvim.tar.gz" -C "$TMP"
mv "$TMP"/nvim-linux64/bin/nvim "$HOME/.local/bin/nvim"
chmod +x "$HOME/.local/bin/nvim"
rm -rf "$TMP"


wget -qO broot https://dystroy.org/broot/download/x86_64-linux/broot
chmod +x broot
mv broot "$HOME/.local/bin/"

mkdir -p "$HOME/.config/broot"
"$HOME/.local/bin/broot" --set-install-state installed || true
$HOME/.local/bin/broot --install

VERBS_FILE="$HOME/.config/broot/verbs.hjson"
if [ -f "$VERBS_FILE" ]; then
    sed -i 's/\$EDITOR/nvim/g' "$VERBS_FILE"
fi


echo "Done."
