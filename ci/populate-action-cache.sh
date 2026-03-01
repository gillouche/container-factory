#!/usr/bin/env bash
# Populate the GitHub Actions archive cache by downloading action tarballs
# through the Nexus proxy. This script is run as an init container in ARC
# runner pods to ensure actions are available from local cache.
#
# Usage: CACHE_DIR=/path/to/cache NEXUS_URL=https://nexus.gillouche.homelab populate-action-cache.sh [workflow_dir]
set -euo pipefail

CACHE_DIR="${CACHE_DIR:-/home/runner/action-archive-cache}"
NEXUS_URL="${NEXUS_URL:-https://nexus.gillouche.homelab}"
WORKFLOW_DIR="${1:-/home/runner/_work/_actions}"

# Parse workflow files from all repos that use our runners
# The script can also accept a directory of workflow YAML files as $1
parse_actions() {
  local search_dir="${1:-.github/workflows}"
  if [ ! -d "$search_dir" ]; then
    echo "No workflow directory found at $search_dir, skipping" >&2
    return
  fi
  grep -rhoP 'uses:\s+\K[^/]+/[^@]+@[a-f0-9]{40}' "$search_dir" 2>/dev/null | sort -u || true
}

download_action() {
  local ref="$1"
  local owner repo sha

  owner="${ref%%/*}"
  local rest="${ref#*/}"
  repo="${rest%%@*}"
  sha="${rest##*@}"

  local cache_subdir="${CACHE_DIR}/${owner}_${repo}"
  local cache_file="${cache_subdir}/${sha}.tar.gz"

  if [ -f "$cache_file" ]; then
    echo "CACHED: ${owner}/${repo}@${sha}"
    return 0
  fi

  mkdir -p "$cache_subdir"

  local url="${NEXUS_URL}/repository/github-codeload/${owner}/${repo}/tar.gz/${sha}"
  echo "FETCH:  ${owner}/${repo}@${sha}"
  if curl -fsSL --retry 2 --retry-delay 3 -o "$cache_file" "$url"; then
    echo "OK:     ${owner}/${repo}@${sha}"
  else
    echo "FAIL:   ${owner}/${repo}@${sha} (will be fetched at runtime)" >&2
    rm -f "$cache_file"
  fi
}

main() {
  mkdir -p "$CACHE_DIR"

  echo "=== Populating GitHub Actions archive cache ==="
  echo "Cache dir: $CACHE_DIR"
  echo "Nexus URL: $NEXUS_URL"

  local actions
  actions=$(parse_actions "$WORKFLOW_DIR")

  if [ -z "$actions" ]; then
    echo "No pinned actions found, nothing to cache"
    exit 0
  fi

  local total=0 cached=0 fetched=0 failed=0
  while IFS= read -r ref; do
    [ -z "$ref" ] && continue
    total=$((total + 1))
    if download_action "$ref"; then
      if [ -f "${CACHE_DIR}/${ref%%/*}_${ref#*/}" ] 2>/dev/null; then
        cached=$((cached + 1))
      else
        fetched=$((fetched + 1))
      fi
    else
      failed=$((failed + 1))
    fi
  done <<< "$actions"

  echo "=== Done: ${total} actions processed (${failed} failures) ==="
}

main "$@"
