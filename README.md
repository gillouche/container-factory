# container-factory

[![Build & Publish](https://github.com/gillouche/container-factory/actions/workflows/build.yaml/badge.svg)](https://github.com/gillouche/container-factory/actions/workflows/build.yaml)

A central monorepo for building hardened, security-scanned Docker images for the homelab.

## Architecture
- **Runners**: GitHub Actions (ARC) with DIND sidecars.
- **Registry**: Nexus (`nexus.gillouche.homelab`).
- **Strategy**: 
    - **Multi-Arch**: AMD64 + ARM64.
    - **Distroless**: Uses "Donor" pattern to transplant specific app versions into `distroless/base`.
## Development Environment
This project includes a Nix flake for a reproducible development environment.

To use it:
1.  **Install Nix**: ensure you have Nix installed.
2.  **Direnv**: `direnv allow .` (this will automatically load `trivy`, `gnumake`, and `docker-buildx`).
3.  **Manual**: `nix develop` (if you don't use direnv).

## Usage
Build a specific image:
```bash
make build-python-distroless
```

Build all:
```bash
make build-all
```

## Adding a new Version
Edit `images/<name>/VARIANTS` and add the new tag (e.g., `3.14.0`).