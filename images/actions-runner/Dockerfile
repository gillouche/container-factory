FROM cgr.dev/chainguard/wolfi-base:latest@sha256:c9a27ee8d2d441f941de2f8e4c2c8ddb0b313adb5d14ab934b19f467b9ea8083 AS build

ARG TARGETARCH
ARG VERSION=2.331.0
ARG RUNNER_CONTAINER_HOOKS_VERSION=0.8.1
ARG RUNNER_CONTAINER_HOOKS_NOVOLUME_VERSION=0.8.1
ARG DOCKER_VERSION=29.2.0
ARG BUILDX_VERSION=0.31.1

USER root

RUN apk update && apk add --no-cache curl unzip

WORKDIR /actions-runner

RUN RUNNER_ARCH="${TARGETARCH}" \
    && if [ "$RUNNER_ARCH" = "amd64" ]; then RUNNER_ARCH="x64"; fi \
    && curl -f -L -o runner.tar.gz "https://github.com/actions/runner/releases/download/v${VERSION}/actions-runner-linux-${RUNNER_ARCH}-${VERSION}.tar.gz" \
    && tar xzf ./runner.tar.gz \
    && rm runner.tar.gz

RUN curl -f -L -o runner-container-hooks.zip "https://github.com/actions/runner-container-hooks/releases/download/v${RUNNER_CONTAINER_HOOKS_VERSION}/actions-runner-hooks-k8s-${RUNNER_CONTAINER_HOOKS_VERSION}.zip" \
    && unzip ./runner-container-hooks.zip -d ./k8s \
    && rm runner-container-hooks.zip

RUN curl -f -L -o runner-container-hooks.zip "https://github.com/actions/runner-container-hooks/releases/download/v${RUNNER_CONTAINER_HOOKS_NOVOLUME_VERSION}/actions-runner-hooks-k8s-${RUNNER_CONTAINER_HOOKS_NOVOLUME_VERSION}.zip" \
    && unzip ./runner-container-hooks.zip -d ./k8s-novolume \
    && rm runner-container-hooks.zip

RUN DOCKER_ARCH="${TARGETARCH}" \
    && if [ "$DOCKER_ARCH" = "amd64" ]; then DOCKER_ARCH="x86_64"; fi \
    && if [ "$DOCKER_ARCH" = "arm64" ]; then DOCKER_ARCH="aarch64"; fi \
    && curl -fLo docker.tgz "https://download.docker.com/linux/static/stable/${DOCKER_ARCH}/docker-${DOCKER_VERSION}.tgz" \
    && tar zxvf docker.tgz \
    && rm -rf docker.tgz \
    && mkdir -p /usr/local/lib/docker/cli-plugins \
    && curl -fLo /usr/local/lib/docker/cli-plugins/docker-buildx \
    "https://github.com/docker/buildx/releases/download/v${BUILDX_VERSION}/buildx-v${BUILDX_VERSION}.linux-${TARGETARCH}" \
    && chmod +x /usr/local/lib/docker/cli-plugins/docker-buildx

FROM cgr.dev/chainguard/wolfi-base:latest@sha256:c9a27ee8d2d441f941de2f8e4c2c8ddb0b313adb5d14ab934b19f467b9ea8083

ARG VERSION=2.331.0
ARG RUNNER_UID=1001
ARG RUNNER_GID=1001
ARG DOCKER_GID=123

ENV RUNNER_MANUALLY_TRAP_SIG=1
ENV ACTIONS_RUNNER_PRINT_LOG_TO_STDOUT=1
ENV ImageOS=wolfi

USER root

RUN apk update && apk add --no-cache \
    bash \
    busybox-full \
    curl \
    git \
    jq \
    glibc-locale-en \
    icu-libs \
    krb5-libs \
    libstdc++ \
    dotnet-8-sdk \
    nodejs-24 \
    build-base \
    zip \
    unzip \
    python-3.14 \
    py3.14-pip \
    sudo

RUN addgroup -S runner -g ${RUNNER_GID} \
    && (addgroup -S docker -g ${DOCKER_GID} || addgroup -S docker) \
    && adduser -S -G runner -u ${RUNNER_UID} runner \
    && addgroup runner docker \
    && echo "runner ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

RUN if [ ! -e /usr/bin/python3 ]; then ln -s /usr/bin/python3.14 /usr/bin/python3; fi

WORKDIR /home/runner

COPY --chown=runner:docker --from=build /actions-runner .
COPY --from=build /usr/local/lib/docker/cli-plugins/docker-buildx /usr/local/lib/docker/cli-plugins/docker-buildx

RUN install -o root -g root -m 755 docker/* /usr/bin/ && rm -rf docker

USER runner

LABEL org.opencontainers.image.source="https://github.com/gillouche/container-factory"
LABEL org.opencontainers.image.description="Wolfi-based GitHub Actions Runner for ARC (Secure)"
LABEL org.opencontainers.image.version="${VERSION}"
