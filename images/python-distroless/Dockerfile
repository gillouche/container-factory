ARG VERSION=3.13
FROM nexus.gillouche.homelab/docker-hub/python:${VERSION}-slim-trixie AS donor

# Upgrade to patch known CVEs in bundled pip/setuptools/wheel
# hadolint ignore=DL3013
RUN pip install --no-cache-dir --upgrade pip setuptools wheel

FROM gcr.io/distroless/base-debian13:nonroot@sha256:fe144a0da26b77d18fb60d434aa6b88d40f9ff46e3ad883252992d5ad4aee333

ARG VERSION

COPY --link --from=donor /usr/local /usr/local

USER nonroot

# OCI Metadata
LABEL org.opencontainers.image.source="https://github.com/gillouche/container-factory"
LABEL org.opencontainers.image.description="Python Distroless Image"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.version="${VERSION}"

ENTRYPOINT ["/usr/local/bin/python3"]
