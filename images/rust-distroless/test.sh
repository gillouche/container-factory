#!/usr/bin/env bash
set -euo pipefail

LOCAL_TAG=$1
EXPECTED_VERSION=$2

echo "Running Rust runtime smoke test against $LOCAL_TAG (expected Rust ${EXPECTED_VERSION})..."

# 1. Non-root check
echo "Checking non-root user..."
CONTAINER_USER=$(docker inspect --format='{{.Config.User}}' "$LOCAL_TAG")
if [ "$CONTAINER_USER" = "nonroot" ]; then
    echo "Non-root check passed: User=$CONTAINER_USER"
else
    echo "Non-root check failed: expected 'nonroot', got '$CONTAINER_USER'"
    exit 1
fi

# 2. Compile externally & run in distroless (uses test Dockerfile to avoid DIND volume mount issues)
echo "Checking Rust binary execution in distroless..."
TEST_TAG="test-rust-distroless:${EXPECTED_VERSION}"
docker buildx build \
    --load \
    --platform linux/amd64 \
    --build-arg BASE_IMAGE="$LOCAL_TAG" \
    --build-arg VERSION="$EXPECTED_VERSION" \
    --tag "$TEST_TAG" \
    --file tests/rust/Dockerfile.test \
    tests/rust

docker run --rm "$TEST_TAG"
docker rmi "$TEST_TAG" || true

echo "All Rust runtime smoke tests passed!"
