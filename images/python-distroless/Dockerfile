ARG VERSION=3.13
FROM nexus.gillouche.homelab/docker-hub/python:${VERSION}-slim-trixie AS donor

# Upgrade to patch known CVEs in bundled pip/setuptools/wheel
# hadolint ignore=DL3013
RUN pip install --no-cache-dir --upgrade pip setuptools wheel

FROM gcr.io/distroless/cc-debian13:nonroot@sha256:26474572388bb8bcbf837002e07b3c068e31b053f0ed1865218fc1e25a7650f6

ARG VERSION

COPY --link --from=donor /usr/local /usr/local

USER nonroot

# OCI Metadata
LABEL org.opencontainers.image.source="https://github.com/gillouche/container-factory"
LABEL org.opencontainers.image.description="Python Distroless Image"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.version="${VERSION}"

ENTRYPOINT ["/usr/local/bin/python3"]
