#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME=$1
TARGET_VERSION=${2:-}
REGISTRY=${NEXUS_REGISTRY:-nexus.gillouche.homelab}
NAMESPACE=${NEXUS_NAMESPACE:-docker-hosted}

# Using Docker Buildx (DIND Sidecar supports this)
if [ -f "images/$IMAGE_NAME/PLATFORMS" ]; then
    PLATFORMS=$(cat "images/$IMAGE_NAME/PLATFORMS")
else
    PLATFORMS="linux/amd64,linux/arm64"
fi

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

# Default to False
PUSH_IMAGES=${PUSH_IMAGES:-false}
SCAN_IMAGES=${SCAN_IMAGES:-false}

# If pushing, we implies scanning (unless disabled explicitly?? No, let's just force it for safety)
if [ "$PUSH_IMAGES" = "true" ]; then
    SCAN_IMAGES="true"
fi

# Determine the highest version for the "latest" tag (semver sort)
LATEST_VERSION=$(echo "$VARIANTS" | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)

# Override if specific version targeted
if [ -n "$TARGET_VERSION" ]; then
    VARIANTS="$TARGET_VERSION"
fi

# Registry cache location
CACHE_IMAGE="$REGISTRY/$NAMESPACE/cache/$IMAGE_NAME"

# ---------------------------------------------------------
# Ensure buildx is available and builder exists (once)
# ---------------------------------------------------------
if ! docker buildx version > /dev/null 2>&1; then
    echo "Error: 'docker buildx' is not available. Please install the Docker Buildx plugin."
    exit 1
fi


