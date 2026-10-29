#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

printf 'Container\n'
docker compose ps

printf '\nTailscale\n'
if ! docker compose exec -T tailscale tailscale status; then
  printf 'Tailscale is not ready or the container is not running.\n' >&2
fi

printf '\nVPS public egress IP\n'
if ! docker compose exec -T tailscale wget -qO- --timeout=8 https://ifconfig.me/ip; then
  printf 'Unavailable (network check failed).'
fi
printf '\n'

printf '\nHost traffic totals\n'
if command -v vnstat >/dev/null 2>&1; then
  DEFAULT_IFACE="$(ip route show default 2>/dev/null | awk 'NR == 1 { print $5 }')"
  if [[ -n "$DEFAULT_IFACE" ]] && vnstat -i "$DEFAULT_IFACE" --oneline >/dev/null 2>&1; then
    vnstat -i "$DEFAULT_IFACE"
  else
    printf 'vnStat is installed but has not initialized the default interface yet.\n'
  fi
else
  printf 'vnStat is not installed. Run ./scripts/bootstrap-ubuntu.sh on Ubuntu.\n'
fi

printf '\nNote: local status cannot confirm admin-console exit-node approval.\n'
