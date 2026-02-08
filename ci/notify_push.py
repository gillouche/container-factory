#!/usr/bin/env python3
import os
import sys
import json
import urllib.request

def main():
    if len(sys.argv) < 4:
        print(f"Usage: {sys.argv[0]} <image_name> <tags> <digest>")
        sys.exit(1)

    image_name = sys.argv[1]
    tags = sys.argv[2] # Version
    digest = sys.argv[3]
    
    webhook_url = os.environ.get("DISCORD_WEBHOOK")
    if not webhook_url:
        print("Skipping notification: DISCORD_WEBHOOK not set.")
        sys.exit(0)

    print(f"Sending Discord notification for {image_name}:{tags}...")

    # Format the message
    # e.g. "New Image Pushed: docker-hosted/base/arc-runner:2.331.0"
    #      "Digest: sha256:..."
    
    content = (
        f"**New Image Pushed**\n"
        f"**Image:** `{image_name}`\n"
        f"**Tag:** `{tags}`\n"
        f"**Digest:** `{digest}`\n"
        f"\nUpdate your manifests to use this secure pinning!"
    )

    message = {
        "username": "Container Factory",
        "content": content
    }

    try:
        req = urllib.request.Request(
            webhook_url, 
            data=json.dumps(message).encode('utf-8'),
            headers={'Content-Type': 'application/json', 'User-Agent': 'Container-Factory-Notifier'}
        )
        with urllib.request.urlopen(req) as response:
            print(f"Notification sent: {response.status} {response.reason}")
    except Exception as e:
        print(f"Failed to send Discord notification: {e}")
        # Do not fail the build for a notification failure
        sys.exit(0)

if __name__ == "__main__":
    main()
