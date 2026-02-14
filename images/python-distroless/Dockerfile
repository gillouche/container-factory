ARG VERSION=3.13
FROM nexus.gillouche.homelab/docker-hub/python:${VERSION}-slim-trixie AS donor

# Upgrade to patch known CVEs in bundled pip/setuptools/wheel
# hadolint ignore=DL3013
RUN pip install --no-cache-dir --upgrade pip setuptools wheel

FROM gcr.io/distroless/base-debian13:nonroot@sha256:e2f22688c7f48cf0657f7c0929b52174c80b73ea24ea898df7517c26621659bb

ARG VERSION

COPY --link --from=donor /usr/local /usr/local

USER nonroot

# OCI Metadata
LABEL org.opencontainers.image.source="https://github.com/gillouche/container-factory"
LABEL org.opencontainers.image.description="Python Distroless Image"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.version="${VERSION}"

ENTRYPOINT ["/usr/local/bin/python3"]
