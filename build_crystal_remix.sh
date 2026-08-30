#!/bin/bash
# Clone Crystal Remix icon theme and build every color variant.
# https://github.com/jsfraz/crystal-remix-icon-theme-color-variants

set -euo pipefail

REPO_URL="https://github.com/jsfraz/crystal-remix-icon-theme-color-variants.git"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="${CRYSTAL_REMIX_SRC_DIR:-${SCRIPT_DIR}/crystal-remix-icon-theme-color-variants}"

log() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

command -v git >/dev/null || die "git is required"
command -v python3 >/dev/null || die "python3 is required (build.sh creates its own venv)"

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

cd "${SRC_DIR}"

chmod +x ./build.sh
log "Building and installing all color variants..."
./build.sh all

log "Done. Themes are in ~/.local/share/icons/crystal-remix-<color>/"
log "Pick a variant in your icon settings, e.g. Crystal Remix Teal."
