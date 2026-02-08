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


def find_repo_root():
    """Find the repository root (directory containing .git)."""
    path = Path(__file__).resolve().parent.parent
    if (path / ".git").exists():
        return path
    return Path.cwd()


def find_docker_digests(root):
    """Find all Docker FROM lines with @sha256: digests or unpinned references."""
    results = []
    dockerfiles = list(root.glob("**/Dockerfile"))
    for dockerfile in dockerfiles:
        content = dockerfile.read_text()
        # Collect ARG defaults for variable resolution
        args = {}
        for m in re.finditer(r"^ARG\s+(\w+)=(.+)$", content, re.MULTILINE):
            args[m.group(1)] = m.group(2).strip()

        for m in re.finditer(
            r"^FROM\s+(\S+?)(?:\s+AS\s+\w+)?\s*$", content, re.MULTILINE
        ):
            from_ref = m.group(1)

            # Resolve ${VAR} references using ARG defaults
            resolved = re.sub(
                r"\$\{(\w+)\}", lambda v: args.get(v.group(1), v.group(0)), from_ref
            )

            if "@sha256:" in resolved:
                base, digest = resolved.split("@sha256:", 1)
                digest = "sha256:" + digest
                if ":" in base:
                    image, tag = base.rsplit(":", 1)
                else:
                    image, tag = base, "latest"
                results.append(
                    {
                        "file": str(dockerfile.relative_to(root)),
                        "image": image,
                        "tag": tag,
                        "current_digest": digest,
                        "type": "docker_digest",
                    }
                )
            elif ":latest" in resolved or resolved.endswith(":latest"):
                if ":" in resolved:
                    image, tag = resolved.rsplit(":", 1)
                else:
                    image, tag = resolved, "latest"
                results.append(
                    {
                        "file": str(dockerfile.relative_to(root)),
                        "image": image,
                        "tag": tag,
                        "current_digest": None,
                        "type": "docker_unpinned",
                    }
                )
    return results


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

            # Skip local actions (./)
            if action.startswith("./"):
                continue

            # Extract tag comment if present (e.g., "# v4.2.2")
            line = content[m.start() : content.index("\n", m.start())]
            tag_match = re.search(r"#\s*(v\S+)", line)
            tag = tag_match.group(1) if tag_match else None

            if re.match(r"^[0-9a-f]{40}$", ref):
                results.append(
                    {
                        "file": str(wf.relative_to(root)),
                        "action": action,
                        "current_sha": ref,
                        "tag": tag,
                        "type": "action_pinned",
                    }
                )
            elif ref in ("main", "master"):
                results.append(
                    {
                        "file": str(wf.relative_to(root)),
                        "action": action,
                        "current_sha": None,
                        "tag": ref,
                        "type": "action_unpinned",
                    }
                )
    return results


def check_docker_update(image, tag):
    """Get the latest digest for a Docker image:tag using crane."""
    ref = f"{image}:{tag}"
    try:
        result = subprocess.run(
            ["crane", "digest", ref],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if result.returncode == 0:
            return result.stdout.strip()
        print(f"  [warn] crane digest failed for {ref}: {result.stderr.strip()}", file=sys.stderr)
        return None
    except FileNotFoundError:
        print("  [error] crane not found in PATH", file=sys.stderr)
        return None
    except subprocess.TimeoutExpired:
        print(f"  [warn] crane digest timed out for {ref}", file=sys.stderr)
        return None


def check_action_update(action, tag):
    """Get the latest commit SHA for a GitHub Action tag using gh api.

    Handles both lightweight and annotated tags.
    """
    owner_repo = action
    parts = owner_repo.split("/")
    if len(parts) > 2:
        owner_repo = "/".join(parts[:2])

    try:
        result = subprocess.run(
            ["gh", "api", f"repos/{owner_repo}/git/ref/tags/{tag}"],
            capture_output=True,
            text=True,
            timeout=30,
        )
        if result.returncode != 0:
            print(
                f"  [warn] gh api failed for {action}@{tag}: {result.stderr.strip()}",
                file=sys.stderr,
            )
            return None

        data = json.loads(result.stdout)
        obj = data.get("object", {})
        sha = obj.get("sha")
        obj_type = obj.get("type")

        # Annotated tags point to a "tag" object; dereference to get the commit
        if obj_type == "tag" and sha:
            result2 = subprocess.run(
                ["gh", "api", f"repos/{owner_repo}/git/tags/{sha}"],
                capture_output=True,
                text=True,
                timeout=30,
            )
            if result2.returncode == 0:
                tag_data = json.loads(result2.stdout)
                sha = tag_data.get("object", {}).get("sha", sha)

        return sha
    except FileNotFoundError:
        print("  [error] gh not found in PATH", file=sys.stderr)
        return None
    except subprocess.TimeoutExpired:
        print(f"  [warn] gh api timed out for {action}@{tag}", file=sys.stderr)
        return None


def main():
    root = find_repo_root()
    print(f"Scanning {root} ...", file=sys.stderr)

    docker_deps = find_docker_digests(root)
    action_deps = find_action_pins(root)

    updates = []
    warnings = []
    up_to_date = []

    # Check Docker digests
    for dep in docker_deps:
        if dep["type"] == "docker_unpinned":
            warnings.append(
                {
                    "file": dep["file"],
                    "image": dep["image"],
                    "tag": dep["tag"],
                    "reason": f"Unpinned image reference: {dep['image']}:{dep['tag']}",
                    "type": "docker_unpinned",
                }
            )
            continue

        print(f"  Checking {dep['image']}:{dep['tag']} ...", file=sys.stderr)
        latest = check_docker_update(dep["image"], dep["tag"])
        if latest is None:
            continue
        if latest != dep["current_digest"]:
            updates.append(
                {
                    "file": dep["file"],
                    "image": dep["image"],
                    "tag": dep["tag"],
                    "current_digest": dep["current_digest"],
                    "latest_digest": latest,
                    "type": "docker_digest",
                }
            )
        else:
            up_to_date.append(
                {
                    "file": dep["file"],
                    "image": dep["image"],
                    "tag": dep["tag"],
                    "digest": dep["current_digest"],
                    "type": "docker_digest",
                }
            )

    # Check GitHub Action SHAs
    for dep in action_deps:
        if dep["type"] == "action_unpinned":
            warnings.append(
                {
                    "file": dep["file"],
                    "action": dep["action"],
                    "ref": dep["tag"],
                    "reason": f"Unpinned action reference: {dep['action']}@{dep['tag']}",
                    "type": "action_unpinned",
                }
            )
            continue

        if not dep["tag"]:
            warnings.append(
                {
                    "file": dep["file"],
                    "action": dep["action"],
                    "current_sha": dep["current_sha"],
                    "reason": f"SHA-pinned action without tag comment: {dep['action']}@{dep['current_sha'][:12]}",
                    "type": "action_no_tag",
                }
            )
            continue

        print(f"  Checking {dep['action']}@{dep['tag']} ...", file=sys.stderr)
        latest = check_action_update(dep["action"], dep["tag"])
        if latest is None:
            continue
        if latest != dep["current_sha"]:
            updates.append(
                {
                    "file": dep["file"],
                    "action": dep["action"],
                    "tag": dep["tag"],
                    "current_sha": dep["current_sha"],
                    "latest_sha": latest,
                    "type": "action_pinned",
                }
            )
        else:
            up_to_date.append(
                {
                    "file": dep["file"],
                    "action": dep["action"],
                    "tag": dep["tag"],
                    "sha": dep["current_sha"],
                    "type": "action_pinned",
                }
            )

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
