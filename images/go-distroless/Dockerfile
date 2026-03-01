ARG VERSION=1.26.0
FROM nexus.gillouche.homelab/docker-hub/golang:${VERSION}-trixie AS donor

FROM nexus.gillouche.homelab/gcr-proxy/distroless/static-debian13:nonroot

ARG VERSION

COPY --link --from=donor /usr/local/go /usr/local/go

ENV GOROOT=/usr/local/go
ENV GOPATH=/home/nonroot/go
ENV PATH="/usr/local/go/bin:/home/nonroot/go/bin:${PATH}"

USER nonroot

# OCI Metadata
LABEL org.opencontainers.image.source="https://github.com/gillouche/container-factory"
LABEL org.opencontainers.image.description="Go Distroless Image"
LABEL org.opencontainers.image.licenses="MIT"
LABEL org.opencontainers.image.version="${VERSION}"

ENTRYPOINT ["/usr/local/go/bin/go"]
