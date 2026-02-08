ARG VERSION=2.331.0

FROM ghcr.io/actions/actions-runner:${VERSION}@sha256:dced476aa42703ebd9aafc295ce52f160989c4528e831fc3be2aef83a1b3f6da

# Switch to root to install dependencies
USER root

# hadolint ignore=DL3008
# Versions intentionally unpinned: packages track the base image's Debian release.
# Pinning would create false reproducibility and break on base image updates.
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    xz-utils \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create /nix directory and give ownership to runner for single-user install
RUN mkdir -m 0755 /nix && chown runner:runner /nix

# Use ENV HOME so PATH and config paths stay correct if the base image changes
ENV HOME=/home/runner

# Switch to runner user
USER runner

# Single-user Nix installation (pinned version, TLS enforced)
# Combined into single layer: install, configure, verify, and cleanup
ARG NIX_VERSION=2.33.2
RUN curl --proto '=https' --tlsv1.2 -sSf -L \
    "https://releases.nixos.org/nix/nix-${NIX_VERSION}/install" \
    | sh -s -- --no-daemon && \
    mkdir -p "${HOME}/.config/nix" && printf '%s\n' \
    'experimental-features = nix-command flakes' \
    'sandbox = false' \
    'filter-syscalls = false' \
    'substituters = s3://nix-cache?endpoint=http://seaweedfs-s3.seaweedfs.svc.cluster.local:8333&scheme=http https://cache.nixos.org/' \
    'trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=' \
    'require-sigs = false' \
    > "${HOME}/.config/nix/nix.conf" && \
    . "${HOME}/.nix-profile/etc/profile.d/nix.sh" && \
    nix --version && \
    nix-collect-garbage -d && \
    rm -rf /nix/var/nix/gcroots/auto/* ~/.cache/nix

# Add Nix to PATH for all future commands and runtime
ENV PATH="${HOME}/.nix-profile/bin:$PATH"

# Remove xz-utils (only needed for Nix tar.xz extraction during install)
USER root
RUN apt-get purge -y --auto-remove xz-utils && rm -rf /var/lib/apt/lists/*
USER runner

ARG VERSION
# OCI Metadata
LABEL org.opencontainers.image.source="https://github.com/gillouche/container-factory"
LABEL org.opencontainers.image.description="GitHub Actions Runner with Nix and homelab cache config"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.version="${VERSION}"
