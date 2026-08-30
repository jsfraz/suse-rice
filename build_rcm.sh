#!/bin/sh
set -e

# Get the path to the rcm folder
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RCM_DIR="$SCRIPT_DIR/rcm"

# Check if the rcm folder exists
if [ ! -d "$RCM_DIR" ]; then
    echo "Error: rcm/ folder not found!"
    exit 1
fi

# sudo resets PATH (secure_path), so Go is often missing as root.
# Build as the original user; elevate only for the install step.
if [ "$(id -u)" -eq 0 ] && [ -n "${SUDO_USER:-}" ]; then
    if ! sudo -u "$SUDO_USER" -H bash -lc 'command -v go >/dev/null 2>&1'; then
        echo "Error: Go is not installed. Please install it using your package manager."
        exit 1
    fi
    echo "Compiling rcm..."
    sudo -u "$SUDO_USER" -H bash -lc "cd '$RCM_DIR' && go build -o rcm ."
else
    if ! command -v go >/dev/null 2>&1; then
        echo "Error: Go is not installed. Please install it using your package manager."
        exit 1
    fi
    echo "Compiling rcm..."
    (cd "$RCM_DIR" && go build -o rcm .)
fi

INSTALL_DIR="/usr/local/bin"
echo "Installing rcm to $INSTALL_DIR..."

if [ "$(id -u)" -eq 0 ]; then
    install -m 755 "$RCM_DIR/rcm" "$INSTALL_DIR/rcm"
else
    sudo install -m 755 "$RCM_DIR/rcm" "$INSTALL_DIR/rcm"
fi

rm -f "$RCM_DIR/rcm"

echo "rcm was successfully installed to $INSTALL_DIR"
echo "You can run it using the command: rcm"
