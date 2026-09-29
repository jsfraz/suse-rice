#!/usr/bin/env python3
"""Keyboard layout list and rcm persistence. Prints JSON."""

import json
import os
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
    proc = run(["rcm", "set", key, str(value)])
    if proc.returncode != 0:
        fail(proc.stderr or proc.stdout or f"rcm set {key}")


def lines(args):
    proc = run(args)
    if proc.returncode != 0:
        fail(proc.stderr or proc.stdout or "localectl selhal")
    return [line.strip() for line in proc.stdout.splitlines() if line.strip()]


def emit(payload):
    json.dump(payload, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")


def main():
    env()
    if len(sys.argv) < 2:
        fail("chybí příkaz")
    cmd = sys.argv[1]
    if cmd == "status":
        variant = rcm_get("keyboardVariant", "-")
        emit({
            "ok": True,
            "layout": rcm_get("keyboard", "cz"),
            "variant": "" if variant == "-" else variant,
        })
        return
    if cmd == "layouts":
        emit({"ok": True, "layouts": lines(["localectl", "list-x11-keymap-layouts"])})
        return
    if cmd == "variants":
        if len(sys.argv) < 3:
            fail("chybí rozložení")
        emit({"ok": True, "variants": lines(["localectl", "list-x11-keymap-variants", sys.argv[2]])})
        return
    if cmd == "apply":
        if len(sys.argv) < 3:
            fail("chybí rozložení")
        layout = sys.argv[2]
        variant = sys.argv[3] if len(sys.argv) > 3 else ""
        if not layout or "/" in layout or " " in layout:
            fail("neplatné rozložení")
        if variant and ("/" in variant or " " in variant):
            fail("neplatná varianta")
        rcm_set("keyboard", layout)
        rcm_set("keyboardVariant", variant if variant else "-")
        script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "apply-keyboard.sh")
        proc = run(["bash", script])
        if proc.returncode != 0:
            fail(proc.stderr or proc.stdout or "hyprctl selhal")
        emit({"ok": True})
        return
    if cmd == "restart-wayvnc":
        script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "apply-keyboard.sh")
        proc = run(["bash", script, "--restart-wayvnc"])
        if proc.returncode != 0:
            fail(proc.stderr or proc.stdout or "wayvnc se nepodařilo restartovat")
        emit({"ok": True})
        return
    fail("neznámý příkaz")


if __name__ == "__main__":
    main()
