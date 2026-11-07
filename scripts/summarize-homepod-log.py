#!/usr/bin/env python3
"""Summarize HomePod setup phases without printing private syslog payloads.

Usage: python scripts/summarize-homepod-log.py homepod-setup-YYYYMMDD-HHMMSS.txt
The source log is read-only. Only timestamp and predefined event labels are
printed; never output the original line, device IDs, tokens, or account data.
"""

import argparse
from collections import Counter
from pathlib import Path
import re


EVENTS = (
    ("tweak_loaded", re.compile(r"\[HomePodBridge 0\.\d+\.\d+\] Initialized")),
    ("patch_applied", re.compile(r"\[HomePodBridge\] Patched unknown-device update gate")),
    ("patch_refused", re.compile(r"\[HomePodBridge\] (?:Refusing to patch|FAILED to patch)")),
    ("legacy_unknown_device", re.compile(r"Requires an upgrade because device \d+ is not known")),
    ("setup_transport", re.compile(r"B238Setup: (?:Activated|Start request send|Start ack received)")),
    ("preauth_complete", re.compile(r"PreAuth response:")),
    ("wifi_handoff", re.compile(r"(?:Re-enabling B238Setup after WiFi|WiFi.*(?:connect|join|error))", re.I)),
    ("homekit_start", re.compile(r"HomeKitSetup(?:Start| started)", re.I)),
    ("homekit_wait_timeout", re.compile(r"(?:kHomeKitSyncTimeoutErr|HomeKitSetupWaitDeviceSetup)")),
    ("setup_failed", re.compile(r"(?:### Setup failed:|Setup Failed|HomeKitSetup failed)")),
)

TIMESTAMP = re.compile(r"\b(\d{4}-\d\d-\d\d[ T]\d\d:\d\d:\d\d(?:\.\d+)?)\b")


def summarize(lines):
    events = []
    for line in lines:
        timestamp = TIMESTAMP.search(line)
        when = timestamp.group(1) if timestamp else "unknown-time"
        for label, pattern in EVENTS:
            if pattern.search(line):
                events.append((when, label))
                break
    return events


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("log", type=Path, help="Raw pymobiledevice3 syslog capture")
    args = parser.parse_args()
    # Windows PowerShell 5.1 commonly writes UTF-16LE with a BOM, while
    # PowerShell 7 and many text editors use UTF-8. Handle both transparently.
    with args.log.open("rb") as handle:
        first = handle.read(4)
    encoding = "utf-16" if first.startswith((b"\xff\xfe", b"\xfe\xff")) else "utf-8-sig"
    with args.log.open("r", encoding=encoding, errors="replace") as handle:
        events = summarize(handle)

    if not events:
        print("No recognized HomePod setup events. Check that logging began before the setup attempt.")
        return

    print("HomePod setup events (private values omitted):")
    for when, label in events:
        print(f"  {when}  {label}")

    counts = Counter(label for _, label in events)
    print("\nCounts:")
    for label, count in counts.items():
        print(f"  {label}: {count}")
    if counts["homekit_wait_timeout"]:
        print("\nResult: HomeKit device-setup wait timed out; earlier events may locate the last successful phase.")
    elif counts["legacy_unknown_device"] and not counts["patch_applied"]:
        print("\nResult: Older unknown-device gate observed; check installed tweak version and patch logs.")
    elif counts["patch_applied"]:
        print("\nResult: Unknown-device gate patch confirmed, but setup completion is not proven by this log.")


if __name__ == "__main__":
    main()
