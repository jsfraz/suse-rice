#!/bin/sh
# Distro mark for the bar. Arch and the Tux match the AGS bar; openSUSE gets its own mark.
name=$(grep '^NAME=' /etc/os-release | cut -d= -f2- | tr -d '"')
case "$name" in
    "Arch Linux") class=arch ;;
    openSUSE*|SUSE*) class=opensuse ;;
    *) class=linux ;;
esac
printf '{"text":"","class":"%s"}\n' "$class"
