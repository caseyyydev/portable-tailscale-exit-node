# Portable Tailscale Exit Node

A small, provider-neutral Docker deployment for running a personal Tailscale
exit-node VPN on an Ubuntu VPS. The image extends the official, version-pinned
Tailscale image and keeps credentials and machine identity outside the image, so
the setup can move between GCP, Hetzner, Vultr, DigitalOcean, or another VPS.

## What this deploys

- Official `tailscale/tailscale:v1.94.1` base image
- Kernel-mode WireGuard through `/dev/net/tun`
- Docker bridge isolation; no host networking or privileged mode
- Persistent, portable Tailscale node state
- Auth key mounted as a Docker secret, never baked into the image
- Local-only health check and bounded Docker logs
- Host traffic totals through `vnstat`
- Safe state backup and restore helpers

## Requirements

- An Ubuntu VPS with TUN support
- Docker Engine with the Compose plugin
- A Tailscale account where you can approve exit nodes
- A tagged, pre-authorized Tailscale auth key

For best direct connectivity, allow inbound UDP 41641 in the provider firewall.
Tailscale can fall back to DERP relays when it is blocked, but performance may be
lower. Keep SSH restricted; this project does not modify firewall rules for you.

## Quick start on Ubuntu

```bash
git clone https://github.com/caseyyydev/portable-tailscale-exit-node.git
cd portable-tailscale-exit-node
./scripts/bootstrap-ubuntu.sh
```

Log out and back in if the bootstrap script added you to the `docker` group,
then configure the node. The auth-key prompt is hidden so the key does not enter
shell history or process listings.

```bash
./scripts/configure.sh
docker compose up -d --build
./scripts/status.sh
```

Open the [Tailscale admin console](https://login.tailscale.com/admin/machines),
find the new machine, open its route settings, and approve **Use as exit node**.
Advertisement alone does not grant approval. Your tailnet policy must also allow
the intended users to access `autogroup:internet` through exit nodes.

On each client, select this machine as its exit node. Tailscale clients normally
offer a separate option to keep access to the client's local LAN, such as a Wi-Fi
printer, while the exit node is enabled.

## Routine operations

```bash
# Container, Tailscale, public IP, and host traffic totals
./scripts/status.sh

# Logs
docker compose logs -f --tail=200 tailscale

# Update after deliberately changing TAILSCALE_VERSION
docker compose build --pull
docker compose up -d

# Stop without deleting identity
docker compose stop
```

Do not run `docker compose down -v` as a substitute for a backup. This project
uses a bind-mounted state directory, but the state remains sensitive and should
be backed up explicitly.

## Moving to another VPS

### Recommended: create a fresh node

1. Deploy this repository on the new VPS with a fresh one-off auth key.
2. Approve the new machine as an exit node.
3. Test it from one client and verify its public IP.
4. Switch the remaining clients.
5. Stop and remove the old node.

This avoids cloning private identity and allows a low-downtime cutover.

### Preserve the existing Tailscale identity

On the old VPS:

```bash
./scripts/backup-state.sh --stop
```

Copy the resulting `.tar.gz` and `.sha256` files securely to the new VPS, clone
this repository there, run `./scripts/configure.sh` to create the required local
secret file (it is not consumed while valid restored state exists), build the
image, and restore:

```bash
./scripts/configure.sh
docker compose build
./scripts/restore-state.sh /secure/path/tailscale-state-TIMESTAMP.tar.gz
docker compose up -d
```

The old container must remain stopped. Never run two copies of the same state;
they contain the same private node identity. Encrypt state archives before
off-host storage. The auth-key secret is intentionally not included in backups.

If the state is missing, the container registers as a new Tailscale machine and
requires fresh authentication and exit-node approval.

## Configuration

`./scripts/configure.sh` creates a private `.env` with:

| Variable | Default | Purpose |
| --- | --- | --- |
| `TS_HOSTNAME` | `portable-exit-node` | Device name in Tailscale |
| `TAILSCALE_VERSION` | `1.94.1` | Pinned official base image version |
| `IMAGE_NAME` | `portable-tailscale-exit-node` | Local image name |

The health endpoint listens only inside the container on `127.0.0.1:9002`. Its
status means the node has a tailnet IP; it is a readiness signal, not a complete
end-to-end test of internet routing.

## Cost and traffic

The image itself has no fee. VPS compute and outbound internet traffic are billed
by the provider. `vnstat` records totals on the host's default network interface;
it is useful for estimates but the provider's billing dashboard remains the
authoritative source.

## Security

Read [SECURITY.md](SECURITY.md) before copying state or using reusable keys. No
secret or state file should ever be committed to this repository.

## License

MIT

