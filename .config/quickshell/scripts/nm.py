#!/usr/bin/env python3
"""NetworkManager snapshot and actions for the settings window. Prints JSON."""

import glob
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

PATH_PREFIX = "/usr/local/bin:/usr/bin:/bin"
CACHE_DIR = os.path.join(os.path.expanduser("~"), ".cache", "suse-rice")
EAP_CA_BUNDLE = os.path.join(CACHE_DIR, "geteduroam-ca-bundle.pem")


def run(args):
    proc = subprocess.run(args, text=True, capture_output=True)
    return proc.returncode, proc.stdout, proc.stderr


def fail(message, code=1, needs_auth=False, connection=""):
    text = message.strip()
    if "\nHint:" in text:
        text = text.split("\nHint:", 1)[0].strip()
    payload = {"ok": False, "error": text}
    if needs_auth:
        payload["needsAuth"] = True
        if connection:
            payload["connection"] = connection
    json.dump(payload, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")
    raise SystemExit(code)


def openvpn_plugin_ready():
    # Distros differ: .name descriptor (current NM), legacy .service, or plugin .so only.
    patterns = (
        "/usr/lib*/NetworkManager/VPN/nm-openvpn*.name",
        "/usr/lib*/NetworkManager/VPN/nm-openvpn.service",
        "/usr/lib*/NetworkManager/libnm-vpn-plugin-openvpn.so",
    )
    for pattern in patterns:
        if glob.glob(pattern):
            return True
    return shutil.which("nm-openvpn-service") is not None


def openvpn_editor_ready():
    patterns = (
        "/usr/lib*/NetworkManager/libnm-vpn-plugin-openvpn-editor.so",
        "/usr/lib*/NetworkManager/libnm-gtk4-vpn-plugin-openvpn-editor.so",
    )
    return any(glob.glob(pattern) for pattern in patterns)


def is_vpn_connection(name):
    return connection_value(name, "connection.type") == "vpn"


def vpn_service_label(service):
    if not service:
        return "vpn"
    lower = service.lower()
    if "openvpn" in lower:
        return "openvpn"
    tail = service.rsplit(".", 1)[-1]
    return tail or "vpn"


def connection_uuid(name):
    return connection_value(name, "connection.uuid")


def _uuid_in_keyfile(path, uuid):
    try:
        with open(path, encoding="utf-8") as handle:
            for line in handle:
                if line.startswith("uuid="):
                    return line.strip().split("=", 1)[1] == uuid
    except OSError:
        return False
    return False


def connection_keyfile_path(name):
    uuid = connection_uuid(name)
    if not uuid:
        return ""
    patterns = (
        os.path.join(
            os.path.expanduser("~"),
            ".config/NetworkManager/system-connections/*.nmconnection",
        ),
        "/etc/NetworkManager/system-connections/*.nmconnection",
    )
    for pattern in patterns:
        for path in glob.glob(pattern):
            try:
                if _uuid_in_keyfile(path, uuid):
                    return path
            except OSError:
                continue
    return ""


def connection_system_wide(name):
    path = connection_keyfile_path(name)
    return path.startswith("/etc/NetworkManager")


def vpn_password_save_flag(name):
    """Use OpenVPN password-flags from vpn.data only (no nmcli -s / keyring prompt)."""
    data = connection_value(name, "vpn.data")
    return "password-flags = 2" in data or "password-flags=2" in data


def openvpn_data_username(data):
    match = re.search(r"(?:^|,)\s*username\s*=\s*([^,]+)", data)
    if not match:
        return ""
    return match.group(1).strip()


def openvpn_username(name):
    user = connection_value(name, "vpn.user-name")
    if user and user not in ("--", ""):
        return user
    return openvpn_data_username(connection_value(name, "vpn.data"))


def vpn_uses_password(name):
    data = connection_value(name, "vpn.data")
    lower = data.lower()
    return (
        "connection-type = password-tls" in data
        or "connection-type = passwords" in data
        or "connection-type=password-tls" in data
        or "connection-type=passwords" in data
        or "auth-user-pass" in lower
    )


def vpn_needs_login(name):
    if not vpn_uses_password(name):
        return False
    if not openvpn_username(name):
        return True
    if vpn_password_save_flag(name):
        return False
    data = connection_value(name, "vpn.data")
    if "password-flags = 1" in data or "password-flags=1" in data:
        return True
    if "auth-user-pass" in data.lower():
        return True
    return False


def auth_required_message(text):
    lower = text.lower()
    markers = (
        "secrets were required",
        "no vpn secrets",
        "vpn plugin failed",
        "missing vpn plugin",
        "interactive authentication",
        "not given in 'passwd-file'",
        "cannot ask without '--ask'",
        "vpn.secrets.password",
        "no valid secrets",
    )
    return any(marker in lower for marker in markers)


def write_vpn_passwd_file(path, username="", password=""):
    lines = []
    if username:
        lines.append(f"vpn.user-name:{username}")
    if password:
        lines.append(f"vpn.secrets.password:{password}")
    with open(path, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines) + ("\n" if lines else ""))


