#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
FORCE=false

usage() {
  printf 'Usage: %s [--force]\n' "$0"
  printf 'Creates .env and the local Tailscale auth-key secret.\n'
}

while (($#)); do
  case "$1" in
    --force) FORCE=true ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

ENV_FILE="$ROOT_DIR/.env"
SECRET_DIR="$ROOT_DIR/secrets"
SECRET_FILE="$SECRET_DIR/tailscale-authkey"

if [[ "$FORCE" != true && ( -e "$ENV_FILE" || -e "$SECRET_FILE" ) ]]; then
  printf 'Configuration already exists. Re-run with --force to replace it.\n' >&2
  exit 1
fi

read -r -p 'Tailscale hostname [portable-exit-node]: ' HOSTNAME_INPUT
HOSTNAME_INPUT="${HOSTNAME_INPUT:-portable-exit-node}"
if [[ ! "$HOSTNAME_INPUT" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?$ ]]; then
  printf 'Invalid hostname. Use letters, numbers, and hyphens only (1-63 characters).\n' >&2
  exit 1
fi

printf 'Paste a tagged, pre-authorized Tailscale auth key (input is hidden): '
IFS= read -r -s AUTH_KEY
printf '\n'
if [[ -z "$AUTH_KEY" ]]; then
  printf 'Auth key cannot be empty.\n' >&2
  exit 1
fi

umask 077
mkdir -p "$SECRET_DIR" "$ROOT_DIR/tailscale-state"
chmod 700 "$SECRET_DIR" "$ROOT_DIR/tailscale-state"
printf '%s' "$AUTH_KEY" > "$SECRET_FILE"
chmod 600 "$SECRET_FILE"
unset AUTH_KEY

{
  printf 'TS_HOSTNAME=%s\n' "$HOSTNAME_INPUT"
  printf 'TAILSCALE_VERSION=1.94.1\n'
  printf 'IMAGE_NAME=portable-tailscale-exit-node\n'
} > "$ENV_FILE"
chmod 600 "$ENV_FILE"

cd "$ROOT_DIR"
docker compose config --quiet

printf '\nConfiguration written safely. Next run:\n'
printf '  docker compose up -d --build\n'
printf '  ./scripts/status.sh\n\n'
printf 'Then approve this device as an exit node in the Tailscale admin console.\n'

