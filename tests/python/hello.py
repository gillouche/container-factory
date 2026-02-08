import sys
import os
import ssl
import json
import hashlib
import urllib.request

# Verify non-root execution
uid = os.getuid()
assert uid != 0, f"Container must not run as root (got uid={uid})"

# Verify Python version matches expected (if provided via env)
expected = os.environ.get("EXPECTED_VERSION")
if expected:
    actual = f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}"
    assert actual == expected, f"Version mismatch: expected {expected}, got {actual}"

print(f"Python version: {sys.version}")
print(f"Running as uid: {uid}")
print("All smoke test assertions passed.")
