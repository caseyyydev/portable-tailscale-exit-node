#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
FORCE=false

usage() {
  printf 'Usage: %s [--force]\n' "$0"
  printf 'Bootstraps Ubuntu, configures the node, builds the image, and starts it.\n'
}

while (($#)); do
  case "$1" in
    --force) FORCE=true ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

"$ROOT_DIR/scripts/bootstrap-ubuntu.sh"

if docker info >/dev/null 2>&1; then
  DOCKER=(docker)
elif command -v sudo >/dev/null 2>&1 && sudo docker info >/dev/null 2>&1; then
  DOCKER=(sudo docker)
else
  printf 'Docker is installed but unavailable to this session. Log out, reconnect, and run this installer again.\n' >&2
  exit 1
fi

if [[ -f "$ROOT_DIR/.env" && -f "$ROOT_DIR/secrets/tailscale-authkey" && "$FORCE" != true ]]; then
  printf 'Existing local configuration found; reusing it.\n'
else
  CONFIGURE_ARGS=()
  [[ "$FORCE" == true ]] && CONFIGURE_ARGS+=(--force)
  "$ROOT_DIR/scripts/configure.sh" "${CONFIGURE_ARGS[@]}"
fi

cd "$ROOT_DIR"
"${DOCKER[@]}" compose up -d --build
"${DOCKER[@]}" compose ps

printf '\nExit node is running. Finish setup in the Tailscale admin console:\n'
printf '  https://login.tailscale.com/admin/machines\n'
printf 'Approve "Use as exit node" for this machine, then select it on your clients.\n'
