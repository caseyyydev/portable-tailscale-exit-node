#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
STOP=false
INCLUDE_ENV=false
OUTPUT=""

usage() {
  printf 'Usage: %s [--stop] [--include-env] [--output FILE]\n' "$0"
}

while (($#)); do
  case "$1" in
    --stop) STOP=true ;;
    --include-env) INCLUDE_ENV=true ;;
    --output) shift; OUTPUT="${1:-}"; [[ -n "$OUTPUT" ]] || { usage >&2; exit 2; } ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

cd "$ROOT_DIR"
CONTAINER_ID="$(docker compose ps -aq tailscale 2>/dev/null || true)"
CONTAINER_STATE="absent"
if [[ -n "$CONTAINER_ID" ]]; then
  CONTAINER_STATE="$(docker inspect --format '{{.State.Status}}' "$CONTAINER_ID")"
fi

if [[ "$CONTAINER_STATE" == running || "$CONTAINER_STATE" == restarting || "$CONTAINER_STATE" == paused ]]; then
  if [[ "$STOP" == true ]]; then
    docker compose stop tailscale
    CONTAINER_STATE="$(docker inspect --format '{{.State.Status}}' "$CONTAINER_ID")"
    if [[ "$CONTAINER_STATE" != exited && "$CONTAINER_STATE" != created && "$CONTAINER_STATE" != dead ]]; then
      printf 'Container did not reach a stopped state (current: %s). Refusing backup.\n' "$CONTAINER_STATE" >&2
      exit 1
    fi
  else
    printf 'The exit node is active (%s). Re-run with --stop for a consistent backup.\n' "$CONTAINER_STATE" >&2
    exit 1
  fi
fi

if [[ ! -d tailscale-state ]] || [[ -z "$(find tailscale-state -mindepth 1 ! -name .gitkeep -print -quit)" ]]; then
  printf 'No Tailscale state exists to back up.\n' >&2
  exit 1
fi

mkdir -p backups
umask 077
OUTPUT="${OUTPUT:-backups/tailscale-state-$(date -u +%Y%m%dT%H%M%SZ).tar.gz}"
mkdir -p "$(dirname -- "$OUTPUT")"
ITEMS=(tailscale-state)
if [[ "$INCLUDE_ENV" == true && -f .env ]]; then
  ITEMS+=(.env)
fi
BACKUP_IMAGE="$(docker compose config --images | head -n 1)"
if ! docker image inspect "$BACKUP_IMAGE" >/dev/null 2>&1; then
  printf 'Local image %s is unavailable. Run docker compose build first.\n' "$BACKUP_IMAGE" >&2
  exit 1
fi

# Docker's rootful helper can read state files created as root inside the
# Tailscale container. The archive is streamed back to a user-owned file.
docker run --rm \
  --entrypoint tar \
  --mount "type=bind,src=$ROOT_DIR,dst=/source,readonly" \
  "$BACKUP_IMAGE" -czf - -C /source "${ITEMS[@]}" > "$OUTPUT"
chmod 600 "$OUTPUT"
(cd -- "$(dirname -- "$OUTPUT")" && sha256sum "$(basename -- "$OUTPUT")") > "$OUTPUT.sha256"
chmod 600 "$OUTPUT.sha256"

printf 'Backup: %s\nChecksum: %s\n' "$OUTPUT" "$OUTPUT.sha256"
printf 'This archive contains private node identity material. Encrypt it before off-host storage.\n'
printf 'The auth-key secret was not included. The container remains stopped.\n'
