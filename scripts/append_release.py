#!/usr/bin/env python3
"""Append build info to releases/manifest.json"""

import json
import sys
from pathlib import Path

def main():
    if len(sys.argv) < 2:
        print("Usage: append_release.py <build_info.json>")
        sys.exit(1)

    build_info_path = Path(sys.argv[1])
    manifest_path = Path(__file__).parent.parent / "releases" / "manifest.json"

    # Read build info with error handling
    try:
        with open(build_info_path) as f:
            build_info = json.load(f)
    except FileNotFoundError:
        print(f"Error: Build info file not found: {build_info_path}")
        sys.exit(1)
    except json.JSONDecodeError as e:
        print(f"Error: Invalid JSON in build info file: {e}")
        sys.exit(1)

    # Validate build_info structure
    required_fields = ["build_id", "signature", "git_commit", "git_branch", "timestamp"]
    missing_fields = [field for field in required_fields if field not in build_info]
    if missing_fields:
        print(f"Error: Build info missing required fields: {', '.join(missing_fields)}")
        sys.exit(1)

    # Add notes field
    build_info["notes"] = ""

    # Read or create manifest with error handling
    if manifest_path.exists():
        try:
            with open(manifest_path) as f:
                manifest = json.load(f)
        except json.JSONDecodeError as e:
            print(f"Error: Invalid JSON in manifest file: {e}")
            sys.exit(1)
    else:
        manifest = {"releases": []}

    # Check for duplicate
    for release in manifest["releases"]:
        if release.get("build_id") == build_info.get("build_id"):
            print(f"Build {build_info['build_id']} already in manifest, skipping")
            return

    # Append new release
    manifest["releases"].append(build_info)

    # Write manifest with error handling and trailing newline
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    try:
        with open(manifest_path, "w") as f:
            json.dump(manifest, f, indent=2)
            f.write("\n")  # Add trailing newline
    except OSError as e:
        print(f"Error: Failed to write manifest file: {e}")
        sys.exit(1)

    print(f"Added {build_info['build_id']} to manifest")

if __name__ == "__main__":
    main()

