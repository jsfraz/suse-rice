#!/bin/sh
# App launcher only (launcher.rasi). Screenshot dmenu uses a different theme.
pkill -f '[r]ofi .*launcher.rasi' >/dev/null 2>&1 || true
