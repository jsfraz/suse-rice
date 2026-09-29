#!/usr/bin/env python3
"""Read and write Look & Feel values stored in rcm. Prints JSON."""

import json
import os
import shutil
import subprocess
import sys

COLORS = ["red", "orange", "yellow", "green", "teal", "blue", "purple", "pink"]
HOME = os.path.expanduser("~")
SAVER_MODES = ("none", "cycle", "random")


def env():
    path = os.environ.get("PATH", "")
    extra = ":".join([
        os.path.join(HOME, ".cargo", "bin"),
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


def shaders():
    if shutil.which("hyprsaver") is None:
        return []
    proc = run(["hyprsaver", "--list-shaders"])
    names = []
    for line in proc.stdout.splitlines():
        if not line.startswith("  "):
            continue
        parts = line.strip().split(None, 1)
        if not parts or parts[0] in ("(none",):
            continue
        names.append(parts[0])
    return names


def status():
    saver = rcm_get("screensaver", "cycle")
    names = shaders()
    options = list(SAVER_MODES) + [name for name in names if name not in SAVER_MODES]
    payload = {
        "ok": True,
        "wallpaper": rcm_get("wallpaper", "/usr/share/hypr/wall0.png"),
        "color": rcm_get("color", "blue"),
        "colors": COLORS,
        "forcedColor": as_bool(rcm_get("forcedColor", "false")),
        "colorFromWallpaper": as_bool(rcm_get("colorFromWallpaper", "false")),
        "forcedBrightnessMode": as_bool(rcm_get("forcedBrightnessMode", "false")),
        "brightnessMode": rcm_get("brightnessMode", "light"),
        "screensaver": saver,
        "screensavers": options,
    }
    json.dump(payload, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")


def apply(data):
    color = data.get("color", "blue")
    if color not in COLORS:
        fail("neznámá barva")
    mode = data.get("brightnessMode", "light")
    if mode not in ("light", "dark"):
        fail("neznámý režim jasu")
    saver = data.get("screensaver", "cycle")
    allowed = set(SAVER_MODES) | set(shaders())
    if saver not in allowed:
        fail("neznámý spořič")
    wallpaper = data.get("wallpaper", "").strip()
    if not wallpaper:
        fail("chybí tapeta")
    rcm_set("wallpaper", wallpaper)
    rcm_set("color", color)
    rcm_set("forcedColor", bool(data.get("forcedColor")))
    rcm_set("colorFromWallpaper", bool(data.get("colorFromWallpaper")))
    rcm_set("forcedBrightnessMode", bool(data.get("forcedBrightnessMode")))
    rcm_set("brightnessMode", mode)
    rcm_set("screensaver", saver)

    script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "apply-look.sh")
    proc = run(["bash", script])
    if proc.returncode != 0:
        fail(proc.stderr or proc.stdout or "matugen selhal")
    status()


def main():
    env()
    if len(sys.argv) < 2:
        fail("chybí příkaz")
    if sys.argv[1] == "status":
        status()
        return
    if sys.argv[1] == "apply":
        if len(sys.argv) < 3:
            fail("chybí JSON")
        try:
            data = json.loads(sys.argv[2])
        except json.JSONDecodeError as exc:
            fail(f"JSON: {exc}")
        apply(data)
        return
    fail("neznámý příkaz")


if __name__ == "__main__":
    main()
