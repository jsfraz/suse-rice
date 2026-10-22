#!/bin/bash
# Install XSI (XApp Symbolic Icons) into the hicolor fallback theme.
# https://github.com/xapp-project/xapp-symbolic-icons
#
# Nemo 6 asks for xsi-*-symbolic icons for its toolbar, sidebar and view
# buttons. They are not part of any desktop icon theme and openSUSE does not
# package them, so without this every one of those buttons renders as the
# "image-missing" placeholder. hicolor is the last fallback of every theme,
# so installing the set there fixes Nemo under Crystal Remix and friends.

set -euo pipefail

REPO_URL="https://github.com/xapp-project/xapp-symbolic-icons.git"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="${XSI_SRC_DIR:-${SCRIPT_DIR}/xapp-symbolic-icons}"
DEST_DIR="${XSI_DEST_DIR:-${HOME}/.local/share/icons/hicolor/scalable/actions}"

log() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

command -v git >/dev/null || die "git is required"

if [[ "${EUID}" -eq 0 ]]; then
	die "run as your user so the icons land in ~/.local/share/icons"
fi

if [[ -d "${SRC_DIR}/.git" ]]; then
	log "Updating ${SRC_DIR}..."
	git -C "${SRC_DIR}" fetch --depth 1 origin
	git -C "${SRC_DIR}" reset --hard FETCH_HEAD
elif [[ -e "${SRC_DIR}" ]]; then
	die "${SRC_DIR} exists but is not a git repository"
else
	log "Cloning ${REPO_URL}..."
	git clone --depth 1 "${REPO_URL}" "${SRC_DIR}"
fi

[[ -d "${SRC_DIR}/icons/symbolic" ]] || die "${SRC_DIR}/icons/symbolic not found"

log "Installing XSI icons to ${DEST_DIR}..."
install -d "${DEST_DIR}"
cp -f "${SRC_DIR}/icons/symbolic/"*.svg "${DEST_DIR}/"

count=$(find "${DEST_DIR}" -maxdepth 1 -name 'xsi-*.svg' | wc -l)
log "Installed ${count} xsi- icons."

# Running apps cache the theme; refresh the theme's cache and restart Nemo.
if command -v gtk-update-icon-cache >/dev/null; then
	gtk-update-icon-cache -f -t "${HOME}/.local/share/icons/hicolor" >/dev/null 2>&1 || true
fi

if pgrep -x nemo >/dev/null; then
	log "Nemo is running - run 'nemo -q' and reopen it to pick up the icons."
fi

log "Done."
