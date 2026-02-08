#!/usr/bin/env python3
"""Create a PR with updated pinned dependencies via the GitHub API.

Reads a report.json produced by check-pinned-deps.py, computes file replacements
in memory, and creates/updates a PR branch entirely through the GitHub API.
No local files are modified, no git commit/push is performed.

Usage:
    python3 ci/create-update-pr.py report.json

Requires:
    - GH_TOKEN environment variable (GitHub token with contents:write + pull-requests:write)
    - GITHUB_REPOSITORY environment variable (owner/repo)
    - gh CLI available in PATH
"""

import json
import os
import subprocess
import sys


BRANCH = "auto-update/pinned-deps"
BASE = "main"
COMMIT_MSG = "chore: update pinned dependency digests/SHAs"


def gh_api(endpoint, method="GET", input_data=None):
    """Call the GitHub API via gh CLI."""
    cmd = ["gh", "api"]
    if method != "GET":
        cmd += ["-X", method]
    cmd.append(endpoint)
    if input_data is not None:
        cmd += ["--input", "-"]
        result = subprocess.run(
            cmd, input=json.dumps(input_data), capture_output=True, text=True
        )
    else:
        result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode != 0:
        return None, result.stderr.strip()
    return json.loads(result.stdout) if result.stdout.strip() else {}, None


def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <report.json>", file=sys.stderr)
        sys.exit(1)

    report = json.load(open(sys.argv[1]))
    updates = report.get("updates", [])
    if not updates:
        print("No updates to apply", file=sys.stderr)
        sys.exit(0)

    repo = os.environ["GITHUB_REPOSITORY"]

    # Get base branch SHA
    data, err = gh_api(f"repos/{repo}/git/ref/heads/{BASE}")
    if err:
        print(f"Failed to get base branch: {err}", file=sys.stderr)
        sys.exit(1)
    base_sha = data["object"]["sha"]

    # Get base commit's tree SHA
    data, err = gh_api(f"repos/{repo}/git/commits/{base_sha}")
    if err:
        print(f"Failed to get base commit: {err}", file=sys.stderr)
        sys.exit(1)
    base_tree_sha = data["tree"]["sha"]

    # Group updates by file
    files_to_update = {}
    for u in updates:
        f = u["file"]
        if f not in files_to_update:
            files_to_update[f] = []
        files_to_update[f].append(u)

    # Build new tree entries from updated files
    tree_entries = []
    for filepath, file_updates in files_to_update.items():
        # Read the file from the local checkout (read-only)
        with open(filepath) as fh:
            content = fh.read()

        # Apply replacements in memory
        for u in file_updates:
            if u["type"] == "docker_digest":
                content = content.replace(u["current_digest"], u["latest_digest"])
            elif u["type"] == "action_pinned":
                content = content.replace(u["current_sha"], u["latest_sha"])

        # Create blob via API
        data, err = gh_api(
            f"repos/{repo}/git/blobs", method="POST",
            input_data={"content": content, "encoding": "utf-8"},
        )
        if err:
            print(f"Failed to create blob for {filepath}: {err}", file=sys.stderr)
            sys.exit(1)

        tree_entries.append({
            "path": filepath,
            "mode": "100644",
            "type": "blob",
            "sha": data["sha"],
        })

    # Create tree
    data, err = gh_api(
        f"repos/{repo}/git/trees", method="POST",
        input_data={"base_tree": base_tree_sha, "tree": tree_entries},
    )
    if err:
        print(f"Failed to create tree: {err}", file=sys.stderr)
        sys.exit(1)
    new_tree_sha = data["sha"]

    # Create commit
    data, err = gh_api(
        f"repos/{repo}/git/commits", method="POST",
        input_data={
            "message": COMMIT_MSG,
            "tree": new_tree_sha,
            "parents": [base_sha],
        },
    )
    if err:
        print(f"Failed to create commit: {err}", file=sys.stderr)
        sys.exit(1)
    new_commit_sha = data["sha"]
    print(f"Created commit {new_commit_sha[:12]}", file=sys.stderr)

    # Create or update branch ref
    data, err = gh_api(f"repos/{repo}/git/ref/heads/{BRANCH}")
    if err:
        # Branch doesn't exist — create it
        data, err = gh_api(
            f"repos/{repo}/git/refs", method="POST",
            input_data={"ref": f"refs/heads/{BRANCH}", "sha": new_commit_sha},
        )
        if err:
            print(f"Failed to create branch: {err}", file=sys.stderr)
            sys.exit(1)
        print(f"Created branch {BRANCH}", file=sys.stderr)
    else:
        # Branch exists — force update
        data, err = gh_api(
            f"repos/{repo}/git/refs/heads/{BRANCH}", method="PATCH",
            input_data={"sha": new_commit_sha, "force": True},
        )
        if err:
            print(f"Failed to update branch: {err}", file=sys.stderr)
            sys.exit(1)
        print(f"Updated branch {BRANCH}", file=sys.stderr)

    # Create PR if one doesn't already exist
    result = subprocess.run(
        ["gh", "pr", "list", "--head", BRANCH, "--state", "open",
         "--json", "number", "-q", ".[0].number"],
        capture_output=True, text=True,
    )
    existing_pr = result.stdout.strip()

    if not existing_pr:
        # Build PR body
        lines = ["## Summary", "",
                 "Automated update of pinned dependency digests and/or SHAs "
                 "detected by the nightly dependency checker.", "",
                 "### Updated dependencies", ""]
        for u in updates:
            if u["type"] == "docker_digest":
                lines.append(f"- **{u['image']}:{u['tag']}** in `{u['file']}`")
                lines.append(f"  - `{u['current_digest'][:19]}...` -> `{u['latest_digest'][:19]}...`")
            elif u["type"] == "action_pinned":
                lines.append(f"- **{u['action']}@{u['tag']}** in `{u['file']}`")
                lines.append(f"  - `{u['current_sha'][:12]}` -> `{u['latest_sha'][:12]}`")
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
        print(f"PR #{existing_pr} already exists, updated via branch force-push", file=sys.stderr)


if __name__ == "__main__":
    main()
