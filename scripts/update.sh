#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [[ -n "$(git status --porcelain)" ]]; then
  printf 'Local repository has uncommitted changes. Commit or remove them before updating.\n' >&2
  exit 1
fi

if docker info >/dev/null 2>&1; then
  DOCKER=(docker)
elif command -v sudo >/dev/null 2>&1 && sudo docker info >/dev/null 2>&1; then
  DOCKER=(sudo docker)
else
  printf 'Docker is unavailable. Reconnect after bootstrap or check the Docker service.\n' >&2
  exit 1
fi

git pull --ff-only
"${DOCKER[@]}" compose build --pull
"${DOCKER[@]}" compose up -d
"${DOCKER[@]}" compose ps

printf 'Update complete. Tailscale identity and authentication state were preserved.\n'
