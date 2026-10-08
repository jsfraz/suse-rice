#!/bin/sh
# GNOME keyring (Secret Service) + polkit agent for a Hyprland session.
# Needed by Cursor, NetworkManager VPN secrets, and nm-connection-editor saves.
export PATH="${PATH}:/usr/local/bin:${HOME}/.local/bin"

if command -v gnome-keyring-daemon >/dev/null 2>&1; then
    eval "$(gnome-keyring-daemon --start --components=pkcs11,secrets,ssh 2>/dev/null)"
    [ -n "${SSH_AUTH_SOCK:-}" ] && export SSH_AUTH_SOCK
    if command -v dbus-update-activation-environment >/dev/null 2>&1; then
        dbus-update-activation-environment --systemd \
            GNOME_KEYRING_CONTROL SSH_AUTH_SOCK XDG_CURRENT_DESKTOP >/dev/null 2>&1 || true
    fi
    # tty autologin + uwsm never runs pam_gnome_keyring (only_if=gdm,… on openSUSE).
    unlock_file="${HOME}/.config/suse-rice/unlock-keyring"
    if [ -f "$unlock_file" ]; then
        gnome-keyring-daemon --unlock <"$unlock_file" 2>/dev/null || true
    fi
fi

if [ -x /usr/libexec/polkit-gnome-authentication-agent-1 ]; then
    pgrep -f polkit-gnome-authentication-agent >/dev/null 2>&1 || \
        /usr/libexec/polkit-gnome-authentication-agent-1 &
fi
