#!/usr/bin/env python3
"""Backlight percent and hypridle timeouts. Prints JSON."""

import json
import os
import re
import shutil
import subprocess
import sys

HOME = os.path.expanduser("~")


def env():
    os.environ["PATH"] = "/usr/local/bin:" + os.path.join(HOME, ".local", "bin") + ":" + os.environ.get("PATH", "")


def run(args):
    return subprocess.run(args, text=True, capture_output=True)


def fail(message, code=1):
    json.dump({"ok": False, "error": message.strip()}, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    raise SystemExit(code)


def rcm_get(key, fallback):
    proc = run(["rcm", "get", key, "-f", fallback])
    if proc.returncode != 0:
        fail(proc.stderr or proc.stdout or f"rcm get {key}")
    return proc.stdout.rstrip("\n")


def rcm_set(key, value):
    proc = run(["rcm", "set", key, str(int(value))])
    if proc.returncode != 0:
        fail(proc.stderr or proc.stdout or f"rcm set {key}")


def brightness():
    if shutil.which("brightnessctl") is None:
        return None
    proc = run(["brightnessctl", "-m"])
    if proc.returncode != 0 or not proc.stdout.strip():
        return None
    # device,class,current,percent,max
    parts = proc.stdout.splitlines()[0].split(",")
    if len(parts) < 4:
        return None
    match = re.search(r"(\d+)", parts[3])
    if not match:
        return None
    return int(match.group(1))


def emit(extra=None):
    payload = {
        "ok": True,
        "brightness": brightness(),
        "idleKbd": int(rcm_get("idleKbd", "150")),
        "idleScreensaver": int(rcm_get("idleScreensaver", "600")),
        "idleLock": int(rcm_get("idleLock", "3600")),
    }
    if extra:
        payload.update(extra)
    json.dump(payload, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")


def set_brightness(percent):
    percent = int(percent)
    if percent < 2 or percent > 100:
        fail("brightness must be from 2 to 100")
    proc = run(["brightnessctl", "-n2", "set", f"{percent}%"])
    if proc.returncode != 0:
        fail(proc.stderr or proc.stdout or "brightnessctl failed")


def main():
    env()
    if len(sys.argv) < 2:
        fail("missing command")
    cmd = sys.argv[1]
    if cmd == "status":
        emit()
        return
    if cmd == "brightness":
        if len(sys.argv) < 3:
            fail("missing percent")
        set_brightness(sys.argv[2])
        emit()
        return
    if cmd == "idle":
        if len(sys.argv) < 3:
            fail("missing JSON")
        try:
            data = json.loads(sys.argv[2])
        except json.JSONDecodeError as exc:
            fail(f"JSON: {exc}")
        for key, low, high in (
            ("idleKbd", 30, 900),
            ("idleScreensaver", 60, 7200),
            ("idleLock", 120, 21600),
        ):
            value = int(data[key])
            if value < low or value > high:
                fail(f"{key} is out of range")
            rcm_set(key, value)
        script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "apply-idle.sh")
        proc = run(["bash", script])
        if proc.returncode != 0:
            fail(proc.stderr or proc.stdout or "hypridle failed")
        emit()
        return
    fail("unknown command")


if __name__ == "__main__":
    main()
