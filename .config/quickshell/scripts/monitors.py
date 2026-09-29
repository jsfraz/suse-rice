#!/usr/bin/env python3
"""List Hyprland monitors and apply a layout through rcm + hyprctl. Prints JSON."""

import json
import os
import subprocess
import sys

HOME = os.path.expanduser("~")
SCALES = [1, 1.25, 1.5, 1.75, 2]
TRANSFORMS = [
    {"value": 0, "label": "0°"},
    {"value": 1, "label": "90°"},
    {"value": 2, "label": "180°"},
    {"value": 3, "label": "270°"},
]


def env():
    os.environ["PATH"] = "/usr/local/bin:" + os.path.join(HOME, ".local", "bin") + ":" + os.environ.get("PATH", "")


def run(args):
    return subprocess.run(args, text=True, capture_output=True)


def fail(message, code=1):
    json.dump({"ok": False, "error": message.strip()}, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    raise SystemExit(code)


def rcm_set(value):
    proc = run(["rcm", "set", "monitors", value])
    if proc.returncode != 0:
        fail(proc.stderr or proc.stdout or "rcm set monitors")


def live():
    proc = run(["hyprctl", "monitors", "-j"])
    if proc.returncode != 0:
        fail(proc.stderr or proc.stdout or "hyprctl monitors selhal")
    try:
        data = json.loads(proc.stdout or "[]")
    except json.JSONDecodeError as exc:
        fail(f"hyprctl JSON: {exc}")
    monitors = []
    for mon in data:
        rate = float(mon.get("refreshRate") or 0)
        mode = ""
        if not mon.get("disabled"):
            mode = f"{mon.get('width')}x{mon.get('height')}@{rate:.2f}Hz"
        modes = list(mon.get("availableModes") or [])
        if mode and mode not in modes:
            modes.insert(0, mode)
        monitors.append({
            "name": mon.get("name") or "",
            "description": mon.get("description") or mon.get("name") or "",
            "mode": mode,
            "modes": modes,
            "x": int(mon.get("x") or 0),
            "y": int(mon.get("y") or 0),
            "scale": float(mon.get("scale") or 1),
            "transform": int(mon.get("transform") or 0),
            "enabled": not bool(mon.get("disabled")),
        })
    return monitors


def encode(monitors):
    lines = []
    for mon in monitors:
        name = str(mon.get("name", "")).strip()
        if not name or "|" in name:
            fail(f"neplatný výstup: {name}")
        mode = str(mon.get("mode", "")).strip()
        enabled = bool(mon.get("enabled"))
        if enabled and not mode:
            fail(f"{name}: chybí režim")
        lines.append("|".join([
            name,
            mode,
            str(int(mon.get("x", 0))),
            str(int(mon.get("y", 0))),
            str(mon.get("scale", 1)),
            str(int(mon.get("transform", 0))),
            "1" if enabled else "0",
        ]))
    return "\n".join(lines)


def emit_status():
    json.dump({
        "ok": True,
        "monitors": live(),
        "scales": SCALES,
        "transforms": TRANSFORMS,
    }, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")


def apply_file():
    script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "apply-monitors.sh")
    proc = run(["bash", script])
    if proc.returncode != 0:
        fail(proc.stderr or proc.stdout or "hyprctl monitor selhal")


def main():
    env()
    if len(sys.argv) < 2:
        fail("chybí příkaz")
    cmd = sys.argv[1]
    if cmd == "status":
        emit_status()
        return
    if cmd == "apply":
        if len(sys.argv) < 3:
            fail("chybí JSON")
        try:
            data = json.loads(sys.argv[2])
        except json.JSONDecodeError as exc:
            fail(f"JSON: {exc}")
        monitors = data.get("monitors")
        if not isinstance(monitors, list) or not monitors:
            fail("chybí seznam displejů")
        rcm_set(encode(monitors))
        apply_file()
        emit_status()
        return
    if cmd == "reset":
        for mon in live():
            name = mon["name"]
            proc = run([
                "hyprctl", "eval",
                f'hl.monitor({{ output = "{name}", mode = "preferred", position = "auto", scale = 1, disabled = false }})',
            ])
            if proc.returncode != 0:
                fail(proc.stderr or proc.stdout or f"reset {name}")
        rcm_set("-")
        emit_status()
        return
    fail("neznámý příkaz")


if __name__ == "__main__":
    main()
