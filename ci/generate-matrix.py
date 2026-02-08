#!/usr/bin/env python3
import json
import os
import sys

def main():
    include = []
    # Relative to project root
    images_dir = "images"

    if not os.path.exists(images_dir):
        print(f"Error: {images_dir} not found")
        sys.exit(1)

    for image_name in sorted(os.listdir(images_dir)):
        image_path = os.path.join(images_dir, image_name)
        variants_file = os.path.join(image_path, "VARIANTS")

        if os.path.isdir(image_path):
            if os.path.isfile(variants_file):
                with open(variants_file, "r") as f:
                    content = f.read()
                    versions = content.strip().split()
                    for version in versions:
                         if version.strip():
                            include.append({
                                "image": image_name,
                                "version": version.strip()
                            })
            else:
                 # Check for legacy VERSION file or single Dockerfile?
                 # build.sh handles fallback to VERSION file.
                 version_file = os.path.join(image_path, "VERSION")
                 if os.path.isfile(version_file):
                     with open(version_file, "r") as f:
                         version = f.read().strip()
                         if version:
                            include.append({
                                "image": image_name,
                                "version": version
                            })
                 # Else skip, or maybe just list image without version?
                 # But build.sh expects VARIANTS.
    
    # Sort for deterministic output
    include.sort(key=lambda x: (x["image"], x["version"]))
    
    # Output JSON for GitHub Actions matrix
    print(json.dumps({"include": include}))

if __name__ == "__main__":
    main()
