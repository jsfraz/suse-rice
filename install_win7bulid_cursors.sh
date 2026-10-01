#!/bin/bash
# Install Win7Bulid cursor themes for light and dark mode.
# https://github.com/jsfraz/Win7Bulid-cursors-plus-dark

set -euo pipefail

REPO_URL="https://github.com/jsfraz/Win7Bulid-cursors-plus-dark.git"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="${SCRIPT_DIR}/Win7Bulid-cursors-plus-dark"

log() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

command -v git >/dev/null || die "git is required"

if [[ "${EUID}" -eq 0 ]]; then
	die "run as your user so the themes land in ~/.local/share/icons"
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

chmod +x "${SRC_DIR}/install.sh"
log "Installing light and dark variants..."
(
	cd "${SRC_DIR}"
	./install.sh
)

log "Done. Themes are in ~/.local/share/icons/Win7Bulid-cursors and ~/.local/share/icons/Win7Bulid-cursors-dark."
