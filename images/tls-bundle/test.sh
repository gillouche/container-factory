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
if openssl x509 -in /tmp/test-nexus-ca.crt -noout -subject 2>/dev/null | grep -q "Homelab Root CA"; then
    echo "PASS: nexus-ca.crt contains Homelab Root CA"
else
    echo "FAIL: nexus-ca.crt does not contain Homelab Root CA"
    exit 1
fi

echo ""
echo "[2/3] Verifying Wolfi CA bundle..."
docker cp "$CID:/certs/wolfi-ca-certificates.crt" /tmp/test-ca-bundle.crt
if grep -q "Homelab Root CA" /tmp/test-ca-bundle.crt; then
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
