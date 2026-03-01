#!/usr/bin/env python3
"""Check pinned dependencies (Docker digests + GitHub Action SHAs) for updates.

Read-only scanner: discovers all pinned dependencies in Dockerfiles and GitHub
Actions workflows, checks registries/APIs for newer versions, and outputs a
JSON report to stdout. Does NOT modify any files.

Usage:
    python3 ci/check-pinned-deps.py    # JSON report to stdout
"""

import json
import re
import subprocess
import sys
from pathlib import Path

# Actions allowed to use branch references (e.g. @main) without triggering
# unpinned-dependency warnings.  Each entry is matched as a prefix against the
# action name so "gillouche/homelab-ci" covers all sub-paths like
# "gillouche/homelab-ci/actions/discord-notify".
IGNORED_ACTIONS = [
    "gillouche/homelab-ci",
]


def find_repo_root():
    """Find the repository root (directory containing .git)."""
    path = Path(__file__).resolve().parent.parent
    if (path / ".git").exists():
        return path
    return Path.cwd()


def find_docker_digests(root):
    """Docker digest pinning is no longer enforced. Return empty list."""
    return []


def find_action_pins(root):
    """Find all GitHub Actions `uses:` references with SHA pins or unpinned refs."""
    results = []
    workflow_files = list(root.glob(".github/**/*.yaml")) + list(
        root.glob(".github/**/*.yml")
    )
    for wf in workflow_files:
        content = wf.read_text()
        for m in re.finditer(
            r"^\s*-?\s*uses:\s+([^@\s]+)@(\S+)", content, re.MULTILINE
        ):
            action = m.group(1)
            ref = m.group(2)
            raw_ref = f"{action}@{ref}"

            # Skip local actions (./)
            if action.startswith("./"):
                continue

            # Skip actions on the ignore list (allowed to use @main)
            if any(action.startswith(prefix) for prefix in IGNORED_ACTIONS):
                continue

            # Extract tag comment if present (e.g., "# v4.2.2" or "# main")
            line = content[m.start() : content.index("\n", m.start())]
            tag_match = re.search(r"#\s*(\S+)", line)
            tag = tag_match.group(1) if tag_match else None

            if re.match(r"^[0-9a-f]{40}$", ref):
                results.append(
                    {
                        "file": str(wf.relative_to(root)),
                        "action": action,
                        "current_sha": ref,
                        "tag": tag,
                        "type": "action_pinned",
                        "raw_ref": raw_ref,
                    }
                )
            else:
                # Unpinned branch or tag
                results.append(
                    {
                        "file": str(wf.relative_to(root)),
                        "action": action,
                        "current_sha": None,
                        "tag": ref, # In this case tag is the ref (e.g. main)
                        "type": "action_unpinned",
                        "raw_ref": raw_ref,
                    }
                )
    return results


def check_action_update(action, ref):
    """Get the latest commit SHA for a GitHub Action ref using gh api."""
    owner_repo = action
    parts = owner_repo.split("/")
    if len(parts) > 2:
        owner_repo = "/".join(parts[:2])

    try:
        # Use commits API to resolve any ref (branch, tag, sha) to a commit SHA
        result = subprocess.run(
            ["gh", "api", f"repos/{owner_repo}/commits/{ref}", "--header", "Accept: application/vnd.github+json"],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if result.returncode != 0:
            print(
                f"  [warn] gh api failed for {action}@{ref}: {result.stderr.strip()}",
                file=sys.stderr,
            )
            return None

        data = json.loads(result.stdout)
        return data.get("sha")
    except FileNotFoundError:
        print("  [error] gh not found in PATH", file=sys.stderr)
        return None
    except subprocess.TimeoutExpired:
        print(f"  [warn] gh api timed out for {action}@{ref}", file=sys.stderr)
        return None


def main():
    root = find_repo_root()
    print(f"Scanning {root} ...", file=sys.stderr)

    action_deps = find_action_pins(root)

    updates = []
    warnings = []
    up_to_date = []

    # Check GitHub Action SHAs
    for dep in action_deps:
        tag_or_ref = dep["tag"] # For unpinned, this is the ref (main)
        
        if dep["type"] == "action_no_tag":
             # Still a warning, manual fix needed
            warnings.append({
                "file": dep["file"],
                "action": dep["action"],
                "current_sha": dep["current_sha"],
                "reason": f"SHA-pinned action without tag comment",
                "type": "action_no_tag"
            })
            continue

        print(f"  Checking {dep['action']}@{tag_or_ref} ...", file=sys.stderr)
        latest = check_action_update(dep["action"], tag_or_ref)
        
        if latest is None:
             warnings.append({
                "file": dep["file"],
                "action": dep["action"],
                "ref": tag_or_ref,
                "reason": f"Could not check update for {dep['action']}@{tag_or_ref}",
                "type": dep["type"]
            })
             continue
        
        if dep["type"] == "action_unpinned":
            updates.append({
                "file": dep["file"],
                "action": dep["action"],
                "tag": tag_or_ref,
                "current_sha": None,
                "latest_sha": latest,
                "type": "action_unpinned",
                "raw_ref": dep["raw_ref"]
            })
        elif latest != dep["current_sha"]:
             updates.append({
                "file": dep["file"],
                "action": dep["action"],
                "tag": dep["tag"],
                "current_sha": dep["current_sha"],
                "latest_sha": latest,
                "type": "action_pinned",
                "raw_ref": dep["raw_ref"]
            })
        else:
             up_to_date.append({
                "file": dep["file"],
                "action": dep["action"],
                "tag": dep["tag"], # For unpinned this might be misleading in 'up_to_date'? 
                # If unpinned deps shouldn't be 'up_to_date', I should change logic.
                # But if we pinned it now, it goes to updates.
                # Wait, if I run this script on already unpinned file, it ALWAYS says update (pin it).
                # Good.
                "sha": dep.get("current_sha"),
                "type": "action_pinned",
                "raw_ref": dep["raw_ref"]
            })

    report = {
        "updates": updates,
        "warnings": warnings,
        "up_to_date": up_to_date,
    }

    # JSON report to stdout
    print(json.dumps(report, indent=2))

    # Summary to stderr
    print(
        f"\nSummary: {len(updates)} update(s), {len(warnings)} warning(s), "
        f"{len(up_to_date)} up-to-date",
        file=sys.stderr,
    )


if __name__ == "__main__":
    main()
