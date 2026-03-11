ARG VERSION=25.8.1
FROM nexus.gillouche.homelab/docker-hub/node:${VERSION}-trixie-slim AS donor

FROM nexus.gillouche.homelab/gcr-proxy/distroless/cc-debian13:nonroot

ARG VERSION

COPY --link --from=donor /usr/local/bin/node /usr/local/bin/node
# Node.js requires libatomic which is not included in distroless/cc
COPY --link --from=donor /usr/lib/*-linux-gnu/libatomic.so.* /usr/lib/

USER nonroot

# OCI Metadata
LABEL org.opencontainers.image.source="https://github.com/gillouche/container-factory"
LABEL org.opencontainers.image.description="Node.js Distroless Image"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.version="${VERSION}"

ENTRYPOINT ["/usr/local/bin/node"]
