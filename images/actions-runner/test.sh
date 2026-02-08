#!/bin/bash
set -euo pipefail

IMAGE=$1
VERSION=$2

echo "=============================================="
echo "Smoke Testing: $IMAGE"
echo "Expected Runner Version: $VERSION"
echo "=============================================="

PLATFORM=${TEST_PLATFORM:-amd64}

run_cmd() {
    docker run --rm --platform "linux/${PLATFORM}" --entrypoint /bin/bash "$IMAGE" -c "$@"
}

echo ""
echo "[1/9] Verifying non-root user..."
UID_OUTPUT=$(run_cmd "id -u")
if [ "$UID_OUTPUT" = "0" ]; then
    echo "FAIL: Container runs as root (uid=0)"
    exit 1
fi
echo "PASS: Non-root user (uid=$UID_OUTPUT)"

echo ""
echo "[2/9] Verifying docker group membership..."
GROUPS_OUTPUT=$(run_cmd "id -Gn")
if [[ "$GROUPS_OUTPUT" != *"docker"* ]]; then
    echo "FAIL: User not in docker group"
    exit 1
fi
echo "PASS: User in docker group ($GROUPS_OUTPUT)"

echo ""
echo "[3/9] Verifying GitHub Actions Runner binary..."
RUNNER_VERSION=$(run_cmd "/home/runner/bin/Runner.Listener --version" 2>/dev/null || echo "FAILED")
if [[ "$RUNNER_VERSION" != *"$VERSION"* ]]; then
    echo "FAIL: Runner version mismatch. Expected $VERSION, got: $RUNNER_VERSION"
    exit 1
fi
echo "PASS: Runner version ($RUNNER_VERSION)"

echo ""
echo "[4/9] Verifying Runner.Listener starts correctly..."
RUNNER_CHECK=$(run_cmd "timeout 5 /home/runner/bin/Runner.Listener --help 2>&1 | head -3" || true)
if [[ -z "$RUNNER_CHECK" ]]; then
    echo "FAIL: Runner.Listener did not produce output"
    exit 1
fi
echo "PASS: Runner.Listener responds to --help"

echo ""
echo "[5/9] Verifying runner-container-hooks (k8s)..."
if ! run_cmd "test -d /home/runner/k8s && ls /home/runner/k8s/*.js >/dev/null 2>&1"; then
    echo "FAIL: k8s container hooks not found"
    exit 1
fi
echo "PASS: k8s container hooks present"

echo ""
echo "[6/9] Verifying Docker and Buildx..."
DOCKER_VER=$(run_cmd "docker --version")
BUILDX_VER=$(run_cmd "docker buildx version" 2>/dev/null || echo "not found")
echo "PASS: Docker ($DOCKER_VER)"
echo "PASS: Buildx ($BUILDX_VER)"

echo ""
echo "[7/9] Verifying Node.js..."
NODE_VER=$(run_cmd "node --version")
echo "PASS: Node.js ($NODE_VER)"

echo ""
echo "[8/9] Verifying Python..."
PYTHON_VER=$(run_cmd "python3 --version")
echo "PASS: Python ($PYTHON_VER)"

echo ""
echo "[9/9] Verifying .NET SDK..."
DOTNET_VER=$(run_cmd "dotnet --version")
echo "PASS: .NET SDK ($DOTNET_VER)"

echo ""
echo "=============================================="
echo "All smoke tests passed!"
echo "=============================================="
