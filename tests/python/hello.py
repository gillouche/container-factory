import sys
import os

# Verify non-root execution
uid = os.getuid()
assert uid != 0, f"Container must not run as root (got uid={uid})"

# Verify Python version matches expected (if provided via env)
expected = os.environ.get("EXPECTED_VERSION")
if expected:
    actual = f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}"
    assert actual == expected, f"Version mismatch: expected {expected}, got {actual}"

# Verify standard library modules load correctly
import ssl
import json
import sqlite3
import hashlib
import urllib.request

print(f"Python version: {sys.version}")
print(f"Running as uid: {uid}")
print("All smoke test assertions passed.")
