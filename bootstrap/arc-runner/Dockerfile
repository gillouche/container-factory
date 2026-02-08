FROM ghcr.io/actions/actions-runner:latest

# Switch to root to install dependencies
USER root

# Install Nix dependencies
RUN apt-get update && apt-get upgrade -y && apt-get install -y \
    curl \
    xz-utils \
    git \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Create /nix directory and give ownership to runner for single-user install
RUN mkdir -m 0755 /nix && chown runner:runner /nix

# Switch to runner user
USER runner

# Single-user installation
RUN curl -L https://nixos.org/nix/install | sh -s -- --no-daemon

# Add Nix to PATH for all future commands
ENV PATH="/home/runner/.nix-profile/bin:$PATH"

# Configure Nix (enable flakes)
RUN mkdir -p ~/.config/nix \
    && echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf \
    && echo 'sandbox = false' >> ~/.config/nix/nix.conf \
    && echo 'filter-syscalls = false' >> ~/.config/nix/nix.conf \
    && echo 'extra-trusted-users = runner' >> ~/.config/nix/nix.conf

# Verify Nix installation
RUN nix --version
