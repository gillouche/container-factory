#!/usr/bin/env python3
import json
import os
import sys
import argparse


def get_base_images(dockerfile_path):
    """Return all FROM image references in the Dockerfile (handles multi-stage builds)."""
    if not os.path.exists(dockerfile_path):
        return []
    images = []
    with open(dockerfile_path, "r") as f:
        for line in f:
            if line.strip().upper().startswith("FROM "):
                # Extract image name (handling "AS ..." aliases)
                parts = line.strip().split()
                if len(parts) > 1:
                    images.append(parts[1])
    return images


def get_internal_deps(base_images, internal_registry_prefix):
    """Extract internal image dependency names from FROM references.

    Looks for references like:
      nexus.gillouche.homelab/docker-hosted/base/<image-name>:<tag>
    and returns a set of image names (e.g. {"tls-bundle", "actions-runner"}).
    """
    deps = set()
    for img in base_images:
        if "/docker-hosted/" in img and img.startswith(internal_registry_prefix):
            # "nexus.../docker-hosted/base/actions-runner:${VERSION}" → "actions-runner"
            after_hosted = img.split("/docker-hosted/")[-1]
            name = after_hosted.split("/")[-1]
            name = name.split(":")[0]
            name = name.split("@")[0]
            deps.add(name)
    return deps


def compute_levels(image_deps):
    """Assign build levels via topological sort.

    Level 1: images with no internal dependencies.
    Level N: images whose dependencies are all in levels < N.

    Returns a dict mapping image name → level number.
    """
    levels = {}
    remaining = set(image_deps.keys())

    current_level = 1
    while remaining:
        ready = set()
        for img in remaining:
            deps = image_deps[img]
            # An image is ready when all its deps have been assigned a level
            if deps.issubset(set(levels.keys())):
                ready.add(img)

        if not ready:
            unresolved = {img: image_deps[img] - set(levels.keys()) for img in remaining}
            print(f"Error: circular or unresolvable dependencies: {unresolved}", file=sys.stderr)
            sys.exit(1)

        for img in ready:
            levels[img] = current_level
        remaining -= ready
        current_level += 1

    return levels


def main():
    parser = argparse.ArgumentParser(description="Generate GitHub Actions matrix for container builds")
    parser.add_argument("--level", type=int, default=1,
                        help="Build level to output (1 = no deps, 2+ = increasing dependency depth)")
    parser.add_argument("--max-level", action="store_true",
                        help="Print the maximum build level and exit")
    args = parser.parse_args()

    images_dir = "images"

    if not os.path.exists(images_dir):
        print(f"Error: {images_dir} not found", file=sys.stderr)
        sys.exit(1)

    internal_registry_prefix = "nexus.gillouche.homelab"

    # Phase 1: Scan all images and their dependencies
    image_deps = {}
    image_versions = {}

    for image_name in sorted(os.listdir(images_dir)):
        image_path = os.path.join(images_dir, image_name)
        if not os.path.isdir(image_path):
            continue

        dockerfile_path = os.path.join(image_path, "Dockerfile")
        base_images = get_base_images(dockerfile_path)
        deps = get_internal_deps(base_images, internal_registry_prefix)
        image_deps[image_name] = deps

        # Collect versions
        versions = []
        variants_file = os.path.join(image_path, "VARIANTS")
        if os.path.isfile(variants_file):
            with open(variants_file, "r") as f:
                content = f.read()
                versions = [v.strip() for v in content.strip().split() if v.strip()]
        else:
            version_file = os.path.join(image_path, "VERSION")
            if os.path.isfile(version_file):
                with open(version_file, "r") as f:
                    v = f.read().strip()
                    if v:
                        versions.append(v)
        image_versions[image_name] = versions

    # Phase 2: Compute levels
    levels = compute_levels(image_deps)
    max_level = max(levels.values()) if levels else 0

    if args.max_level:
        print(max_level)
        return

    # Phase 3: Build matrix for the requested level
    include = []
    for image_name, level in sorted(levels.items()):
        if level != args.level:
            continue
        for version in image_versions.get(image_name, []):
            include.append({
                "image": image_name,
                "version": version
            })

    # Sort for deterministic output
    include.sort(key=lambda x: (x["image"], x["version"]))

    # Output JSON for GitHub Actions matrix
    print(json.dumps({"include": include}))


if __name__ == "__main__":
    main()
