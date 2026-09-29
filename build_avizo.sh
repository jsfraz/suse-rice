#!/bin/bash
# Clone, build, and install Avizo (OSD for volume, brightness, and similar keys).
# https://github.com/heyjuvi/avizo

set -euo pipefail

REPO_URL="https://github.com/heyjuvi/avizo.git"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="${AVIZO_SRC_DIR:-${SCRIPT_DIR}/avizo}"
PREFIX="${AVIZO_PREFIX:-/usr/local}"

BUILD_DEPS=(
	gcc
	meson
	ninja
	pkgconf-pkg-config
	vala
	glib2-devel
	gtk3-devel
	gobject-introspection-devel
	gtk-layer-shell-devel
	pamixer
)

log() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

command -v git >/dev/null || die "git is required"
command -v sudo >/dev/null || die "sudo is required"
command -v zypper >/dev/null || die "zypper is required (openSUSE)"

log "Installing build dependencies..."
sudo zypper --non-interactive install "${BUILD_DEPS[@]}"

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

PATCH="${SCRIPT_DIR}/patches/avizo-rounded-level.patch"
if [[ -f "${PATCH}" ]]; then
	log "Rounding the level indicator..."
	git -C "${SRC_DIR}" apply "${PATCH}"
fi

log "Configuring..."
rm -rf "${SRC_DIR}/build"
meson setup "${SRC_DIR}/build" "${SRC_DIR}" --prefix="${PREFIX}"

log "Compiling..."
meson compile -C "${SRC_DIR}/build"

log "Installing to ${PREFIX}..."
sudo meson install -C "${SRC_DIR}/build"

log "Done. Binaries are in ${PREFIX}/bin (avizo-service, avizo-client, volumectl, lightctl)."
log "Start the daemon with: avizo-service"
