#!/usr/bin/env bash
set -euo pipefail

LOCAL_TAG=$1
EXPECTED_VERSION=$2

echo "Running Python smoke test against $LOCAL_TAG (expected Python ${EXPECTED_VERSION})..."

# Pipe test script into the container to avoid DIND volume mount issues
cat tests/python/hello.py | docker run --rm -i -e "EXPECTED_VERSION=$EXPECTED_VERSION" "$LOCAL_TAG" -
