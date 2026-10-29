#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ! -r /etc/os-release ]]; then
  printf 'Cannot identify this operating system. Ubuntu is required.\n' >&2
  exit 1
fi

# shellcheck disable=SC1091
source /etc/os-release
if [[ "${ID:-}" != ubuntu ]]; then
  printf 'Unsupported operating system: %s. This bootstrap script supports Ubuntu only.\n' "${PRETTY_NAME:-unknown}" >&2
  exit 1
fi

if [[ "${EUID}" -eq 0 ]]; then
  SUDO=()
  TARGET_USER="${SUDO_USER:-root}"
else
  if ! command -v sudo >/dev/null 2>&1; then
    printf 'sudo is required when this script is not run as root.\n' >&2
    exit 1
  fi
  SUDO=(sudo)
  TARGET_USER="$USER"
fi

export DEBIAN_FRONTEND=noninteractive
"${SUDO[@]}" apt-get update
"${SUDO[@]}" apt-get install -y ca-certificates curl gnupg vnstat

if ! command -v docker >/dev/null 2>&1 || ! docker compose version >/dev/null 2>&1; then
  "${SUDO[@]}" install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | "${SUDO[@]}" tee /etc/apt/keyrings/docker.asc >/dev/null
  "${SUDO[@]}" chmod a+r /etc/apt/keyrings/docker.asc

  ARCH="$(dpkg --print-architecture)"
  REPO_LINE="deb [arch=${ARCH} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${VERSION_CODENAME} stable"
  printf '%s\n' "$REPO_LINE" | "${SUDO[@]}" tee /etc/apt/sources.list.d/docker.list >/dev/null
  "${SUDO[@]}" apt-get update
  "${SUDO[@]}" apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
fi

"${SUDO[@]}" systemctl enable --now docker
"${SUDO[@]}" systemctl enable --now vnstat

if [[ ! -c /dev/net/tun ]]; then
  "${SUDO[@]}" modprobe tun 2>/dev/null || true
fi
if [[ ! -c /dev/net/tun ]]; then
  printf '/dev/net/tun is unavailable. Enable TUN support with the VPS provider before continuing.\n' >&2
  exit 1
fi

if [[ "$TARGET_USER" != root ]]; then
  "${SUDO[@]}" usermod -aG docker "$TARGET_USER"
fi

"${SUDO[@]}" docker info >/dev/null

printf '\nUbuntu host is ready.\n'
if [[ "$TARGET_USER" != root ]]; then
  printf 'Log out and back in once so the docker group membership takes effect.\n'
fi
printf 'This script did not change SSH, UFW, or your provider firewall.\n'

