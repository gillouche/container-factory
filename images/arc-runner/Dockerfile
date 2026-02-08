ARG VERSION=2.331.0

FROM ghcr.io/actions/actions-runner:${VERSION}@sha256:dced476aa42703ebd9aafc295ce52f160989c4528e831fc3be2aef83a1b3f6da

# Switch to root to install dependencies
USER root

# hadolint ignore=DL3008
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    xz-utils \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create /nix directory and give ownership to runner for single-user install
RUN mkdir -m 0755 /nix && chown runner:runner /nix

# Switch to runner user
USER runner

# Single-user Nix installation (pinned version, TLS enforced)
ARG NIX_VERSION=2.33.2
RUN curl --proto '=https' --tlsv1.2 -sSf -L \
    "https://releases.nixos.org/nix/nix-${NIX_VERSION}/install" \
    | sh -s -- --no-daemon

# Add Nix to PATH for all future commands
ENV PATH="/home/runner/.nix-profile/bin:$PATH"

# Configure Nix
# sandbox=false: required inside containers (no nested namespaces)
# filter-syscalls=false: required for QEMU-emulated multi-arch builds
#   (Nix seccomp BPF filter fails under QEMU aarch64 emulation, see NixOS/nix#5258)
RUN mkdir -p ~/.config/nix \
    && printf '%s\n' \
    'experimental-features = nix-command flakes' \
    'sandbox = false' \
    'filter-syscalls = false' \
    > ~/.config/nix/nix.conf

# Verify Nix installation
RUN nix --version

ARG VERSION
# OCI Metadata
LABEL org.opencontainers.image.source="https://github.com/gillouche/container-factory"
LABEL org.opencontainers.image.description="GitHub Actions Runner with Nix"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.version="${VERSION}"

ENTRYPOINT ["/home/runner/run.sh"]
