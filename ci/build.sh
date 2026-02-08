#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME=$1
REGISTRY=${NEXUS_REGISTRY:-nexus.gillouche.homelab}
NAMESPACE=${NEXUS_NAMESPACE:-docker-hosted}
# Using Docker Buildx (DIND Sidecar supports this)
PLATFORMS="linux/amd64,linux/arm64"

# Check if image exists
if [ ! -d "images/$IMAGE_NAME" ]; then
    echo "Error: Image $IMAGE_NAME not found"
    exit 1
fi

# Load Variants
VARIANTS_FILE="images/$IMAGE_NAME/VARIANTS"
if [ -f "$VARIANTS_FILE" ]; then
    VARIANTS=$(cat "$VARIANTS_FILE")
else
    # Fallback to single version if no VARIANTS (look for legacy VERSION file)
    if [ -f "images/$IMAGE_NAME/VERSION" ]; then
        VARIANTS=$(cat "images/$IMAGE_NAME/VERSION")
    else
        echo "Error: No VARIANTS or VERSION file found for $IMAGE_NAME"
        exit 1
    fi
fi

# Build Loop
for VERSION in $VARIANTS; do
    FULL_IMAGE="$REGISTRY/$NAMESPACE/$IMAGE_NAME"
    echo "=================================================="
    echo "Building $FULL_IMAGE:$VERSION ($PLATFORMS)"
    echo "=================================================="

    # Create builder if needed (DIND supports buildx)
    if ! docker buildx inspect homelab-builder > /dev/null 2>&1; then
        docker buildx create --use --name homelab-builder --driver docker-container
        docker buildx inspect --bootstrap
    fi

    # Build & Push
    # We pass VERSION as a build-arg
    docker buildx build \
      --platform "$PLATFORMS" \
      --build-arg VERSION="$VERSION" \
      --tag "$FULL_IMAGE:$VERSION" \
      --tag "$FULL_IMAGE:latest" \
      --push \
      "images/$IMAGE_NAME"
    
    echo "✅ Pushed $FULL_IMAGE:$VERSION"
done
