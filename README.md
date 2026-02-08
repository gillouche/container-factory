# Container Factory

A central monorepo for building hardened, security-scanned Docker images for the homelab.

## Architecture
- **Runners**: GitHub Actions (ARC) with DIND sidecars.
- **Registry**: Nexus (`nexus.gillouche.homelab`).
- **Strategy**: 
    - **Multi-Arch**: AMD64 + ARM64.
    - **Distroless**: Uses "Donor" pattern to transplant specific app versions into `distroless/base`.
    - **Security**: Trivy strict scanning (fails on Critical).

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