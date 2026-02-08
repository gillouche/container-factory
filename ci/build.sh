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

# Default to False
PUSH_IMAGES=${PUSH_IMAGES:-false}
SCAN_IMAGES=${SCAN_IMAGES:-false}

# If pushing, we implies scanning (unless disabled explicitly?? No, let's just force it for safety)
if [ "$PUSH_IMAGES" = "true" ]; then
    SCAN_IMAGES="true"
fi

# Determine the highest version for the "latest" tag (semver sort)
LATEST_VERSION=$(echo "$VARIANTS" | sort -t. -k1,1n -k2,2n -k3,3n | tail -1)

# Build Loop
for VERSION in $VARIANTS; do
    # User requested docker-hosted/base/ structure
    FULL_IMAGE="$REGISTRY/$NAMESPACE/base/$IMAGE_NAME"
    echo "=================================================="
    echo "Building $FULL_IMAGE:$VERSION ($PLATFORMS)"
    echo "Push Enabled: $PUSH_IMAGES"
    echo "Scan Enabled: $SCAN_IMAGES"
    echo "=================================================="

    # Create builder if needed (DIND supports buildx)
    if ! docker buildx version > /dev/null 2>&1; then
        echo "Error: 'docker buildx' is not available. Please install the Docker Buildx plugin."
        exit 1
    fi

    if ! docker buildx inspect homelab-builder > /dev/null 2>&1; then
        docker buildx create --name homelab-builder --driver docker-container
        docker buildx use homelab-builder
        docker buildx inspect --bootstrap
    fi

    # ---------------------------------------------------------
    # 1. Pre-flight Verification (Scan + Smoke Test)
    # ---------------------------------------------------------
    if [ "$SCAN_IMAGES" = "true" ]; then
        echo "Pre-flight verification (linux/amd64)..."
        
        # Build local image for verification
        LOCAL_TAG="local-scan-$IMAGE_NAME:$VERSION"
        
        # We must build a single arch to load it into the local daemon
        docker buildx build \
            --load \
            --platform linux/amd64 \
            --build-arg VERSION="$VERSION" \
            --tag "$LOCAL_TAG" \
            --file "images/$IMAGE_NAME/Dockerfile" \
            "images/$IMAGE_NAME"
            
        # 1.1 Security Scan
        if command -v trivy &> /dev/null; then
            echo "Running Trivy..."
            # Explicitly capture exit code to ensure failure stops the build
            if ! trivy image --exit-code 1 --severity HIGH,CRITICAL --ignore-unfixed "$LOCAL_TAG"; then
                echo "Trivy found Critical/High vulnerabilities!"
                docker rmi "$LOCAL_TAG" || true
                exit 1
            fi
            echo "Scan passed."
        else
            echo "Trivy not found. Skipping security scan."
        fi
        
        # 1.2 Smoke Test
        # Determine test script based on image name
        TEST_SCRIPT=""
        if [[ "$IMAGE_NAME" == *"python"* ]]; then
            TEST_SCRIPT="/tests/python/hello.py"
        fi

        if [ -n "$TEST_SCRIPT" ]; then
            echo "Running Smoke Test ($TEST_SCRIPT)..."
            if docker run --rm -v "$(pwd)/tests:/tests" "$LOCAL_TAG" "$TEST_SCRIPT"; then
                 echo "Smoke Test Passed!"
            else
                 echo "Smoke Test Failed!"
                 docker rmi "$LOCAL_TAG" || true
                 exit 1
            fi
        else
            echo "No smoke test defined for $IMAGE_NAME"
        fi
        
        # Cleanup
        docker rmi "$LOCAL_TAG" || true
        
    else
        echo "Skipping Pre-flight Verification (SCAN_IMAGES=false)"
    fi

    # ---------------------------------------------------------
    # 2. Multi-Arch Build & Push
    # ---------------------------------------------------------
    
    # Construct Build Command
    BUILD_CMD=(docker buildx build)
    BUILD_CMD+=(--platform "$PLATFORMS")
    BUILD_CMD+=(--build-arg VERSION="$VERSION")
    BUILD_CMD+=(--tag "$FULL_IMAGE:$VERSION")

    # Only tag the highest version as "latest"
    if [ "$VERSION" = "$LATEST_VERSION" ]; then
        BUILD_CMD+=(--tag "$FULL_IMAGE:latest")
    fi
    BUILD_CMD+=(--file "images/$IMAGE_NAME/Dockerfile")
    
    if [ "$PUSH_IMAGES" = "true" ]; then
        BUILD_CMD+=(--push)
        BUILD_CMD+=(--sbom=true)
    else
        # partial output to avoid loading all multi-arch layers into local docker daemon
        echo "Dry Run (Push disabled)"
    fi

    # Execute Build
    "${BUILD_CMD[@]}" "images/$IMAGE_NAME"

    if [ "$PUSH_IMAGES" = "true" ]; then
        echo "Pushed $FULL_IMAGE:$VERSION"
        echo "=================================================="
        echo "Manifest Details:"
        docker buildx imagetools inspect "$FULL_IMAGE:$VERSION"
        echo "=================================================="

        # Sign images with cosign (keyless via OIDC in CI)
        if command -v cosign &> /dev/null; then
            echo "Signing $FULL_IMAGE:$VERSION with cosign..."
            cosign sign --yes "$FULL_IMAGE:$VERSION"
            if [ "$VERSION" = "$LATEST_VERSION" ]; then
                cosign sign --yes "$FULL_IMAGE:latest"
            fi
            echo "Image signed successfully."
        else
            echo "Warning: cosign not found, skipping image signing."
        fi
    else
        echo "Build Successful. Would have pushed: $FULL_IMAGE:$VERSION"
    fi
done
