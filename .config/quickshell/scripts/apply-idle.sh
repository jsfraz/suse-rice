#!/bin/bash
# Build ~/.local/state/suse-rice/hypridle.conf from the repo template and rcm timeouts.
# --if-absent starts hypridle only when it is not already running (Hyprland autostart).
# Any other invocation restarts hypridle so a settings change takes effect.
set -euo pipefail
export PATH="${HOME}/.local/bin:/usr/local/bin:${PATH}"

template=$(dirname "$(readlink -f "$0")")/../../hypr/hypridle.conf
out_dir="${HOME}/.local/state/suse-rice"
out="${out_dir}/hypridle.conf"
mkdir -p "$out_dir"

kbd=$(rcm get idleKbd -f 150)
saver=$(rcm get idleScreensaver -f 600)
lock=$(rcm get idleLock -f 3600)
kbd=${kbd//$'\n'/}
saver=${saver//$'\n'/}
lock=${lock//$'\n'/}

case "$kbd" in
    ''|*[!0-9]*) echo "idleKbd musí být celé číslo" >&2; exit 1 ;;
esac
case "$saver" in
    ''|*[!0-9]*) echo "idleScreensaver musí být celé číslo" >&2; exit 1 ;;
esac
case "$lock" in
    ''|*[!0-9]*) echo "idleLock musí být celé číslo" >&2; exit 1 ;;
esac

python3 - "$template" "$out" "$kbd" "$saver" "$lock" <<'PY'
import pathlib, re, sys
template, dest, kbd, saver, lock = sys.argv[1:]
text = pathlib.Path(template).read_text()
values = iter((kbd, saver, lock))

def repl(_match):
    return f"timeout = {next(values)}"

new, count = re.subn(r"timeout = \d+", repl, text, count=3)
if count != 3:
    raise SystemExit(f"šablona hypridle nemá 3 timeouty (nalezeno {count})")
pathlib.Path(dest).write_text(new)
PY

mode=${1:-restart}
if [ "$mode" = "--if-absent" ]; then
    if pgrep -x hypridle >/dev/null 2>&1; then
        exit 0
    fi
    exec hypridle -c "$out"
fi

if pgrep -x hypridle >/dev/null 2>&1; then
    pkill -x hypridle || true
    i=0
    while [ "$i" -lt 20 ]; do
        pgrep -x hypridle >/dev/null 2>&1 || break
        i=$((i + 1))
        sleep 0.1
    done
fi
hypridle -c "$out" >/dev/null 2>&1 &
