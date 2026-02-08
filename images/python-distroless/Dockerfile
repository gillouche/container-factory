ARG VERSION=3.13

FROM python:${VERSION}-slim-trixie AS donor

# hadolint ignore=DL3013
RUN pip install --no-cache-dir --upgrade pip setuptools wheel

FROM gcr.io/distroless/base-debian13:nonroot

COPY --from=donor /usr/local /usr/local

# OCI Metadata
LABEL org.opencontainers.image.source="https://github.com/gillouche/container-factory"
LABEL org.opencontainers.image.description="Python Distroless Image"
LABEL org.opencontainers.image.licenses="MIT"

ENTRYPOINT ["/usr/local/bin/python3"]
