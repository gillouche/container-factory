#!/usr/bin/env bash
set -euo pipefail

LOCAL_TAG=$1
EXPECTED_VERSION=$2

echo "Running TypeScript smoke test against $LOCAL_TAG (expected Node ${EXPECTED_VERSION})..."

# 1. Node version check
echo "Checking node version..."
VERSION_OUTPUT=$(docker run --rm "$LOCAL_TAG" --version)
if echo "$VERSION_OUTPUT" | grep -q "v${EXPECTED_VERSION}"; then
    echo "Version check passed: $VERSION_OUTPUT"
else
    echo "Version check failed: expected v${EXPECTED_VERSION}, got: $VERSION_OUTPUT"
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

# 3. TypeScript compiler check
echo "Checking tsc version..."
TSC_OUTPUT=$(docker run --rm --entrypoint /usr/local/bin/tsc "$LOCAL_TAG" --version)
if echo "$TSC_OUTPUT" | grep -q "Version"; then
    echo "TypeScript check passed: $TSC_OUTPUT"
else
    echo "TypeScript check failed: $TSC_OUTPUT"
    exit 1
fi

# 4. Run TypeScript file (uses test Dockerfile to avoid DIND volume mount issues)
echo "Checking TypeScript execution via tsx..."
TEST_TAG="test-typescript-distroless:${EXPECTED_VERSION}"
docker buildx build \
    --load \
    --platform linux/amd64 \
    --build-arg BASE_IMAGE="$LOCAL_TAG" \
    --tag "$TEST_TAG" \
    --file tests/typescript/Dockerfile.test \
    tests/typescript

docker run --rm -e "EXPECTED_VERSION=$EXPECTED_VERSION" "$TEST_TAG"
docker rmi "$TEST_TAG" || true

echo "All TypeScript smoke tests passed!"
