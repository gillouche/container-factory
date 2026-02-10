#!/usr/bin/env python3
"""Create a PR with updated pinned dependencies via git CLI.

Reads a report.json produced by check-pinned-deps.py, applies replacements
to local files, commits changes, and pushes a branch to create a PR.

Usage:
    python3 ci/create_update_pr.py report.json

Requires:
    - GH_TOKEN environment variable (for gh pr create)
    - GITHUB_REPOSITORY environment variable
    - git and gh CLI available in PATH
"""

import json
import os
import subprocess
import sys

BRANCH = "auto-update/pinned-deps"
BASE = "main"
COMMIT_MSG = "update: pinned dependency digests/SHAs"


def run_git(args, check=True):
    """Run a git command."""
    cmd = ["git"] + args
    result = subprocess.run(cmd, capture_output=True, text=True)
    if check and result.returncode != 0:
        print(f"Git command failed: {' '.join(cmd)}\n{result.stderr}", file=sys.stderr)
        sys.exit(1)
    return result


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <report.json>", file=sys.stderr)
        sys.exit(1)

    with open(sys.argv[1]) as f:
        report = json.load(f)

    updates = report.get("updates", [])
    if not updates:
        print("No updates to apply", file=sys.stderr)
        sys.exit(0)

    # Configure git identity
    run_git(["config", "user.name", "github-actions[bot]"])
    run_git(["config", "user.email", "41898282+github-actions[bot]@users.noreply.github.com"])

    # Create/Reset branch to start fresh from origin/main
    # This prevents stale state on persistent runners and ensures updates apply relative to current main
    print(f"Resetting branch {BRANCH} to origin/{BASE}...", file=sys.stderr)
    run_git(["fetch", "origin", BASE])
    run_git(["checkout", "-B", BRANCH, f"origin/{BASE}"])
    
    # Reset to matches with origin/main to avoid conflicts/stale state
    # But we might not have origin/main fetched fully if shallow.
    # Just ensure we start from current state (which is clean checkout of main).
    # If we are reusing the branch, we should merge main or reset.
    # For simplicity: We are on 'main' (from checkout), we branched off. 
    # If the branch existed remotely, we will force push over it anyway.
    
    # Apply updates to files
    files_to_update = {}
    for u in updates:
        f = u["file"]
        if f not in files_to_update:
            files_to_update[f] = []
        files_to_update[f].append(u)

    print("Applying updates to local files...", file=sys.stderr)
    for filepath, file_updates in files_to_update.items():
        try:
            with open(filepath, "r") as f:
                content = f.read()
            
            seen_refs = set()
            for u in file_updates:
                ref_key = (u["type"], u["raw_ref"])
                if ref_key in seen_refs:
                    continue
                seen_refs.add(ref_key)

                if u["type"] == "docker_digest":
                    content = content.replace(u["current_digest"], u["latest_digest"])
                elif u["type"] == "docker_unpinned":
                    # Pin unpinned Docker image: image:tag -> image:tag@digest
                    content = content.replace(u["raw_ref"], f"{u['raw_ref']}@{u['latest_digest']}")
                elif u["type"] == "action_pinned":
                    content = content.replace(u["current_sha"], u["latest_sha"])
                elif u["type"] == "action_unpinned":
                    # Pin unpinned Action: action@ref -> action@sha # ref
                    replacement = f"{u['action']}@{u['latest_sha']} # {u['tag']}"
                    content = content.replace(u["raw_ref"], replacement)
                elif u["type"] == "variant_update":
                    # Update version in VARIANTS file
                    content = content.replace(u["current_version"], u["latest_version"])

            with open(filepath, "w") as f:
                f.write(content)
            
            # Stage file
            run_git(["add", filepath])
            
        except FileNotFoundError:
            print(f"Warning: File {filepath} not found, skipping.", file=sys.stderr)

    # Check if there are changes
    res = run_git(["diff", "--cached", "--quiet"], check=False)
    if res.returncode == 0:
        print("No changes to commit.", file=sys.stderr)
        return

    # Commit
    print("Committing changes...", file=sys.stderr)
    run_git(["commit", "-m", COMMIT_MSG])

    # Push
    print(f"Pushing branch {BRANCH}...", file=sys.stderr)
    run_git(["push", "--force", "origin", BRANCH])

    # Create PR if needed
    print("Checking for existing PR...", file=sys.stderr)
    result = subprocess.run(
        ["gh", "pr", "list", "--head", BRANCH, "--state", "open",
         "--json", "number", "-q", ".[0].number"],
        capture_output=True, text=True,
    )
    existing_pr = result.stdout.strip()

    if not existing_pr:
        print("Creating Pull Request...", file=sys.stderr)
        # Build PR body
        lines = ["## Summary", "",
                 "Automated update of pinned dependency digests and/or SHAs "
                 "detected by the nightly dependency checker.", "",
                 "### Updated dependencies", ""]
        for u in updates:
            if u["type"] == "docker_digest":
                lines.append(f"- **{u['image']}:{u['tag']}** in `{u['file']}`")
                lines.append(f"  - `{u['current_digest'][:19]}...` -> `{u['latest_digest'][:19]}...`")
            elif u["type"] == "docker_unpinned":
                lines.append(f"- **{u['image']}:{u['tag']}** in `{u['file']}` (Pinned)")
                lines.append(f"  - `unpinned` -> `{u['latest_digest'][:19]}...`")
            elif u["type"] == "action_pinned":
                lines.append(f"- **{u['action']}@{u['tag']}** in `{u['file']}`")
                lines.append(f"  - `{u['current_sha'][:12]}` -> `{u['latest_sha'][:12]}`")
            elif u["type"] == "action_unpinned":
                lines.append(f"- **{u['action']}@{u['tag']}** in `{u['file']}` (Pinned)")
                lines.append(f"  - `unpinned` -> `{u['latest_sha'][:12]}`")
            elif u["type"] == "variant_update":
                lines.append(f"- **{u['file']}** (Version Update)")
                lines.append(f"  - `{u['current_version']}` -> `{u['latest_version']}`")
        
        lines += ["", "## Test plan", "",
                  "- [ ] Verify updated digests/SHAs resolve correctly",
                  "- [ ] Confirm nightly build passes with updated dependencies",
                  "", "Generated by the nightly pinned dependency checker"]
        body = "\n".join(lines)

        result = subprocess.run(
            ["gh", "pr", "create",
             "--title", COMMIT_MSG,
             "--body", body,
             "--head", BRANCH,
             "--base", BASE],
            capture_output=True, text=True,
        )
        if result.returncode != 0:
            print(f"Failed to create PR: {result.stderr.strip()}", file=sys.stderr)
            sys.exit(1)
        print(f"Created PR: {result.stdout.strip()}", file=sys.stderr)
    else:
        print(f"PR #{existing_pr} already exists.", file=sys.stderr)

if __name__ == "__main__":
    main()
