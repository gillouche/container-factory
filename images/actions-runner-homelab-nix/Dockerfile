ARG VERSION=2.331.0

# FROM nexus.gillouche.homelab/docker-hosted/base/actions-runner:${VERSION}
FROM ghcr.io/actions/actions-runner:${VERSION}@sha256:dced476aa42703ebd9aafc295ce52f160989c4528e831fc3be2aef83a1b3f6da

# Switch to root to configure Nix
USER root

# Create /nix directory and give ownership to runner
RUN mkdir -m 0755 /nix && chown runner:runner /nix

# Use ENV HOME so PATH and config paths stay correct
ENV HOME=/home/runner

# Switch back to runner user
USER runner

# Single-user Nix installation (pinned version, TLS enforced)
ARG NIX_VERSION=2.33.2
SHELL ["/bin/bash", "-c"]

RUN curl --proto '=https' --tlsv1.2 -sSf -L \
    "https://releases.nixos.org/nix/nix-${NIX_VERSION}/install" \
    | sh -s -- --no-daemon && \
    export PATH="${HOME}/.nix-profile/bin:$PATH" && \
    mkdir -p "${HOME}/.config/nix" && printf '%s\n' \
    'experimental-features = nix-command flakes' \
    'sandbox = false' \
    'filter-syscalls = false' \
    'substituters = s3://nix-cache?endpoint=http://seaweedfs-s3.seaweedfs.svc.cluster.local:8333&scheme=http https://cache.nixos.org/' \
    'trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=' \
    'require-sigs = false' \
    > "${HOME}/.config/nix/nix.conf" && \
    nix --version && \
    nix-collect-garbage -d && \
    rm -rf /nix/var/nix/gcroots/auto/* ~/.cache/nix

SHELL ["/bin/sh", "-c"]

# Add Nix to PATH for all future commands and runtime
ENV PATH="${HOME}/.nix-profile/bin:$PATH"

ARG VERSION
LABEL org.opencontainers.image.source="https://github.com/gillouche/container-factory"
LABEL org.opencontainers.image.description="GitHub Actions Runner (Wolfi) with Nix and homelab cache config"
LABEL org.opencontainers.image.version="${VERSION}"
