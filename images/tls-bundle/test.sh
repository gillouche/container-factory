#!/usr/bin/env bash
set -euo pipefail

IMAGE=$1
VERSION=${2:-}

echo "=============================================="
echo "Smoke Testing TLS Bundle: $IMAGE"
echo "=============================================="

# FROM scratch images have no shell — use docker create + docker cp
CID=$(docker create --platform "linux/amd64" "$IMAGE" /dev/null)
trap 'docker rm "$CID" >/dev/null 2>&1; rm -f /tmp/test-nexus-ca.crt /tmp/test-ca-bundle.crt /tmp/test-java-cacerts' EXIT

echo ""
echo "[1/3] Verifying nexus-ca.crt..."
docker cp "$CID:/certs/nexus-ca.crt" /tmp/test-nexus-ca.crt
if grep -q "BEGIN CERTIFICATE" /tmp/test-nexus-ca.crt; then
    echo "PASS: nexus-ca.crt is a valid PEM certificate"
else
    echo "FAIL: nexus-ca.crt is not a valid PEM certificate"
    exit 1
fi

echo ""
echo "[2/3] Verifying Wolfi CA bundle..."
docker cp "$CID:/certs/wolfi-ca-certificates.crt" /tmp/test-ca-bundle.crt
# Match a unique base64 line from the Homelab Root CA cert inside the bundle
CERT_LINE=$(sed -n '2p' /tmp/test-nexus-ca.crt)
if grep -qF "$CERT_LINE" /tmp/test-ca-bundle.crt; then
    echo "PASS: CA bundle includes Homelab Root CA"
else
    echo "FAIL: CA bundle does not include Homelab Root CA"
    exit 1
fi

echo ""
echo "[3/3] Verifying Java truststore..."
docker cp "$CID:/certs/java-cacerts" /tmp/test-java-cacerts
if [ -s /tmp/test-java-cacerts ]; then
    echo "PASS: Java truststore exists and is non-empty"
else
    echo "FAIL: Java truststore is missing or empty"
    exit 1
fi

echo ""
echo "=============================================="
echo "All TLS Bundle smoke tests passed!"
echo "=============================================="
