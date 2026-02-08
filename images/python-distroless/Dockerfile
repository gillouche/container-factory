ARG VERSION=3.13
# --- Stage 1: Donor ---
FROM python:${VERSION}-slim-bookworm AS donor

# --- Stage 2: Distroless Skeleton ---
FROM gcr.io/distroless/base-debian12:debug-nonroot
# Note: 'debug' variant includes busybox shell, useful for debugging. 
# Switch to 'nonroot' (no debug) for production strictness.

# Copy the entire /usr/local hierarchy which contains python binary, libs, include, bin
COPY --from=donor /usr/local /usr/local

# Copy shared libraries that Python might rely on (e.g. libexpat, libz)
# This is a heuristic. For absolute precision, one should run ldd.
# However, copying broadly from /usr/lib/aarch64-linux-gnu or x86_64 is tricky in multi-arch.
# Python slim is usually fairly self-contained in /usr/local, linking to libc (present in distroless-base).

# Set the entrypoint to the python binary
ENTRYPOINT ["/usr/local/bin/python3"]
