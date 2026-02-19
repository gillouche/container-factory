#!/usr/bin/env bash
set -euo pipefail

LOCAL_TAG=$1
EXPECTED_VERSION=$2

echo "Running Go smoke test against $LOCAL_TAG (expected Go ${EXPECTED_VERSION})..."

# 1. Version check
echo "Checking go version..."
VERSION_OUTPUT=$(docker run --rm "$LOCAL_TAG" version)
if echo "$VERSION_OUTPUT" | grep -q "go${EXPECTED_VERSION}"; then
    echo "Version check passed: $VERSION_OUTPUT"
else
    echo "Version check failed: expected go${EXPECTED_VERSION}, got: $VERSION_OUTPUT"
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

# 3. Compile & run check (uses test Dockerfile to avoid DIND volume mount issues)
echo "Checking Go compile & run..."
TEST_TAG="test-go-distroless:${EXPECTED_VERSION}"
docker buildx build \
    --load \
    --platform linux/amd64 \
    --build-arg BASE_IMAGE="$LOCAL_TAG" \
    --build-arg EXPECTED_VERSION="$EXPECTED_VERSION" \
    --tag "$TEST_TAG" \
    --file tests/go/Dockerfile.test \
    tests/go

docker run --rm -e "EXPECTED_VERSION=$EXPECTED_VERSION" "$TEST_TAG"
docker rmi "$TEST_TAG" || true

echo "All Go smoke tests passed!"
