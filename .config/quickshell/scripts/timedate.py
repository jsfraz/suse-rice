#!/usr/bin/env python3
"""Timezone, NTP, and manual clock. Writes go through sudo -n timedatectl. Prints JSON."""

import json
import re
import subprocess
import sys

TIME_RE = re.compile(r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}$")
ZONE_RE = re.compile(r"^[A-Za-z0-9_+-]+(/[A-Za-z0-9_+-]+)+$|^UTC$")


def run(args):
    return subprocess.run(args, text=True, capture_output=True)


def fail(message, code=1):
    json.dump({"ok": False, "error": message.strip()}, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    raise SystemExit(code)


def show():
    proc = run(["timedatectl", "show", "-p", "Timezone", "-p", "NTP", "-p", "CanNTP"])
    if proc.returncode != 0:
        fail(proc.stderr or proc.stdout or "timedatectl failed")
    info = {}
    for line in proc.stdout.splitlines():
        if "=" in line:
            key, value = line.split("=", 1)
            info[key] = value
    return {
        "timezone": info.get("Timezone", ""),
        "ntp": info.get("NTP", "yes") == "yes",
        "canNtp": info.get("CanNTP", "yes") == "yes",
    }


def sudo_timedate(*args):
    proc = run(["sudo", "-n", "timedatectl", *args])
    if proc.returncode != 0:
        message = (proc.stderr or proc.stdout or "timedatectl selhal").strip()
        if "password" in message.lower() or "a password is required" in message.lower() or proc.returncode == 1 and "sudo" in message.lower():
            fail("sudo -n timedatectl failed. This rice expects passwordless sudo.")
        fail(message)


def main():
    if len(sys.argv) < 2:
        fail("missing command")
    cmd = sys.argv[1]
    if cmd == "status":
        payload = {"ok": True}
        payload.update(show())
        json.dump(payload, sys.stdout, ensure_ascii=False)
        sys.stdout.write("\n")
        return
    if cmd == "zones":
        proc = run(["timedatectl", "list-timezones"])
        if proc.returncode != 0:
            fail(proc.stderr or proc.stdout or "could not list time zones")
        zones = [line.strip() for line in proc.stdout.splitlines() if line.strip()]
        json.dump({"ok": True, "zones": zones}, sys.stdout, ensure_ascii=False)
        sys.stdout.write("\n")
        return
    if cmd == "timezone":
        if len(sys.argv) < 3 or not ZONE_RE.match(sys.argv[2]):
            fail("invalid time zone")
        sudo_timedate("set-timezone", sys.argv[2])
        payload = {"ok": True}
        payload.update(show())
        json.dump(payload, sys.stdout, ensure_ascii=False)
        sys.stdout.write("\n")
        return
    if cmd == "ntp":
        if len(sys.argv) < 3 or sys.argv[2] not in ("true", "false"):
            fail("ntp true|false")
        sudo_timedate("set-ntp", sys.argv[2])
        payload = {"ok": True}
        payload.update(show())
        json.dump(payload, sys.stdout, ensure_ascii=False)
        sys.stdout.write("\n")
        return
    if cmd == "time":
        if len(sys.argv) < 3 or not TIME_RE.match(sys.argv[2]):
            fail("time must be YYYY-MM-DD HH:MM:SS")
        sudo_timedate("set-time", sys.argv[2])
        payload = {"ok": True}
        payload.update(show())
        json.dump(payload, sys.stdout, ensure_ascii=False)
        sys.stdout.write("\n")
        return
    fail("unknown command")


if __name__ == "__main__":
    main()
