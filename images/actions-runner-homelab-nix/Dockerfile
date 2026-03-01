ARG VERSION=2.331.0
ARG DOWNLOAD_PROXY=nexus.gillouche.homelab/repository

FROM nexus.gillouche.homelab/docker-hosted/base/tls-bundle:latest AS tls

FROM nexus.gillouche.homelab/docker-hosted/base/actions-runner:${VERSION}

ARG DOWNLOAD_PROXY

# Switch to root to configure Nix and CA certificates
USER root

# Java truststore and raw cert from centralized TLS bundle
COPY --from=tls /certs/java-cacerts /etc/ssl/certs/java/cacerts
COPY --from=tls /certs/nexus-ca.crt /usr/local/share/ca-certificates/nexus-ca.crt

# Install packages and prepare /nix
RUN apk update && apk add --no-cache xz coreutils && \
    mkdir -m 0755 /nix && chown runner:runner /nix

# Use ENV HOME so PATH and config paths stay correct
ENV HOME=/home/runner

# Switch back to runner user
USER runner

# Single-user Nix installation (pinned version, TLS enforced)
ARG NIX_VERSION=2.33.2
SHELL ["/bin/bash", "-c"]

RUN export NIX_CONFIG="filter-syscalls = false" && \
    curl --proto '=https' --tlsv1.2 -sSf -L \
    "https://${DOWNLOAD_PROXY}/nixos-releases/nix/nix-${NIX_VERSION}/install" \
    | sh -s -- --no-daemon && \
    export PATH="${HOME}/.nix-profile/bin:$PATH" && \
    mkdir -p "${HOME}/.config/nix" && printf '%s\n' \
    'experimental-features = nix-command flakes' \
    'sandbox = false' \
    'filter-syscalls = false' \
    'substituters = s3://nix-cache?endpoint=http://seaweedfs-s3.seaweedfs.svc.cluster.local:8333&scheme=http&profile=nix https://nexus.gillouche.homelab/repository/nix-cache-proxy/ https://cache.nixos.org/' \
    'trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=' \
    'require-sigs = false' \
    > "${HOME}/.config/nix/nix.conf" && \
    nix --version && \
    nix-collect-garbage -d && \
    rm -rf /nix/var/nix/gcroots/auto/* ~/.cache/nix

SHELL ["/bin/sh", "-c"]

# Add Nix to PATH for all future commands and runtime
ENV PATH="${HOME}/.nix-profile/bin:$PATH"

USER runner

ARG VERSION
LABEL org.opencontainers.image.source="https://github.com/gillouche/container-factory"
LABEL org.opencontainers.image.description="GitHub Actions Runner (Wolfi) with Nix and homelab cache config"
LABEL org.opencontainers.image.version="${VERSION}"
