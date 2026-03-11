ARG VERSION=1.94.0
FROM nexus.gillouche.homelab/docker-hub/rust:${VERSION}-slim-trixie AS donor

FROM nexus.gillouche.homelab/gcr-proxy/distroless/cc-debian13:nonroot

ARG VERSION

USER nonroot

# OCI Metadata
LABEL org.opencontainers.image.source="https://github.com/gillouche/container-factory"
LABEL org.opencontainers.image.description="Rust Distroless Runtime Image"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.version="${VERSION}"
