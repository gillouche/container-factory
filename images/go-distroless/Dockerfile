ARG VERSION=1.26.0
FROM nexus.gillouche.homelab/docker-hub/golang:${VERSION}-trixie AS donor

FROM nexus.gillouche.homelab/gcr-proxy/distroless/static-debian13:nonroot

ARG VERSION

USER nonroot

# OCI Metadata
LABEL org.opencontainers.image.source="https://github.com/gillouche/container-factory"
LABEL org.opencontainers.image.description="Go Distroless Runtime Image"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.version="${VERSION}"
