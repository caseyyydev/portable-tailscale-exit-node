# Security policy

## Secrets and identity

Never commit `.env`, `secrets/tailscale-authkey`, or anything inside
`tailscale-state/`. The state directory contains private node identity material;
any backup of it must be encrypted before it leaves the VPS.

Use a tagged, pre-authorized, one-off Tailscale auth key whenever possible. The
key is needed only for initial registration because the durable identity is kept
in `tailscale-state/`. For unattended disaster recovery, use a narrowly scoped
Tailscale OAuth client with a permitted tag and `ephemeral=false` instead of a
broad reusable auth key.

Never start two VPS instances from the same copied state. Stop the old node
before restoring its state to a new host.

## Runtime boundaries

The container deliberately uses bridge networking, `/dev/net/tun`, and only the
`NET_ADMIN` capability. It does not use privileged mode, host networking, the
Docker socket, Tailscale SSH, or a public health port.

The bootstrap script does not change SSH, UFW, or provider firewall rules. Keep
SSH restricted to trusted source IPs or your tailnet. Allow outbound traffic;
allow inbound UDP 41641 when practical for better direct connectivity.

## Reporting a vulnerability

Open a GitHub security advisory for sensitive reports. Do not include auth keys,
state archives, public IPs, or other live credentials in a public issue.

