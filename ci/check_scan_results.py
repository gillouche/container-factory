#!/usr/bin/env python3

import json
import sys
import os

def load_trivy_ignores(ignore_file):
    """
    Parses .trivyignore file.
    Returns a set of ignore patterns (CVEs, secrets, etc.).
    """
    ignores = set()
    if not os.path.exists(ignore_file):
        return ignores
        
    with open(ignore_file, 'r') as f:
        for line in f:
            # Strip comments first (e.g. "CVE-1234 # reason")
            if '#' in line:
                line = line.split('#', 1)[0]
            
            line = line.strip()
            
            # Skip empty lines
            if not line:
                continue
            ignores.add(line)
    return ignores

def main():
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <trivy-results.json> <.trivyignore>")
        sys.exit(1)

    json_file = sys.argv[1]
    ignore_file = sys.argv[2]

    # Load ignores
    ignores = load_trivy_ignores(ignore_file)
    print(f"Loaded {len(ignores)} ignores from {ignore_file}")
    
    # Load Trivy JSON
    try:
        with open(json_file, 'r') as f:
            data = json.load(f)
    except Exception as e:
        print(f"Error loading JSON results: {e}")
        sys.exit(1)

    unignored_findings = []
    used_ignores = set()

    results = data.get("Results", [])
    if not results:
        print("No results found in scan (scan passed clean).")
        # All ignores are stale if nothing was found
        # (Though technically secrets might still be there but filtered? No, JSON contains everything)
        pass 

    import fnmatch

    for result in results:
        target = result.get("Target", "unknown")
        
        # Check Vulnerabilities
        vulns = result.get("Vulnerabilities", [])
        for vuln in vulns:
            vuln_id = vuln.get("VulnerabilityID")
            pkg_name = vuln.get("PkgName", "unknown")
            title = vuln.get("Title", "No title")
            
            if vuln_id:
                if vuln_id in ignores:
                    used_ignores.add(vuln_id)
                else:
                    unignored_findings.append(f"[VULN] {vuln_id} ({pkg_name}): {title}")

        # Check Secrets
        secrets = result.get("Secrets", [])
        for secret in secrets:
            rule_id = secret.get("RuleID")
            title = secret.get("Title", "No title")
            # For secrets, the 'Target' in result is usually the file path, or 'Target' inside secret?
            # Trivy JSON output for secrets usually has 'Target' at the Result level (the file being scanned).
            # But sometimes secrets are inside a container image where Target is the image name.
            # Wait, `trivy image --output json` lists files in `Results[i].Target`.
            
            secret_file = target 
            
            is_ignored = False
            
            # 1. Check if RuleID is ignored (e.g. "aws-access-key")
            if rule_id and rule_id in ignores:
                used_ignores.add(rule_id)
                is_ignored = True
            
            # 2. Check if file path matches any glob in ignores
            if not is_ignored:
                # We need to check against all ignore patterns that look like globs (contain *, ?, etc or path separators)
                # Or just check all of them.
                for pattern in ignores:
                    # Heuristic: if pattern has a slash or glob char, treat as path pattern
                    # If it looks like CVE-..., skip
                    if pattern.startswith("CVE-") or pattern.startswith("GHSA-") or pattern.startswith("RUSTSEC-"):
                        continue
                        
                    if fnmatch.fnmatch(secret_file, pattern) or fnmatch.fnmatch(os.path.basename(secret_file), pattern):
                        used_ignores.add(pattern)
                        is_ignored = True
                        break
            
            if not is_ignored:
                 unignored_findings.append(f"[SECRET] {rule_id} in {secret_file}: {title}")

    # Report Findings
    if unignored_findings:
        print("\n[FAILURE] Unignored High/Critical findings detected:")
        for issue in unignored_findings:
            print(f"  {issue}")
    else:
        print("\n[SUCCESS] No unignored vulnerabilities found.")

    # Check Stale Ignores
    stale_ignores = ignores - used_ignores
    
    if stale_ignores:
        print("\n[STALE IGNORES] The following ignores are no longer detected and can be removed:")
        sorted_stale = sorted(stale_ignores)
        for item in sorted_stale:
            print(f"  - {item}")
            
        # Send Discord Notification if configured
        webhook_url = os.environ.get("DISCORD_WEBHOOK_SECURITY_NOTIFICATIONS")
        if webhook_url:
            print("Sending Discord notification for stale ignores...")
            image_context = os.environ.get("IMAGE_NAME", "Unknown Image")
            version_context = os.environ.get("VERSION", "Unknown Version")
            
            message = {
                "username": "Trivy Scanner",
                "content": f"\n**Security Update: {image_context}:{version_context}**\n\nThe following Trivy ignores are no longer detected and can be removed from `.trivyignore`:\n" + "\n".join([f"- `{item}`" for item in sorted_stale])
            }
            
            try:
                import urllib.request
                req = urllib.request.Request(
                    webhook_url, 
                    data=json.dumps(message).encode('utf-8'),
                    headers={'Content-Type': 'application/json', 'User-Agent': 'Trivy-Check-Script'}
                )
                with urllib.request.urlopen(req) as response:
                    print(f"Notification sent: {response.status} {response.reason}")
            except Exception as e:
                print(f"Failed to send Discord notification: {e}")
    
    # Exit 1 if unignored findings exist
    if unignored_findings:
        sys.exit(1)

if __name__ == "__main__":
    main()
