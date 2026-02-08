#!/usr/bin/env bash
set -euo pipefail

IMAGE_NAME=$1
TARGET_VERSION=${2:-}
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

if ! docker buildx inspect homelab-builder > /dev/null 2>&1; then
    docker buildx create --name homelab-builder --driver docker-container
    docker buildx use homelab-builder
    docker buildx inspect --bootstrap
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
            # Generate JSON report (do not fail here, let the python script decide)
            # We run without ignores to detect stale entries
            echo "Generating Trivy report..."
            TRIVY_JSON="trivy-results.json"
            trivy image --format json --output "$TRIVY_JSON" --severity HIGH,CRITICAL --ignore-unfixed "$LOCAL_TAG"
            
            # Run analysis script
            IGNORE_FILE="images/$IMAGE_NAME/.trivyignore"
            if [ ! -f "$IGNORE_FILE" ]; then
                IGNORE_FILE="/dev/null"
            fi
            
            echo "Analyzing scan results..."
            echo "Analyzing scan results..."
            # Pass env vars for the script to use in Discord notifications
            # Do NOT export them globally as it overwrites script variables like IMAGE_NAME
            
            if ! DISCORD_WEBHOOK="$DISCORD_WEBHOOK_SECURITY_NOTIFICATIONS" IMAGE_NAME="$FULL_IMAGE" VERSION="$VERSION" python3 ci/check_scan_results.py "$TRIVY_JSON" "$IGNORE_FILE"; then
                echo "Security check failed!"
                docker rmi "$LOCAL_TAG" || true
                exit 1
            fi
            echo "Scan passed."
        else
            echo "Trivy not found. Skipping security scan."
        fi
        
        # 1.2 Smoke Test (convention-based: images/$IMAGE_NAME/test.sh)
        TEST_SCRIPT="images/$IMAGE_NAME/test.sh"
        if [ -f "$TEST_SCRIPT" ]; then
            echo "Running smoke test ($TEST_SCRIPT)..."
            if bash "$TEST_SCRIPT" "$LOCAL_TAG" "$VERSION"; then
                echo "Smoke test passed!"
            else
                echo "Smoke test failed!"
                docker rmi "$LOCAL_TAG" || true
                exit 1
            fi
        else
            echo "Warning: No smoke test found for $IMAGE_NAME (no test.sh)"
        fi

        # Save image ID for idempotency check before cleanup
        if [ "$PUSH_IMAGES" = "true" ]; then
            LOCAL_ID=$(docker inspect --format='{{.Id}}' "$LOCAL_TAG")
        fi

        # Cleanup
        docker rmi "$LOCAL_TAG" || true
    else
        echo "Skipping Pre-flight Verification (SCAN_IMAGES=false)"
    fi

    # ---------------------------------------------------------
    # 2. Check for Idempotency (if Pushing)
    # ---------------------------------------------------------
    if [ "$PUSH_IMAGES" = "true" ] && command -v crane &> /dev/null && [ -n "${LOCAL_ID:-}" ]; then
        echo "Checking if push is necessary..."
        # LOCAL_ID was saved before cleanup in the pre-flight section.
        # Get Remote Config Digest (this matches Image ID for OCI/Docker v2.2)
        REMOTE_ID=$(crane config "$FULL_IMAGE:$VERSION" 2>/dev/null | sha256sum | awk '{print "sha256:"$1}')

        if [ "$LOCAL_ID" = "$REMOTE_ID" ]; then
             echo "Image $FULL_IMAGE:$VERSION (linux/amd64) matches remote config. Skipping push."
             continue
        else
             echo "Config differs (Local: ${LOCAL_ID:0:12} Remote: ${REMOTE_ID:0:12}). Proceeding to push..."
        fi
    fi

    # ---------------------------------------------------------
    # 3. Multi-Arch Build & Push
    # ---------------------------------------------------------
    
    # Construct Build Command
    BUILD_CMD=(docker buildx build)
    BUILD_CMD+=(--build-arg VERSION="$VERSION")
    BUILD_CMD+=(--label "org.opencontainers.image.created=$(date -u +%Y-%m-%dT%H:%M:%SZ)")
    BUILD_CMD+=(--label "org.opencontainers.image.revision=$(git rev-parse HEAD)")
    BUILD_CMD+=(--tag "$FULL_IMAGE:$VERSION")

    # Only tag the highest version as "latest"
    if [ "$VERSION" = "$LATEST_VERSION" ]; then
        BUILD_CMD+=(--tag "$FULL_IMAGE:latest")
    fi
    BUILD_CMD+=(--file "images/$IMAGE_NAME/Dockerfile")

    if [ "$PUSH_IMAGES" = "true" ]; then
        BUILD_CMD+=(--platform "$PLATFORMS")
        BUILD_CMD+=(--push)
        BUILD_CMD+=(--sbom=true)
        BUILD_CMD+=(--provenance=true)
        BUILD_CMD+=(--cache-from "type=registry,ref=$CACHE_IMAGE:$VERSION")
        BUILD_CMD+=(--cache-to "type=registry,ref=$CACHE_IMAGE:$VERSION,mode=max")
    else
        # Single-platform build loaded into local daemon for validation
        BUILD_CMD+=(--load)
        echo "Local build (single-platform, loaded into local daemon)"
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

        # Send Discord Notification
        # Retrieve Digest from imagetools (more reliable than build output)
        DIGEST=$(docker buildx imagetools inspect "$FULL_IMAGE:$VERSION" --format "{{ .Manifest.Digest }}")
        echo "Image Digest: $DIGEST"
        
        # Only notify if we pushed a new image (which we did if we are here)
        DISCORD_WEBHOOK="$DISCORD_WEBHOOK_GITHUB_ACTIONS" python3 ci/notify_push.py "$FULL_IMAGE" "$VERSION" "$DIGEST"
    else
        echo "Build Successful. Would have pushed: $FULL_IMAGE:$VERSION"
    fi
done
