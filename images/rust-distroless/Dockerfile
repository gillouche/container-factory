ARG VERSION=1.86.0
FROM nexus.gillouche.homelab/docker-hub/rust:${VERSION}-slim-trixie AS donor

FROM nexus.gillouche.homelab/gcr-proxy/distroless/cc-debian13:nonroot

ARG VERSION

COPY --link --from=donor /usr/local/rustup /usr/local/rustup
COPY --link --from=donor /usr/local/cargo /usr/local/cargo

ENV RUSTUP_HOME=/usr/local/rustup
ENV CARGO_HOME=/home/nonroot/.cargo
ENV PATH="/usr/local/cargo/bin:${PATH}"

USER nonroot

# OCI Metadata
LABEL org.opencontainers.image.source="https://github.com/gillouche/container-factory"
LABEL org.opencontainers.image.description="Rust Distroless Image"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.version="${VERSION}"

ENTRYPOINT ["/usr/local/cargo/bin/rustc"]