def store_vpn_secrets(name, username="", password=""):
    if username:
        code, out, err = run([
            "nmcli", "connection", "modify", name, "vpn.user-name", username,
        ])
        if code != 0:
            fail(err or out or "could not set the VPN username")
        code, out, err = run([
            "nmcli", "connection", "modify", name,
            "+vpn.data", f"username {username}",
        ])
        if code != 0:
            fail(err or out or "could not set the OpenVPN username")
    if password:
        code, out, err = run([
            "nmcli", "connection", "modify", name,
            "+vpn.secrets", f"password:{password}",
        ])
        if code != 0:
            fail(err or out or "could not store the VPN password (is gnome-keyring running?)")
        code, out, err = run([
            "nmcli", "connection", "modify", name,
            "+vpn.data", "password-flags 2",
        ])
        if code != 0:
            fail(err or out or "could not mark the VPN password as saved")


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


def vpn_profiles():
    code, out, err = run(["nmcli", "-t", "-f", "NAME,TYPE,DEVICE", "connection", "show"])
    items = []
    if code != 0:
        return items
    for line in out.splitlines():
        fields = split_fields(line)
        if len(fields) < 3:
            continue
        name, kind, device = fields[0], fields[1], fields[2]
        if kind != "vpn":
            continue
        service = connection_value(name, "vpn.service")
        items.append({
            "name": name,
            "type": "vpn",
            "active": bool(device),
            "device": device,
            "vpnType": vpn_service_label(service),
            "needsLogin": vpn_needs_login(name),
            "systemWide": connection_system_wide(name),
        })
    return sorted(items, key=lambda item: (not item["active"], item["name"].lower()))


def snapshot(rescan=False):
    if shutil.which("nmcli") is None:
        fail("nmcli is not installed")
    enabled = wifi_radio()
    payload = {
        "ok": True,
        "wifiEnabled": enabled,
        "networks": wifi_networks(rescan) if enabled else [],
        "saved": saved_connections(),
        "vpn": vpn_profiles(),
        "openvpnReady": openvpn_plugin_ready(),
        "openvpnEditorReady": openvpn_editor_ready(),
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


def connection_up(name, username="", password=""):
    prepare_eap_profile(name)
    passwd_file = None
    try:
        if is_vpn_connection(name):
            if username or password:
                store_vpn_secrets(name, username, password)
            elif vpn_needs_login(name):
                fail("VPN login required", needs_auth=True, connection=name)
        cmd = ["nmcli", "connection", "up", name]
        code, out, err = run(cmd)
        if code != 0 and is_vpn_connection(name) and (username or password):
            os.makedirs(CACHE_DIR, exist_ok=True)
            fd, passwd_file = tempfile.mkstemp(prefix="nm-vpn-", dir=CACHE_DIR)
            os.close(fd)
            os.chmod(passwd_file, 0o600)
            write_vpn_passwd_file(passwd_file, username, password)
            code, out, err = run([
                "nmcli", "connection", "up", name, "passwd-file", passwd_file,
            ])
        if code != 0:
            msg = "\n".join(part for part in (err, out) if part and part.strip()).strip()
            msg = msg or "action failed"
            if is_vpn_connection(name) and auth_required_message(msg):
                fail(msg, needs_auth=True, connection=name)
            fail(msg)
    finally:
        if passwd_file and os.path.isfile(passwd_file):
            os.unlink(passwd_file)
    snapshot()


def rehome_vpn(name):
    if not is_vpn_connection(name):
        fail("not a VPN profile")
    if not connection_system_wide(name):
        snapshot()
        return
    new_name = f"{name} (user)"
    code, out, err = run(["nmcli", "connection", "clone", name, new_name])
    if code != 0:
        fail(err or out or "could not copy the VPN profile to your user account")
    if connection_system_wide(new_name):
        fail(
            "The copied profile is still system-wide. "
            "Install the polkit rule: ~/.config/hypr/scripts/install-polkit-rules.sh"
        )
    snapshot()


def import_vpn(path):
    if not openvpn_plugin_ready():
        fail(
            "OpenVPN support is not installed."
        )
    path = os.path.abspath(os.path.expanduser(path))
    if not os.path.isfile(path):
        fail("file not found")
    code, out, err = run([
        "nmcli", "connection", "import", "type", "openvpn", "file", path,
    ])
    if code != 0:
        fail(err or out or "import failed")
    snapshot()


def connection_cmd(action, name, username="", password=""):
    if action == "up":
        connection_up(name, username, password)
        return
    if action == "down":
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
    elif cmd == "import-vpn":
        if len(sys.argv) < 3:
            fail("missing path")
        import_vpn(sys.argv[2])
    elif cmd == "rehome-vpn":
        if len(sys.argv) < 3:
            fail("missing connection name")
        rehome_vpn(sys.argv[2])
    elif cmd in ("up", "down", "forget"):
        if len(sys.argv) < 3:
            fail("missing connection name")
        username = sys.argv[3] if len(sys.argv) > 3 else ""
        password = sys.argv[4] if len(sys.argv) > 4 else ""
        connection_cmd(cmd, sys.argv[2], username, password)
    elif cmd == "radio":
        if len(sys.argv) < 3 or sys.argv[2] not in ("on", "off"):
            fail("radio on|off")
        radio(sys.argv[2])
    else:
        fail("unknown command")


if __name__ == "__main__":
    main()
