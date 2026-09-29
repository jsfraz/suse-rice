#!/usr/bin/env python3
"""NetworkManager snapshot and actions for the settings window. Prints JSON."""

import json
import shutil
import subprocess
import sys

PATH_PREFIX = "/usr/local/bin:/usr/bin:/bin"


def run(args):
    proc = subprocess.run(args, text=True, capture_output=True)
    return proc.returncode, proc.stdout, proc.stderr


def fail(message, code=1):
    json.dump({"ok": False, "error": message.strip()}, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    raise SystemExit(code)


def split_fields(line):
    fields = []
    buf = []
    i = 0
    while i < len(line):
        if line[i] == "\\" and i + 1 < len(line):
            buf.append(line[i + 1])
            i += 2
            continue
        if line[i] == ":":
            fields.append("".join(buf))
            buf = []
            i += 1
            continue
        buf.append(line[i])
        i += 1
    fields.append("".join(buf))
    return fields


def wifi_radio():
    code, out, err = run(["nmcli", "-t", "-f", "WIFI", "radio"])
    if code != 0:
        return False
    return out.strip() == "enabled"


def wifi_networks():
    code, out, err = run([
        "nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY,BSSID", "device", "wifi", "list",
    ])
    if code != 0:
        return []
    best = {}
    for line in out.splitlines():
        if not line.strip():
            continue
        fields = split_fields(line)
        if len(fields) < 5:
            continue
        in_use, ssid, signal, security = fields[0], fields[1], fields[2], fields[3]
        if not ssid:
            continue
        try:
            strength = int(signal)
        except ValueError:
            strength = 0
        item = best.get(ssid)
        if item is None or strength > item["signal"]:
            best[ssid] = {
                "ssid": ssid,
                "signal": strength,
                "security": security,
                "inUse": in_use == "*",
            }
        elif in_use == "*":
            item["inUse"] = True
    return sorted(best.values(), key=lambda n: (-n["inUse"], -n["signal"], n["ssid"]))


def devices():
    code, out, err = run(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device", "status"])
    ethernet = []
    if code != 0:
        return ethernet
    for line in out.splitlines():
        fields = split_fields(line)
        if len(fields) < 4:
            continue
        device, kind, state, connection = fields[0], fields[1], fields[2], fields[3]
        if kind != "ethernet":
            continue
        ethernet.append({
            "device": device,
            "state": state,
            "connection": connection,
        })
    return ethernet


def saved_connections():
    code, out, err = run(["nmcli", "-t", "-f", "NAME,TYPE,DEVICE", "connection", "show"])
    items = []
    if code != 0:
        return items
    for line in out.splitlines():
        fields = split_fields(line)
        if len(fields) < 3:
            continue
        name, kind, device = fields[0], fields[1], fields[2]
        if kind not in ("802-11-wireless", "802-3-ethernet"):
            continue
        items.append({
            "name": name,
            "type": "wifi" if kind == "802-11-wireless" else "ethernet",
            "active": bool(device),
            "device": device,
        })
    return items


def snapshot(rescan=False):
    if shutil.which("nmcli") is None:
        fail("nmcli není nainstalované")
    if rescan:
        run(["nmcli", "device", "wifi", "rescan"])
    payload = {
        "ok": True,
        "wifiEnabled": wifi_radio(),
        "networks": wifi_networks() if wifi_radio() else [],
        "saved": saved_connections(),
        "ethernet": devices(),
    }
    json.dump(payload, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")


def connect(ssid, password):
    cmd = ["nmcli", "device", "wifi", "connect", ssid]
    if password:
        cmd += ["password", password]
    code, out, err = run(cmd)
    if code != 0:
        fail(err or out or "připojení selhalo")
    snapshot()


def connection_cmd(action, name):
    if action == "up":
        cmd = ["nmcli", "connection", "up", name]
    elif action == "down":
        cmd = ["nmcli", "connection", "down", name]
    elif action == "forget":
        cmd = ["nmcli", "connection", "delete", name]
    else:
        fail("neznámá akce")
    code, out, err = run(cmd)
    if code != 0:
        fail(err or out or "akce selhala")
    snapshot()


def radio(state):
    code, out, err = run(["nmcli", "radio", "wifi", state])
    if code != 0:
        fail(err or out or "Wi-Fi rádio se nepodařilo přepnout")
    snapshot()


def main():
    if len(sys.argv) < 2:
        fail("chybí příkaz")
    cmd = sys.argv[1]
    if cmd == "status":
        snapshot(False)
    elif cmd == "scan":
        snapshot(True)
    elif cmd == "connect":
        if len(sys.argv) < 3:
            fail("chybí SSID")
        connect(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "")
    elif cmd in ("up", "down", "forget"):
        if len(sys.argv) < 3:
            fail("chybí název připojení")
        connection_cmd(cmd, sys.argv[2])
    elif cmd == "radio":
        if len(sys.argv) < 3 or sys.argv[2] not in ("on", "off"):
            fail("radio on|off")
        radio(sys.argv[2])
    else:
        fail("neznámý příkaz")


if __name__ == "__main__":
    main()
