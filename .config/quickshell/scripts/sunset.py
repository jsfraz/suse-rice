#!/usr/bin/env python3
"""Read and write the blue-light filter stored in rcm, then apply it. Prints JSON."""

import json
import os
import subprocess
import sys

HOME = os.path.expanduser("~")
TEMP_MIN = 2500
TEMP_MAX = 6500
TEMP_STEP = 100
TEMP_DEFAULT = 4000


def env():
    path = os.environ.get("PATH", "")
    extra = ":".join([
        os.path.join(HOME, ".local", "bin"),
        "/usr/local/bin",
    ])
    os.environ["PATH"] = extra + ":" + path


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
    if isinstance(value, bool):
        text = "true" if value else "false"
    else:
        text = str(value)
    proc = run(["rcm", "set", key, text])
    if proc.returncode != 0:
        fail(proc.stderr or proc.stdout or f"rcm set {key}")


def as_bool(text):
    return text.strip().lower() == "true"


def as_temp(value):
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        fail("temperature must be 2500–6500 K in steps of 100")
    if isinstance(value, float) and not value.is_integer():
        fail("temperature must be 2500–6500 K in steps of 100")
    temp = int(value)
    if temp < TEMP_MIN or temp > TEMP_MAX or temp % TEMP_STEP:
        fail("temperature must be 2500–6500 K in steps of 100")
    return temp


def stored_temp():
    raw = rcm_get("sunsetTemperature", str(TEMP_DEFAULT)).strip()
    try:
        temp = int(raw)
    except ValueError:
        return TEMP_DEFAULT
    if temp < TEMP_MIN or temp > TEMP_MAX or temp % TEMP_STEP:
        return TEMP_DEFAULT
    return temp


def status():
    payload = {
        "ok": True,
        "followDarkman": as_bool(rcm_get("sunsetFollowDarkman", "true")),
        "on": as_bool(rcm_get("sunsetOn", "false")),
        "temperature": stored_temp(),
    }
    json.dump(payload, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")


def apply(data):
    follow = bool(data.get("followDarkman"))
    enabled = bool(data.get("on"))
    temp = as_temp(data.get("temperature", TEMP_DEFAULT))
    rcm_set("sunsetFollowDarkman", follow)
    rcm_set("sunsetOn", enabled)
    rcm_set("sunsetTemperature", temp)

    script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "apply-sunset.sh")
    proc = run(["bash", script])
    if proc.returncode != 0:
        fail(proc.stderr or proc.stdout or "could not configure hyprsunset")
    status()


def main():
    env()
    if len(sys.argv) < 2:
        fail("missing command")
    if sys.argv[1] == "status":
        status()
        return
    if sys.argv[1] == "apply":
        if len(sys.argv) < 3:
            fail("missing JSON")
        try:
            data = json.loads(sys.argv[2])
        except json.JSONDecodeError as exc:
            fail(f"JSON: {exc}")
        apply(data)
        return
    fail("unknown command")


if __name__ == "__main__":
    main()
