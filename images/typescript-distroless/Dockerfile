ARG VERSION=25.8.1
FROM nexus.gillouche.homelab/docker-hub/node:${VERSION}-trixie-slim AS donor

# Install TypeScript and tsx globally for direct TS execution
# hadolint ignore=DL3016
RUN npm install -g --no-fund --no-audit typescript tsx \
    # Replace symlinks with real files so COPY --link works in the final stage
    && for f in /usr/local/bin/tsc /usr/local/bin/tsserver /usr/local/bin/tsx /usr/local/bin/npm /usr/local/bin/npx; do \
         if [ -L "$f" ]; then cp --remove-destination "$(readlink -f "$f")" "$f"; fi; \
       done

FROM nexus.gillouche.homelab/gcr-proxy/distroless/cc-debian13:nonroot

ARG VERSION

COPY --link --from=donor /usr/local/bin/node /usr/local/bin/node
COPY --link --from=donor /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --link --from=donor /usr/local/bin/npm /usr/local/bin/npm
COPY --link --from=donor /usr/local/bin/npx /usr/local/bin/npx
COPY --link --from=donor /usr/local/bin/tsc /usr/local/bin/tsc
COPY --link --from=donor /usr/local/bin/tsx /usr/local/bin/tsx

USER nonroot

# OCI Metadata
LABEL org.opencontainers.image.source="https://github.com/gillouche/container-factory"
LABEL org.opencontainers.image.description="TypeScript Distroless Image (Node.js + TypeScript + tsx)"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.version="${VERSION}"

ENTRYPOINT ["/usr/local/bin/node"]
