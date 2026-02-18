ARG VERSION=3.13
FROM nexus.gillouche.homelab/docker-hub/python:${VERSION}-slim-trixie AS donor

# Upgrade to patch known CVEs in bundled pip/setuptools/wheel
# hadolint ignore=DL3013
RUN pip install --no-cache-dir --upgrade pip setuptools wheel

FROM gcr.io/distroless/cc-debian13:nonroot@sha256:84fcd3c223b144b0cb6edc5ecc75641819842a9679a3a58fd6294bec47532bf7

ARG VERSION

COPY --link --from=donor /usr/local /usr/local

USER nonroot

# OCI Metadata
LABEL org.opencontainers.image.source="https://github.com/gillouche/container-factory"
LABEL org.opencontainers.image.description="Python Distroless Image"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.version="${VERSION}"

ENTRYPOINT ["/usr/local/bin/python3"]
