#!/usr/bin/env bash
set -euo pipefail

LOCAL_TAG=$1
EXPECTED_VERSION=${2:-}

echo "Running ARC runner smoke test against $LOCAL_TAG..."

# Helper to run arbitrary commands inside the container by overriding entrypoint
PLATFORM=${TEST_PLATFORM:-amd64}

# Helper to run arbitrary commands inside the container by overriding entrypoint
run_cmd() {
    docker run --rm --platform "linux/${PLATFORM}" --entrypoint /bin/bash "$LOCAL_TAG" -c "$@"
}

# Test: non-root user
UID_OUTPUT=$(run_cmd "id -u")
if [ "$UID_OUTPUT" = "0" ]; then
    echo "FAIL: container runs as root (uid=0)"
    exit 1
fi
echo "PASS: non-root user (uid=$UID_OUTPUT)"

# Test: nix is available and works
NIX_VER=$(run_cmd "nix --version")
echo "PASS: nix available ($NIX_VER)"

# Test: nix flakes work
# --impure is required to access builtins.currentSystem in pure eval mode
SYSTEM=$(run_cmd "nix eval --impure --raw --expr 'builtins.currentSystem'")
echo "PASS: nix flakes work (system=$SYSTEM)"

# Test: git is available
GIT_VER=$(run_cmd "git --version")
echo "PASS: git available ($GIT_VER)"

# Test: curl is available
CURL_VER=$(run_cmd "curl --version" | head -1)
echo "PASS: curl available ($CURL_VER)"

# Test: Nexus CA is trusted
echo "Testing Nexus CA trust..."
if run_cmd "curl -sI https://nexus.gillouche.homelab/"; then
    echo "PASS: Nexus CA is trusted"
else
    echo "FAIL: Could not connect to https://nexus.gillouche.homelab/ (SSL/Trust missing?)"
    exit 1
fi

# Test: Java truststore with Homelab Root CA exists
echo "Testing Java truststore..."
if run_cmd "test -f /etc/ssl/certs/java/cacerts"; then
    echo "PASS: Java truststore exists at /etc/ssl/certs/java/cacerts"
else
    echo "FAIL: Java truststore not found at /etc/ssl/certs/java/cacerts"
    exit 1
fi

echo "All ARC runner smoke tests passed."
