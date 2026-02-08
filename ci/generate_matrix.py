#!/usr/bin/env python3
import json
import os
import sys
import argparse

def get_base_image(dockerfile_path):
    if not os.path.exists(dockerfile_path):
        return None
    with open(dockerfile_path, "r") as f:
        for line in f:
            if line.strip().upper().startswith("FROM "):
                # Extract image name (handling "AS ..." aliases)
                parts = line.strip().split()
                if len(parts) > 1:
                    return parts[1]
    return None

def main():
    parser = argparse.ArgumentParser(description="Generate GitHub Actions matrix for container builds")
    parser.add_argument("--level", type=int, choices=[1, 2], default=1, 
                        help="Build level: 1 (independent) or 2 (dependent on internal images)")
    args = parser.parse_args()

    include = []
    images_dir = "images"

    if not os.path.exists(images_dir):
        print(f"Error: {images_dir} not found")
        sys.exit(1)

    internal_registry_prefix = "nexus.gillouche.homelab"

    for image_name in sorted(os.listdir(images_dir)):
        image_path = os.path.join(images_dir, image_name)
        variants_file = os.path.join(image_path, "VARIANTS")
        dockerfile_path = os.path.join(image_path, "Dockerfile")

        if os.path.isdir(image_path):
            base_image = get_base_image(dockerfile_path)
            
            # Determine level
            is_level_2 = base_image and base_image.startswith(internal_registry_prefix)
            
            # Filter based on requested level
            if args.level == 1 and is_level_2:
                continue # Skip Level 2 images when requesting Level 1
                
            if args.level == 2 and not is_level_2:
                continue # Skip Level 1 images when requesting Level 2

            # Process variants/versions
            versions = []
            if os.path.isfile(variants_file):
                with open(variants_file, "r") as f:
                    content = f.read()
                    versions = [v.strip() for v in content.strip().split() if v.strip()]
            else:
                 version_file = os.path.join(image_path, "VERSION")
                 if os.path.isfile(version_file):
                     with open(version_file, "r") as f:
                         v = f.read().strip()
                         if v: versions.append(v)

            for version in versions:
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