# Build Loop
for VERSION in $VARIANTS; do
    # User requested docker-hosted/base/ structure
    FULL_IMAGE="$REGISTRY/$NAMESPACE/base/$IMAGE_NAME"
    echo "=================================================="
    echo "Building $FULL_IMAGE:$VERSION ($PLATFORMS)"
    echo "Push Enabled: $PUSH_IMAGES"
    echo "Scan Enabled: $SCAN_IMAGES"
    echo "=================================================="
    
    # 0. Revision Check (Metadata)
    # We build every time to catch upstream updates (base image, packages).
    # We use GIT_REV and GIT_DATE scoped to the image directory to ensure build reproducibility
    # when only unrelated files change in the repo.
    
    GIT_REV=$(git log -1 --format=%H "images/$IMAGE_NAME")
    # Fallback to HEAD if path history is empty (e.g. new file)
    if [ -z "$GIT_REV" ]; then
        GIT_REV=$(git rev-parse HEAD)
    fi

    GIT_DATE=$(git log -1 --format=%ct "images/$IMAGE_NAME")
    if [ -z "$GIT_DATE" ]; then
        GIT_DATE=$(git log -1 --format=%ct)
    fi
    
    BUILD_DATE=$(date -u -d "@$GIT_DATE" +%Y-%m-%dT%H:%M:%SZ)

    # ---------------------------------------------------------
    # 1. Pre-flight Verification (Build + Smoke Test)
    # ---------------------------------------------------------
    echo "Pre-flight verification (linux/amd64)..."
    
    # Build local image for verification
    LOCAL_TAG="local-scan-$IMAGE_NAME:$VERSION"
    
    # We must build a single arch to load it into the local daemon
    docker buildx build \
        --load \
        --platform linux/amd64 \
        --build-arg VERSION="$VERSION" \
        --build-arg SOURCE_DATE_EPOCH="$GIT_DATE" \
        --build-arg PYTHONDONTWRITEBYTECODE=1 \
        --tag "$LOCAL_TAG" \
        --file "images/$IMAGE_NAME/Dockerfile" \
        "images/$IMAGE_NAME"

    # 1.1 Smoke Test (convention-based: images/$IMAGE_NAME/test.sh)
    TEST_SCRIPT="images/$IMAGE_NAME/test.sh"
    if [ -f "$TEST_SCRIPT" ]; then
        if [ "${SMOKE_TEST:-true}" = "false" ]; then
            echo "Skipping smoke test ($TEST_SCRIPT) due to SMOKE_TEST=false"
        else
            echo "Running smoke test ($TEST_SCRIPT)..."
        if bash "$TEST_SCRIPT" "$LOCAL_TAG" "$VERSION"; then
            echo "Smoke test passed!"
        else
            echo "Smoke test failed!"
            docker rmi "$LOCAL_TAG" || true
            exit 1
        fi
        fi
    else
        echo "Warning: No smoke test found for $IMAGE_NAME (no test.sh)"
    fi

    # Save local image ID for idempotency check
    LOCAL_ID=$(docker inspect --format='{{.Id}}' "$LOCAL_TAG")
    
    # ---------------------------------------------------------
    # 2. Check for Idempotency (if Pushing)
    # ---------------------------------------------------------
    PUSH_NECESSARY="true"
    if [ "$PUSH_IMAGES" = "true" ] && command -v crane &> /dev/null; then
        echo "Checking if push is necessary for $FULL_IMAGE:$VERSION..."
        # Get Remote Config Digest (this matches Image ID for OCI/Docker v2.2)
        REMOTE_CONFIG=$(crane config "$FULL_IMAGE:$VERSION" 2>/dev/null || true)
        if [ -n "$REMOTE_CONFIG" ]; then
            REMOTE_ID=$(echo "$REMOTE_CONFIG" | sha256sum | awk '{print "sha256:"$1}')
            if [ "$LOCAL_ID" = "$REMOTE_ID" ]; then
                 echo "Image $FULL_IMAGE:$VERSION matches remote config. Skipping push."
                 PUSH_NECESSARY="false"
            else
                 echo "Config differs (Local: ${LOCAL_ID:0:12} Remote: ${REMOTE_ID:0:12})."
            fi
        fi
    fi

    # Cleanup local scan image
    docker rmi "$LOCAL_TAG" || true

    # ---------------------------------------------------------
    # 3. Multi-Arch Build & Push
    # ---------------------------------------------------------
    
    # Construct Build Command
    BUILD_CMD=(docker buildx build)
    BUILD_CMD+=(--build-arg VERSION="$VERSION")
    BUILD_CMD+=(--build-arg SOURCE_DATE_EPOCH="$GIT_DATE")
    BUILD_CMD+=(--build-arg PYTHONDONTWRITEBYTECODE=1)
    
    BUILD_CMD+=(--label "org.opencontainers.image.created=$BUILD_DATE")
    BUILD_CMD+=(--label "org.opencontainers.image.revision=$GIT_REV")
    BUILD_CMD+=(--tag "$FULL_IMAGE:$VERSION")

    # Only tag the highest version as "latest"
    if [ "$VERSION" = "$LATEST_VERSION" ]; then
        BUILD_CMD+=(--tag "$FULL_IMAGE:latest")
    fi
    BUILD_CMD+=(--file "images/$IMAGE_NAME/Dockerfile")

    if [ "$PUSH_IMAGES" = "true" ] && [ "$PUSH_NECESSARY" = "true" ]; then
        BUILD_CMD+=(--platform "$PLATFORMS")
        BUILD_CMD+=(--push)
        BUILD_CMD+=(--sbom=true)
        BUILD_CMD+=(--provenance=true)
        BUILD_CMD+=(--cache-from "type=registry,ref=$CACHE_IMAGE:$VERSION")
        BUILD_CMD+=(--cache-to "type=registry,ref=$CACHE_IMAGE:$VERSION,mode=max")
        
        # Execute Build & Push
        "${BUILD_CMD[@]}" "images/$IMAGE_NAME"

        echo "Pushed $FULL_IMAGE:$VERSION"
        
        if command -v crane &> /dev/null; then
            DIGEST=$(crane digest "$FULL_IMAGE:$VERSION")
        else
            DIGEST=$(docker buildx imagetools inspect "$FULL_IMAGE:$VERSION" | grep "Digest:" | head -n 1 | awk '{print $2}')
        fi
        echo "Image Digest: $DIGEST"

        # Sign images with cosign
        if [ -n "$DIGEST" ] && command -v cosign &> /dev/null; then
            echo "Signing $FULL_IMAGE@$DIGEST with cosign..."
            cosign sign --yes "$FULL_IMAGE@$DIGEST"
        fi

        # Pass outputs to GitHub Actions
        if [ -n "${GITHUB_OUTPUT:-}" ]; then
            echo "digest=$DIGEST" >> "$GITHUB_OUTPUT"
            echo "image_full=$FULL_IMAGE:$VERSION" >> "$GITHUB_OUTPUT"
            echo "pushed=true" >> "$GITHUB_OUTPUT"
        fi
    elif [ "$PUSH_IMAGES" = "true" ] && [ "$PUSH_NECESSARY" = "false" ]; then
        # Image already in registry and matches
        if [ -n "${GITHUB_OUTPUT:-}" ]; then
            # We still need the digest for subsequent steps (like signing or notifications)
            DIGEST=$(crane digest "$FULL_IMAGE:$VERSION" 2>/dev/null || true)
            echo "digest=$DIGEST" >> "$GITHUB_OUTPUT"
            echo "image_full=$FULL_IMAGE:$VERSION" >> "$GITHUB_OUTPUT"
            echo "pushed=false" >> "$GITHUB_OUTPUT"
        fi
    else
        # Push not requested
        echo "Build Successful. Pushing disabled: $FULL_IMAGE:$VERSION"
        if [ -n "${GITHUB_OUTPUT:-}" ]; then
            echo "image_full=$FULL_IMAGE:$VERSION" >> "$GITHUB_OUTPUT"
            echo "pushed=false" >> "$GITHUB_OUTPUT"
        fi
    fi
done
