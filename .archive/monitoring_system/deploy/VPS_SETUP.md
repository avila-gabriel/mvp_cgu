# New Ubuntu VPS

Use this on a fresh Ubuntu VPS before running any production tasks.

## Prepare The Host

1. Use Ubuntu 24.04 LTS or 22.04 LTS.
2. Point a real domain or subdomain to the VPS.
3. Open ports `22`, `80`, and `443`.

## Install Base Packages

```bash
sudo apt update
sudo apt install -y ca-certificates curl git unzip build-essential
```

## Install Docker

```bash
sudo apt remove -y docker.io docker-compose docker-compose-v2 docker-doc podman-docker containerd runc || true
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
printf "Types: deb\nURIs: https://download.docker.com/linux/ubuntu\nSuites: %s\nComponents: stable\nArchitectures: %s\nSigned-By: /etc/apt/keyrings/docker.asc\n" "$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")" "$(dpkg --print-architecture)" | sudo tee /etc/apt/sources.list.d/docker.sources >/dev/null
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
```

## Install Task

```bash
curl -1sLf 'https://dl.cloudsmith.io/public/task/task/setup.deb.sh' | sudo -E bash
sudo apt install -y task
```

## Install Node.js And npm

```bash
sudo apt install -y nodejs npm
```

## Install Gleam

```bash
GLEAM_VERSION="$(curl -fsSL https://api.github.com/repos/gleam-lang/gleam/releases/latest | sed -n 's/.*\"tag_name\": \"\\(v[^\"]*\\)\".*/\\1/p' | head -n1)"
curl -fsSL "https://github.com/gleam-lang/gleam/releases/download/${GLEAM_VERSION}/gleam-${GLEAM_VERSION}-x86_64-unknown-linux-musl.tar.gz" -o /tmp/gleam.tar.gz
tar -xzf /tmp/gleam.tar.gz -C /tmp
sudo install /tmp/gleam /usr/local/bin/gleam
rm -f /tmp/gleam /tmp/gleam.tar.gz
```

## Verify Tooling

```bash
docker --version
docker compose version
task --version
node --version
npm --version
gleam --version
```

## Run A VPS Dry Run

Follow [VPS_MIGRATION.md](/home/gabri/Work/cgu_mvp/monitoring_system/deploy/VPS_MIGRATION.md:1) if you are moving an existing installation.

If this is a fresh deploy, use the dry-run flow in [RUNBOOK.md](/home/gabri/Work/cgu_mvp/monitoring_system/deploy/RUNBOOK.md:1) with:

```bash
DEPLOY_ROOT=/srv/monitoring-system-test
SITE_ADDRESS=__TEST_DOMAIN__
```
