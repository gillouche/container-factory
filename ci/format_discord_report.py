#!/usr/bin/env python3
import sys
import json
import argparse
import os

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("report_file")
    parser.add_argument("--type", choices=["updates", "warnings", "success"], required=True)
    args = parser.parse_args()

    with open(args.report_file) as f:
        report = json.load(f)

    fields = []
    
    if args.type == "updates":
        # Docker updates
        for u in report.get("updates", []):
            if u["type"] == "docker_digest":
                fields.append({
                    "name": f"{u['image']}:{u['tag']}",
                    "value": f"File: `{u['file']}`\nOld: `{u['current_digest'][:19]}...`\nNew: `{u['latest_digest'][:19]}...`",
                    "inline": False
                })
            elif u["type"] == "action_pinned":
                fields.append({
                    "name": f"{u['action']}@{u['tag']}",
                    "value": f"File: `{u['file']}`\nOld: `{u['current_sha'][:12]}`\nNew: `{u['latest_sha'][:12]}`",
                    "inline": False
                })
            elif u["type"] == "docker_unpinned":
                fields.append({
                    "name": f"{u['image']}:{u['tag']}",
                    "value": f"File: `{u['file']}`\nStatus: Pinned to `{u['latest_digest'][:19]}...`",
                    "inline": False
                })
            elif u["type"] == "action_unpinned":
                 fields.append({
                    "name": f"{u['action']}@{u['tag']}",
                    "value": f"File: `{u['file']}`\nStatus: Pinned to `{u['latest_sha'][:12]}`",
                    "inline": False
                })

    elif args.type == "warnings":
        for w in report.get("warnings", []):
            # Check keys
            if 'action' in w:
                name = w['action']
            elif 'image' in w:
                name = w['image']
            else:
                name = 'unknown'
            fields.append({
                "name": name,
                "value": f"File: `{w['file']}`\n{w['reason']}",
                "inline": False
            })

    elif args.type == "success":
        count = len(report.get("up_to_date", []))
        fields.append({
            "name": "Status",
            "value": f"{count} dependencies checked. All up to date.",
            "inline": False
        })
    elif args.type == "all":
        # Handle all types if needed later
        pass

    print(json.dumps(fields))

if __name__ == "__main__":
    main()
