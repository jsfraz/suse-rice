#!/bin/sh
# Keep MEGAsync secondary dialogs from collapsing to 1 px wide under XWayland.
set -eu
export PATH="${HOME}/.local/bin:/usr/local/bin:${PATH:-/usr/bin:/bin}"

command -v hyprctl >/dev/null 2>&1 || exit 0
command -v python3 >/dev/null 2>&1 || exit 0

fix_megasync_dialogs() {
    python3 - <<'PY'
import json, subprocess

try:
    raw = subprocess.check_output(["hyprctl", "clients", "-j"], text=True)
except subprocess.CalledProcessError:
    raise SystemExit(0)

clients = json.loads(raw)
for c in clients:
    if c.get("class") != "MEGAsync":
        continue
    title = c.get("title") or ""
    if title in ("", "MEGAsync"):
        continue
    w, _h = c.get("size") or [0, 0]
    if w >= 200:
        continue
    addr = c.get("address")
    if not addr:
        continue
    ev = f'''
local w = hl.get_window("{addr}")
if w then
  hl.dispatch(hl.dsp.window.float({{ action = "set", window = w }}))
  hl.dispatch(hl.dsp.window.center({{ window = w }}))
  hl.dispatch(hl.dsp.window.pin({{ action = "set", window = w }}))
  hl.dispatch(hl.dsp.window.resize({{ x = 520, y = 640, window = w }}))
  hl.dispatch(hl.dsp.focus({{ window = w }}))
end
'''
    subprocess.run(["hyprctl", "eval", ev], check=False)
PY
}

while true; do
    if pgrep -x megasync >/dev/null 2>&1; then
        fix_megasync_dialogs
        sleep 0.12
    else
        sleep 2
    fi
done
