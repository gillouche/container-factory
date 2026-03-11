ARG VERSION=25.8.1
FROM nexus.gillouche.homelab/docker-hub/node:${VERSION}-trixie-slim AS donor

# Install TypeScript and tsx globally for direct TS execution
# hadolint ignore=DL3016
RUN npm install -g --no-fund --no-audit typescript tsx

FROM nexus.gillouche.homelab/gcr-proxy/distroless/cc-debian13:nonroot

ARG VERSION

COPY --link --from=donor /usr/local /usr/local

USER nonroot

# OCI Metadata
LABEL org.opencontainers.image.source="https://github.com/gillouche/container-factory"
LABEL org.opencontainers.image.description="TypeScript Distroless Image (Node.js + TypeScript + tsx)"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.version="${VERSION}"

ENTRYPOINT ["/usr/local/bin/node"]
