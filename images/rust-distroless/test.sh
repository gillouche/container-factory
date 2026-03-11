#!/usr/bin/env bash
set -euo pipefail

LOCAL_TAG=$1
EXPECTED_VERSION=$2

echo "Running Rust smoke test against $LOCAL_TAG (expected Rust ${EXPECTED_VERSION})..."

# 1. Version check
echo "Checking rustc version..."
VERSION_OUTPUT=$(docker run --rm --entrypoint /usr/local/cargo/bin/rustc "$LOCAL_TAG" --version)
if echo "$VERSION_OUTPUT" | grep -q "${EXPECTED_VERSION}"; then
    echo "Version check passed: $VERSION_OUTPUT"
else
    echo "Version check failed: expected ${EXPECTED_VERSION}, got: $VERSION_OUTPUT"
    exit 1
fi

# 2. Non-root check
echo "Checking non-root user..."
CONTAINER_USER=$(docker inspect --format='{{.Config.User}}' "$LOCAL_TAG")
if [ "$CONTAINER_USER" = "nonroot" ]; then
    echo "Non-root check passed: User=$CONTAINER_USER"
else
    echo "Non-root check failed: expected 'nonroot', got '$CONTAINER_USER'"
    exit 1
fi

# 3. Cargo version check
echo "Checking cargo version..."
CARGO_OUTPUT=$(docker run --rm --entrypoint /usr/local/cargo/bin/cargo "$LOCAL_TAG" --version)
if echo "$CARGO_OUTPUT" | grep -q "cargo"; then
    echo "Cargo check passed: $CARGO_OUTPUT"
else
    echo "Cargo check failed: $CARGO_OUTPUT"
    exit 1
fi

# 4. Compile & run check (uses test Dockerfile to avoid DIND volume mount issues)
echo "Checking Rust compile & run..."
TEST_TAG="test-rust-distroless:${EXPECTED_VERSION}"
docker buildx build \
    --load \
    --platform linux/amd64 \
    --build-arg BASE_IMAGE="$LOCAL_TAG" \
    --tag "$TEST_TAG" \
    --file tests/rust/Dockerfile.test \
    tests/rust

docker run --rm -e "EXPECTED_VERSION=$EXPECTED_VERSION" "$TEST_TAG"
docker rmi "$TEST_TAG" || true

echo "All Rust smoke tests passed!"
