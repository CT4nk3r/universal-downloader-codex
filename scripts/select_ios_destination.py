#!/usr/bin/env python3
"""Print an xcodebuild destination for an available iOS simulator."""

from __future__ import annotations

import json
import subprocess
import sys


PREFERRED_NAMES = (
    "iPhone 16",
    "iPhone 15",
    "iPhone 14",
    "iPhone 13",
)


def main() -> int:
    try:
        raw = subprocess.check_output(
            ["xcrun", "simctl", "list", "devices", "available", "--json"],
            text=True,
        )
    except (OSError, subprocess.CalledProcessError) as exc:
        print(f"Unable to list iOS simulators: {exc}", file=sys.stderr)
        return 1

    devices_by_runtime = json.loads(raw).get("devices", {})
    candidates = []
    for runtime, devices in devices_by_runtime.items():
        if ".iOS-" not in runtime:
            continue
        for device in devices:
            if device.get("isAvailable") and "iPhone" in device.get("name", ""):
                candidates.append(device)

    if not candidates:
        print("No available iPhone simulator found.", file=sys.stderr)
        return 1

    for preferred in PREFERRED_NAMES:
        for device in candidates:
            if preferred in device["name"]:
                print(f"platform=iOS Simulator,id={device['udid']}")
                return 0

    print(f"platform=iOS Simulator,id={candidates[0]['udid']}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
