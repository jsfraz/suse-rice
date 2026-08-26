#!/bin/bash
# Configure greetd so that after LUKS unlock, graphical.target starts hyprlogin.
# This is not desktop autologin: hyprlogin still asks for a password.
# https://github.com/AuthenticSm1les/hyprlogin

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GREETD_SRC="${SCRIPT_DIR}/config/greetd/config.toml"
GREETER_HYPR_SRC="${SCRIPT_DIR}/config/hyprlogin/hyprland-greeter.conf"
GREETD_DST="/etc/greetd/config.toml"
GREETER_HYPR_DST="/etc/hyprlogin/hyprland-greeter.conf"
HYPRLOGIN_CONF="/etc/hyprlogin/hyprlogin.conf"
HYPRLOGIN_EXAMPLE="/usr/share/hyprlogin/examples/hyprlogin.conf"
VERIFY_ONLY=0

log() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }
ok() { printf '    ok  %s\n' "$*"; }
fail() { printf '    FAIL %s\n' "$*" >&2; FAIL=1; }

as_root() {
	if [[ "${EUID}" -eq 0 ]]; then
		"$@"
	else
		sudo "$@"
	fi
}

usage() {
	cat <<'EOF'
Usage: setup_greetd.sh [--verify-only]

Install greetd/hyprlogin configs, enable greetd as the display manager,
and set graphical.target as the boot default.

  --verify-only   Check the live config without changing anything
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
	--verify-only) VERIFY_ONLY=1 ;;
	-h | --help)
		usage
		exit 0
		;;
	*) die "unknown argument: $1" ;;
	esac
	shift
done

login_user() {
	if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != root ]]; then
		printf '%s\n' "${SUDO_USER}"
		return
	fi
	if [[ "${EUID}" -ne 0 ]]; then
		id -un
		return
	fi
	logname 2>/dev/null || id -un
}

ensure_sessions_block() {
	local user="$1"
	as_root python3 - "$HYPRLOGIN_CONF" "$user" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
user = sys.argv[2]
text = path.read_text()
block = (
    "sessions {\n"
    f"    default_user = {user}\n"
    "    default_session = hyprland.desktop\n"
    "}\n"
)
if re.search(r"(?m)^sessions\s*\{", text):
    text = re.sub(r"(?ms)^sessions\s*\{.*?^\}[ \t]*\n?", block, text, count=1)
else:
    marker = "$font = Monospace"
    if marker in text:
        text = text.replace(marker, block + "\n" + marker, 1)
    else:
        text = block + "\n" + text
text = text.replace("$LAYOUT[en,ru]", "$LAYOUT[cz]")
path.write_text(text)
PY
}

