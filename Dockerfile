ARG TAILSCALE_VERSION=1.94.1
FROM tailscale/tailscale:v${TAILSCALE_VERSION}

LABEL org.opencontainers.image.title="Portable Tailscale Exit Node" \
      org.opencontainers.image.description="A portable Tailscale exit-node container for Ubuntu VPS hosts" \
      org.opencontainers.image.source="https://github.com/caseyyydev/portable-tailscale-exit-node" \
      org.opencontainers.image.licenses="MIT"

COPY --chmod=0755 docker/healthcheck.sh /usr/local/bin/exit-node-healthcheck

HEALTHCHECK --interval=60s --timeout=10s --start-period=15s --retries=3 \
  CMD ["/usr/local/bin/exit-node-healthcheck"]

