#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
FORCE=false
START=false
ARCHIVE=""

usage() {
  printf 'Usage: %s [--force] [--start] BACKUP.tar.gz\n' "$0"
}

while (($#)); do
  case "$1" in
    --force) FORCE=true ;;
    --start) START=true ;;
    -h|--help) usage; exit 0 ;;
    -*) printf 'Unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    *) [[ -z "$ARCHIVE" ]] || { printf 'Only one backup may be supplied.\n' >&2; exit 2; }; ARCHIVE="$1" ;;
  esac
  shift
done

[[ -n "$ARCHIVE" ]] || { usage >&2; exit 2; }
ARCHIVE="$(cd -- "$(dirname -- "$ARCHIVE")" && pwd)/$(basename -- "$ARCHIVE")"
[[ -f "$ARCHIVE" ]] || { printf 'Backup not found: %s\n' "$ARCHIVE" >&2; exit 1; }

cd "$ROOT_DIR"
CONTAINER_ID="$(docker compose ps -aq tailscale 2>/dev/null || true)"
CONTAINER_STATE="absent"
if [[ -n "$CONTAINER_ID" ]]; then
  CONTAINER_STATE="$(docker inspect --format '{{.State.Status}}' "$CONTAINER_ID")"
fi
if [[ "$CONTAINER_STATE" == running || "$CONTAINER_STATE" == restarting || "$CONTAINER_STATE" == paused ]]; then
  printf 'Target exit-node container is active (%s). Stop it before restoring identity.\n' "$CONTAINER_STATE" >&2
  exit 1
fi

if [[ -f "$ARCHIVE.sha256" ]]; then
  (cd -- "$(dirname -- "$ARCHIVE")" && sha256sum -c "$(basename -- "$ARCHIVE.sha256")")
else
  printf 'Warning: no checksum file was found; integrity cannot be verified.\n' >&2
fi

if tar -tzf "$ARCHIVE" | grep -Eq '(^/|(^|/)\.\.(/|$))'; then
  printf 'Unsafe paths detected in backup; refusing to extract.\n' >&2
  exit 1
fi

mkdir -p tailscale-state
RESTORE_IMAGE="$(docker compose config --images | head -n 1)"
if ! docker image inspect "$RESTORE_IMAGE" >/dev/null 2>&1; then
  printf 'Local image %s is unavailable. Run docker compose build first.\n' "$RESTORE_IMAGE" >&2
  exit 1
fi

STATE_PRESENT="$(docker run --rm \
  --entrypoint sh \
  --mount "type=bind,src=$ROOT_DIR/tailscale-state,dst=/target,readonly" \
  "$RESTORE_IMAGE" \
  -c 'find /target -mindepth 1 ! -name .gitkeep -print -quit')"
if [[ -n "$STATE_PRESENT" && "$FORCE" != true ]]; then
  printf 'tailscale-state is not empty. Re-run with --force only if replacement is intended.\n' >&2
  exit 1
fi

if ! tar -tzf "$ARCHIVE" | grep -q '^tailscale-state/'; then
  printf 'Backup does not contain tailscale-state.\n' >&2
  exit 1
fi

# Extract through a rootful, tightly mounted helper so root-owned state can be
# replaced without making the state directory broadly readable on the host.
docker run --rm -i \
  --entrypoint sh \
  --mount "type=bind,src=$ROOT_DIR/tailscale-state,dst=/target" \
  "$RESTORE_IMAGE" \
  -eu -c 'find /target -mindepth 1 -maxdepth 1 -exec rm -rf -- {} +; tar -xzf - -C /target --strip-components=1 tailscale-state' \
  < "$ARCHIVE"
chmod 700 tailscale-state 2>/dev/null || true

printf 'State restored. The old VPS must remain shut down; never run cloned node identities.\n'
if [[ "$START" == true ]]; then
  docker compose up -d
else
  printf 'Inspect the configuration, then start with: docker compose up -d\n'
fi

