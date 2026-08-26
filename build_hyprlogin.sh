#!/bin/bash
# Build and install hyprlogin (greetd greeter forked from hyprlock) on openSUSE.
# https://github.com/AuthenticSm1les/hyprlogin

set -euo pipefail

REPO_URL="https://github.com/AuthenticSm1les/hyprlogin.git"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="${HYPRLOGIN_SRC_DIR:-${SCRIPT_DIR}/hyprlogin}"
PREFIX="${HYPRLOGIN_PREFIX:-/usr}"
JOBS="$(nproc 2>/dev/null || getconf _NPROCESSORS_CONF)"

log() { printf '==> %s\n' "$*"; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

as_root() {
	if [[ "${EUID}" -eq 0 ]]; then
		"$@"
	else
		sudo "$@"
	fi
}

[[ -r /etc/os-release ]] || die "cannot read /etc/os-release"
# shellcheck source=/dev/null
source /etc/os-release
case "${ID}" in
opensuse* | sle*) ;;
*)
	if [[ "${ID_LIKE:-}" != *suse* ]]; then
		die "this script targets openSUSE (found ${PRETTY_NAME:-unknown})"
	fi
	;;
esac

DEPS=(
	git
	cmake
	ninja
	gcc-c++
	pkgconf
	hyprwayland-scanner
	hyprgraphics-devel
	hyprlang-devel
	hyprutils-devel
	cairo-devel
	pango-devel
	libdrm-devel
	libgbm-devel
	Mesa-libEGL-devel
	Mesa-libGLESv2-devel
	Mesa-libGLESv3-devel
	pam-devel
	sdbus-cpp-devel
	wayland-devel
	wayland-protocols-devel
	libxkbcommon-devel
)

log "Installing build dependencies..."
as_root zypper --non-interactive install --no-recommends "${DEPS[@]}"

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

shopt -s nullglob
for patch in "${SCRIPT_DIR}"/patches/*.patch; do
	log "Applying $(basename "${patch}")..."
	git -C "${SRC_DIR}" apply "${patch}"
done
shopt -u nullglob

log "Configuring (Release, prefix=${PREFIX})..."
cmake --no-warn-unused-cli \
	-DCMAKE_BUILD_TYPE:STRING=Release \
	-DCMAKE_INSTALL_PREFIX:PATH="${PREFIX}" \
	-G Ninja \
	-S "${SRC_DIR}" \
	-B "${SRC_DIR}/build"

log "Building hyprlogin (${JOBS} jobs)..."
cmake --build "${SRC_DIR}/build" --config Release --target hyprlogin -j"${JOBS}"

log "Installing to ${PREFIX}..."
as_root cmake --install "${SRC_DIR}/build"

EXAMPLE="${PREFIX}/share/hyprlogin/examples/hyprlogin.conf"
SYSCONF="/etc/hyprlogin/hyprlogin.conf"
if [[ -f "${EXAMPLE}" && ! -e "${SYSCONF}" ]]; then
	log "Installing default config to ${SYSCONF}"
	as_root install -Dm644 "${EXAMPLE}" "${SYSCONF}"
fi

log "Done. Binary: ${PREFIX}/bin/hyprlogin"
log "Example greeter Hyprland config: ${PREFIX}/share/hyprlogin/hyprland-greeter.conf"
log "Example greetd config: ${PREFIX}/share/hyprlogin/greetd-config.toml"
log "To boot into hyprlogin after LUKS unlock, run: ${SCRIPT_DIR}/setup_greetd.sh"
