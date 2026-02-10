#!/usr/bin/env python3
import json
import os
import re
import sys
import subprocess
from pathlib import Path

CONFIG_FILE = Path(__file__).parent / "upstream_config.json"

def run_cmd(args):
    """Run command and return stdout."""
    try:
        res = subprocess.run(args, capture_output=True, text=True, check=True)
        return res.stdout.strip()
    except subprocess.CalledProcessError:
        return None
    except FileNotFoundError:
        return None

def get_github_releases(repo, prefix="v"):
    """Get list of clean version strings from GitHub Releases."""
    # gh release list returns: Title \t Type \t Tag \t Date
    out = run_cmd(["gh", "release", "list", "-R", repo, "--limit", "30", "--exclude-drafts", "--exclude-pre-releases"])
    if not out:
        return []
    versions = []
    for line in out.splitlines():
        parts = line.split("\t")
        if len(parts) >= 3:
            tag = parts[2]
            if tag.startswith(prefix):
                versions.append(tag[len(prefix):])
            else:
                 # Should we try to parse it anyway if prefix missing?
                 # Assuming strict prefix for now.
                 pass
    return versions

def get_docker_tags(image):
    """Get list of tags from registry."""
    out = run_cmd(["crane", "ls", image])
    if not out:
        return []
    return out.splitlines()

class Version:
    """Simple semantic version parser."""
    def __init__(self, v_str):
        self.raw = v_str
        # Extract numeric components
        self.parts = [int(p) for p in re.findall(r'\d+', v_str)]
        self.major = self.parts[0] if len(self.parts) > 0 else 0
        self.minor = self.parts[1] if len(self.parts) > 1 else 0
        self.micro = self.parts[2] if len(self.parts) > 2 else 0

    def __lt__(self, other): return self.parts < other.parts
    def __gt__(self, other): return self.parts > other.parts
    def __eq__(self, other): return self.parts == other.parts
    def __repr__(self): return str(self.parts)

def check_version_update(curr_ver, available_versions, strict_minor=False, tag_template=None):
    """Find the highest version upgrade."""
    try:
        curr = Version(curr_ver)
    except:
        return None
    
    candidates = []
    for v_str in available_versions:
        clean_v = v_str
        
        # Extract version from tag template if needed
        if tag_template:
            # Escape template chars, make {version} a capture group
            pattern = "^" + re.escape(tag_template).replace(re.escape("{version}"), "(.*)") + "$"
            m = re.match(pattern, v_str)
            if m:
                clean_v = m.group(1)
            else:
                continue
                
        # Filter unstable versions (letters indicate alpha/beta/rc usually)
        if re.search(r'[a-zA-Z]', clean_v):
            continue
            
        try:
            v_obj = Version(clean_v)
            if not v_obj.parts: continue

            # Compare
            if v_obj > curr:
                # Enforce major match
                if v_obj.major != curr.major:
                    continue
                
                # Enforce minor match if strict mode (multiple tracks detected)
                if strict_minor and v_obj.minor != curr.minor:
                    continue
                    
                candidates.append(clean_v)
        except:
            continue
            
    if not candidates:
        return None
        
    # Sort by version (parsed)
    candidates.sort(key=lambda x: Version(x), reverse=True)
    return candidates[0]

def main():
    if not CONFIG_FILE.exists():
        print(json.dumps({"updates": []}))
        return

    with open(CONFIG_FILE) as f:
        config = json.load(f)

    updates = []
    
    for filepath, cfg in config.items():
        if not os.path.exists(filepath):
            continue
            
        with open(filepath) as f:
            content = f.read().strip()
            
        current_versions = [line.strip() for line in content.splitlines() if line.strip()]
        if not current_versions:
            continue
            
        print(f"Checking {filepath} ({len(current_versions)} versions)...", file=sys.stderr)
        
        # Determine strict minor mode: if multiple distinct minors exist for same major, restrict updates.
        majors = {}
        for cv in current_versions:
             try:
                 v = Version(cv)
                 if v.major not in majors: majors[v.major] = set()
                 majors[v.major].add(v.minor)
             except: pass
        
        # Fetch upstream once
        if cfg["source"] == "github_release":
            available = get_github_releases(cfg["repo"], cfg.get("prefix", "v"))
        elif cfg["source"] == "docker_hub":
            available = get_docker_tags(cfg["image"])
        else:
            available = []
            
        if not available:
            print(f"  No upstream versions found.", file=sys.stderr)
            continue
        
        print(f"  Found {len(available)} upstream tags.", file=sys.stderr)
            
        for cv in current_versions:
            try:
                curr_obj = Version(cv)
                strict = len(majors.get(curr_obj.major, [])) > 1
                
                latest = check_version_update(cv, available, strict, cfg.get("tag_template"))
                
                if latest and latest != cv:
                    # Restore prefix if needed
                    # If local used 'v' but source is bare (github releases cleaned it)
                    if cv.startswith('v') and not latest.startswith('v'):
                        latest = 'v' + latest
                        
                    print(f"  Found update: {cv} -> {latest}", file=sys.stderr)
                    updates.append({
                        "file": filepath,
                        "current_version": cv,
                        "latest_version": latest,
                        "type": "variant_update",
                        "raw_ref": cv
                    })
                else:
                    print(f"  {cv} is up-to-date", file=sys.stderr)
            except Exception as e:
                print(f"  Error checking {cv}: {e}", file=sys.stderr)

    print(json.dumps({"updates": updates}, indent=2))

if __name__ == "__main__":
    main()