verify() {
	local FAIL=0
	local default_target dm_link greetd_user greetd_cmd

	printf '==> Verifying greetd / hyprlogin boot path\n'

	command -v greetd >/dev/null || fail "greetd binary missing"
	command -v hyprlogin >/dev/null || fail "hyprlogin binary missing"
	command -v start-hyprland >/dev/null || fail "start-hyprland binary missing"
	command -v Hyprland >/dev/null || fail "Hyprland binary missing"
	[[ -f /usr/share/wayland-sessions/hyprland.desktop ]] || fail "hyprland.desktop session missing"

	default_target="$(systemctl get-default)"
	if [[ "${default_target}" == graphical.target ]]; then
		ok "default target is graphical.target"
	else
		fail "default target is ${default_target} (need graphical.target)"
	fi

	if systemctl is-enabled greetd.service >/dev/null 2>&1; then
		ok "greetd.service is enabled"
	else
		fail "greetd.service is not enabled"
	fi

	dm_link="$(readlink -f /etc/systemd/system/display-manager.service 2>/dev/null || true)"
	if [[ "${dm_link}" == *greetd.service ]]; then
		ok "display-manager.service -> greetd"
	else
		fail "display-manager.service is not greetd (${dm_link:-missing})"
	fi

	if [[ -f "${GREETD_DST}" ]]; then
		ok "${GREETD_DST} exists"
		if grep -qE '^[[:space:]]*\[initial_session\]' "${GREETD_DST}"; then
			fail "${GREETD_DST} has [initial_session] (that skips hyprlogin)"
		else
			ok "no [initial_session] (hyprlogin will be shown)"
		fi

		greetd_user="$(awk '
			$0 ~ /^\[/ { in_default = ($0 ~ /^\[default_session\]/) }
			in_default && $1 == "user" {
				gsub(/[" ]/, "", $3)
				print $3
				exit
			}
		' "${GREETD_DST}")"
		if [[ "${greetd_user}" == greeter ]]; then
			ok "greetd default_session user is greeter"
		else
			fail "greetd default_session user is '${greetd_user:-unset}' (need greeter)"
		fi

		greetd_cmd="$(awk '
			$0 ~ /^\[/ { in_default = ($0 ~ /^\[default_session\]/) }
			in_default && $1 == "command" {
				sub(/^[^=]+= */, "")
				gsub(/^"|"$/, "")
				print
				exit
			}
		' "${GREETD_DST}")"
		if [[ "${greetd_cmd}" == *"start-hyprland"* && "${greetd_cmd}" == *"${GREETER_HYPR_DST}"* ]]; then
			ok "greetd starts Hyprland with ${GREETER_HYPR_DST}"
		else
			fail "greetd command is '${greetd_cmd:-unset}'"
		fi
	else
		fail "${GREETD_DST} missing"
	fi

	if [[ -f "${GREETER_HYPR_DST}" ]]; then
		ok "${GREETER_HYPR_DST} exists"
		if grep -qE '^[[:space:]]*exec-once[[:space:]]*=[[:space:]]*hyprlogin' "${GREETER_HYPR_DST}"; then
			ok "greeter Hyprland config launches hyprlogin"
		else
			fail "${GREETER_HYPR_DST} does not exec hyprlogin"
		fi
	else
		fail "${GREETER_HYPR_DST} missing"
	fi

	if getent passwd greeter >/dev/null; then
		ok "greeter user exists"
	else
		fail "greeter user missing"
	fi

	id -nG greeter 2>/dev/null | grep -qw video && ok "greeter is in video" || fail "greeter is not in video"
	id -nG greeter 2>/dev/null | grep -qw render && ok "greeter is in render" || fail "greeter is not in render"

	if [[ -f "${HYPRLOGIN_CONF}" ]]; then
		ok "${HYPRLOGIN_CONF} exists"
		if grep -qE '^[[:space:]]*default_user[[:space:]]*=' "${HYPRLOGIN_CONF}"; then
			ok "hyprlogin has sessions:default_user"
		else
			fail "hyprlogin.conf has no sessions:default_user"
		fi
		if grep -qE '^[[:space:]]*default_session[[:space:]]*=[[:space:]]*hyprland.desktop' "${HYPRLOGIN_CONF}"; then
			ok "hyprlogin default session is hyprland.desktop"
		else
			fail "hyprlogin.conf has no sessions:default_session = hyprland.desktop"
		fi
	else
		fail "${HYPRLOGIN_CONF} missing"
	fi

	if [[ ${FAIL} -eq 0 ]]; then
		printf '==> Config looks good. After LUKS unlock, reboot should show hyprlogin.\n'
		printf '    Do not systemctl start greetd from this TTY: it conflicts with getty@tty1.\n'
		return 0
	fi
	printf '==> Config check failed.\n' >&2
	return 1
}

if [[ "${VERIFY_ONLY}" -eq 1 ]]; then
	verify
	exit
fi

[[ -f "${GREETD_SRC}" ]] || die "missing ${GREETD_SRC}"
[[ -f "${GREETER_HYPR_SRC}" ]] || die "missing ${GREETER_HYPR_SRC}"
command -v hyprlogin >/dev/null || die "hyprlogin is not installed; run ./build_hyprlogin.sh first"
command -v greetd >/dev/null || die "greetd is not installed"
command -v start-hyprland >/dev/null || die "start-hyprland is not installed"

LOGIN_USER="$(login_user)"
getent passwd "${LOGIN_USER}" >/dev/null || die "login user ${LOGIN_USER} does not exist"

if ! getent passwd greeter >/dev/null; then
	log "Creating greeter user..."
	as_root useradd -r -M -d /var/lib/greetd -s /usr/sbin/nologin greeter
fi
as_root install -d -m 750 -o greeter -g greeter /var/lib/greetd
as_root usermod -aG video,render greeter

log "Installing ${GREETD_DST}"
as_root install -Dm644 "${GREETD_SRC}" "${GREETD_DST}"

log "Installing ${GREETER_HYPR_DST}"
as_root install -Dm644 "${GREETER_HYPR_SRC}" "${GREETER_HYPR_DST}"

if [[ ! -e "${HYPRLOGIN_CONF}" ]]; then
	[[ -f "${HYPRLOGIN_EXAMPLE}" ]] || die "missing ${HYPRLOGIN_EXAMPLE}"
	log "Installing ${HYPRLOGIN_CONF} from example"
	as_root install -Dm644 "${HYPRLOGIN_EXAMPLE}" "${HYPRLOGIN_CONF}"
fi

log "Setting hyprlogin default user=${LOGIN_USER} session=hyprland.desktop"
ensure_sessions_block "${LOGIN_USER}"

log "Enabling greetd as display manager..."
as_root systemctl enable greetd.service

log "Setting default boot target to graphical.target..."
as_root systemctl set-default graphical.target

verify
log "Reboot to show hyprlogin after LUKS unlock."
