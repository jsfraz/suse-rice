#!/usr/bin/env python3
"""NetworkManager snapshot and actions for the settings window. Prints JSON."""

import glob
import json
import os
import shutil
import subprocess
import sys

PATH_PREFIX = "/usr/local/bin:/usr/bin:/bin"
CACHE_DIR = os.path.join(os.path.expanduser("~"), ".cache", "suse-rice")
EAP_CA_BUNDLE = os.path.join(CACHE_DIR, "geteduroam-ca-bundle.pem")


def run(args):
    proc = subprocess.run(args, text=True, capture_output=True)
    return proc.returncode, proc.stdout, proc.stderr


def fail(message, code=1):
    text = message.strip()
    if "\nHint:" in text:
        text = text.split("\nHint:", 1)[0].strip()
    json.dump({"ok": False, "error": text}, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    raise SystemExit(code)


def connection_value(name, field):
    code, out, err = run(["nmcli", "-g", field, "connection", "show", name])
    if code != 0:
        return ""
    return out.strip()


def is_eap_connection(name):
    key_mgmt = connection_value(name, "802-11-wireless-security.key-mgmt")
    return "wpa-eap" in key_mgmt or "ieee8021x" in key_mgmt


def _bundle_mtime(path):
    try:
        return os.path.getmtime(path)
    except OSError:
        return 0


def build_ca_bundle(ca_dir):
    paths = sorted(glob.glob(os.path.join(ca_dir, "[0-9].pem")))
    if not paths:
        return None
    os.makedirs(CACHE_DIR, exist_ok=True)
    newest = max(_bundle_mtime(p) for p in paths)
    if _bundle_mtime(EAP_CA_BUNDLE) >= newest and os.path.isfile(EAP_CA_BUNDLE):
        return EAP_CA_BUNDLE
    with open(EAP_CA_BUNDLE, "w", encoding="utf-8") as handle:
        for path in paths:
            with open(path, encoding="utf-8") as cert:
                data = cert.read()
            handle.write(data)
            if data and not data.endswith("\n"):
                handle.write("\n")
    return EAP_CA_BUNDLE


def prepare_eap_profile(name):
    """NetworkManager rejects 802-1x.ca-path on user profiles; merge CAs into one file."""
    if not is_eap_connection(name):
        return
    ca_path = connection_value(name, "802-1x.ca-path")
    ca_cert = connection_value(name, "802-1x.ca-cert")
    if not ca_path or ca_cert:
        return
    bundle = build_ca_bundle(ca_path)
    if not bundle:
        fail(f"no CA certificates found in {ca_path}")
    code, out, err = run([
        "nmcli", "connection", "modify", name,
        "802-1x.ca-cert", bundle,
        "802-1x.ca-path", "",
    ])
    if code != 0:
        fail(err or out or "could not prepare the 802.1X profile")


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


def wifi_networks(rescan=False):
    # "auto" waits on a fresh scan and holds the settings page for seconds.
    # Status reads the cache; only an explicit search asks NetworkManager to rescan.
    code, out, err = run([
        "nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY,BSSID",
        "device", "wifi", "list", "--rescan", "yes" if rescan else "no",
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


def wifi_ssid(name):
    code, out, err = run(["nmcli", "-g", "802-11-wireless.ssid", "connection", "show", name])
    if code != 0:
        return ""
    return out.strip()


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
        wifi = kind == "802-11-wireless"
        items.append({
            "name": name,
            "ssid": wifi_ssid(name) if wifi else "",
            "type": "wifi" if wifi else "ethernet",
            "active": bool(device),
            "device": device,
        })
    return items


def saved_wifi_name(ssid):
    for item in saved_connections():
        if item["type"] != "wifi":
            continue
        if item["ssid"] == ssid or item["name"] == ssid:
            return item["name"]
    return ""


def snapshot(rescan=False):
    if shutil.which("nmcli") is None:
        fail("nmcli is not installed")
    enabled = wifi_radio()
    payload = {
        "ok": True,
        "wifiEnabled": enabled,
        "networks": wifi_networks(rescan) if enabled else [],
        "saved": saved_connections(),
        "ethernet": devices(),
    }
    json.dump(payload, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")


def connect(ssid, password):
    # Disconnect only deactivates the profile. Reuse it so the saved PSK is kept.
    if not password:
        name = saved_wifi_name(ssid)
        if name:
            connection_cmd("up", name)
            return
    if password and saved_wifi_name(ssid):
        fail("this network already has a saved profile; use Connect without a password")
    cmd = ["nmcli", "device", "wifi", "connect", ssid]
    if password:
        cmd += ["password", password]
    code, out, err = run(cmd)
    if code != 0:
        fail(err or out or "connection failed")
    snapshot()


def connection_cmd(action, name):
    if action == "up":
        prepare_eap_profile(name)
        cmd = ["nmcli", "connection", "up", name]
    elif action == "down":
        cmd = ["nmcli", "connection", "down", name]
    elif action == "forget":
        cmd = ["nmcli", "connection", "delete", name]
    else:
        fail("unknown action")
    code, out, err = run(cmd)
    if code != 0:
        fail(err or out or "action failed")
    snapshot()


def radio(state):
    code, out, err = run(["nmcli", "radio", "wifi", state])
    if code != 0:
        fail(err or out or "could not switch the Wi-Fi radio")
    snapshot()


def main():
    if len(sys.argv) < 2:
        fail("missing command")
    cmd = sys.argv[1]
    if cmd == "status":
        snapshot(False)
    elif cmd == "scan":
        snapshot(True)
    elif cmd == "connect":
        if len(sys.argv) < 3:
            fail("missing SSID")
        connect(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else "")
    elif cmd in ("up", "down", "forget"):
        if len(sys.argv) < 3:
            fail("missing connection name")
        connection_cmd(cmd, sys.argv[2])
    elif cmd == "radio":
        if len(sys.argv) < 3 or sys.argv[2] not in ("on", "off"):
            fail("radio on|off")
        radio(sys.argv[2])
    else:
        fail("unknown command")


if __name__ == "__main__":
    main()
