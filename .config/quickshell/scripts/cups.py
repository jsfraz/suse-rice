#!/usr/bin/env python3
"""CUPS printer list and a small set of lpadmin actions. Prints JSON."""

import json
import re
import shutil
import subprocess
import sys

NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_-]{0,63}$")
URI_RE = re.compile(r"^(ipp|ipps|socket|lpd|usb)://\S+$")


def run(args):
    return subprocess.run(args, text=True, capture_output=True)


def fail(message, code=1):
    json.dump({"ok": False, "error": message.strip()}, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    raise SystemExit(code)


def cups_run(args):
    proc = run(args)
    if proc.returncode == 0:
        return proc
    if shutil.which("sudo"):
        proc = run(["sudo", "-n", *args])
    return proc


def unavailable():
    json.dump({
        "ok": True,
        "available": False,
        "hint": "CUPS is not installed. Install it with: sudo zypper in cups",
        "printers": [],
        "jobs": [],
        "default": "",
    }, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")


def parse_printers(text):
    printers = []
    for line in text.splitlines():
        match = re.match(r"^printer\s+(.+?)\s+(is idle|is printing|disabled since|now printing)\b", line)
        if not match:
            continue
        name, state = match.group(1), match.group(2)
        printers.append({
            "name": name,
            "enabled": not state.startswith("disabled"),
            "state": state,
        })
    return printers


def status():
    if shutil.which("lpstat") is None:
        unavailable()
        return
    listed = run(["lpstat", "-p"])
    if listed.returncode != 0 and "No destinations" not in (listed.stderr + listed.stdout) and "Žádn" not in listed.stderr:
        # lpstat exits non-zero when no printers exist on some versions; still try to show that.
        if "scheduler is not running" in (listed.stderr + listed.stdout).lower() or "Nepodařilo" in listed.stderr:
            json.dump({
                "ok": True,
                "available": False,
                "hint": "The CUPS service is not running. Start it with: sudo systemctl enable --now cups",
                "printers": [],
                "jobs": [],
                "default": "",
            }, sys.stdout, ensure_ascii=False)
            sys.stdout.write("\n")
            return
    printers = parse_printers(listed.stdout)
    default = ""
    dest = run(["lpstat", "-d"])
    for line in dest.stdout.splitlines():
        if ":" in line:
            value = line.split(":", 1)[1].strip()
            if value and "no system default" not in value.lower() and "žádn" not in value.lower():
                default = value
    jobs = []
    queued = run(["lpstat", "-o"])
    if queued.returncode == 0:
        for line in queued.stdout.splitlines():
            if line.strip():
                jobs.append(line.strip())
    json.dump({
        "ok": True,
        "available": True,
        "printers": printers,
        "jobs": jobs,
        "default": default,
    }, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")


def main():
    if len(sys.argv) < 2:
        fail("missing command")
    cmd = sys.argv[1]
    if cmd == "status":
        status()
        return
    if shutil.which("lpadmin") is None or shutil.which("lpstat") is None:
        fail("CUPS is not installed. sudo zypper in cups")
    if cmd == "default":
        name = sys.argv[2] if len(sys.argv) > 2 else ""
        if not NAME_RE.match(name):
            fail("invalid printer name")
        proc = cups_run(["lpadmin", "-d", name])
        if proc.returncode != 0:
            fail(proc.stderr or proc.stdout or "could not set the default printer")
    elif cmd == "enable":
        name = sys.argv[2] if len(sys.argv) > 2 else ""
        if not NAME_RE.match(name):
            fail("invalid printer name")
        tool = "cupsenable" if shutil.which("cupsenable") else None
        proc = cups_run([tool, name]) if tool else cups_run(["lpadmin", "-p", name, "-E"])
        if proc.returncode != 0:
            fail(proc.stderr or proc.stdout or "could not enable the printer")
    elif cmd == "disable":
        name = sys.argv[2] if len(sys.argv) > 2 else ""
        if not NAME_RE.match(name):
            fail("invalid printer name")
        tool = "cupsdisable" if shutil.which("cupsdisable") else None
        if tool is None:
            fail("cupsdisable is missing")
        proc = cups_run([tool, name])
        if proc.returncode != 0:
            fail(proc.stderr or proc.stdout or "could not pause the printer")
    elif cmd == "delete":
        name = sys.argv[2] if len(sys.argv) > 2 else ""
        if not NAME_RE.match(name):
            fail("invalid printer name")
        proc = cups_run(["lpadmin", "-x", name])
        if proc.returncode != 0:
            fail(proc.stderr or proc.stdout or "could not delete the printer")
    elif cmd == "add":
        if len(sys.argv) < 4:
            fail("add NAME URI")
        name, uri = sys.argv[2], sys.argv[3]
        if not NAME_RE.match(name):
            fail("the name may contain only letters, digits, _ and -")
        if not URI_RE.match(uri):
            fail("the URI must start with ipp://, ipps://, socket://, lpd:// or usb://")
        proc = cups_run(["lpadmin", "-p", name, "-E", "-v", uri, "-m", "everywhere"])
        if proc.returncode != 0:
            fail(proc.stderr or proc.stdout or "could not add the printer")
    else:
        fail("unknown command")
    status()


if __name__ == "__main__":
    main()
