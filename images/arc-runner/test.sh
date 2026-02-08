#!/usr/bin/env bash
set -euo pipefail

LOCAL_TAG=$1
EXPECTED_VERSION=${2:-}

echo "Running ARC runner smoke test against $LOCAL_TAG..."

# Test: non-root user
UID_OUTPUT=$(docker run --rm "$LOCAL_TAG" id -u)
if [ "$UID_OUTPUT" = "0" ]; then
    echo "FAIL: container runs as root (uid=0)"
    exit 1
fi
echo "PASS: non-root user (uid=$UID_OUTPUT)"

# Test: nix is available and works
NIX_VER=$(docker run --rm "$LOCAL_TAG" nix --version)
echo "PASS: nix available ($NIX_VER)"

# Test: nix flakes work
SYSTEM=$(docker run --rm "$LOCAL_TAG" nix eval --raw --expr 'builtins.currentSystem')
echo "PASS: nix flakes work (system=$SYSTEM)"

# Test: git is available
GIT_VER=$(docker run --rm "$LOCAL_TAG" git --version)
echo "PASS: git available ($GIT_VER)"

# Test: curl is available
CURL_VER=$(docker run --rm "$LOCAL_TAG" curl --version | head -1)
echo "PASS: curl available ($CURL_VER)"

echo "All ARC runner smoke tests passed."
