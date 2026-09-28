#!/bin/sh
# light or dark. A forced rcm value wins; otherwise follow darkman.
# Same rule as ~/.config/matugen/matugen.sh.
if [ "$(rcm get forcedBrightnessMode 2>/dev/null)" = true ]; then
    rcm get brightnessMode
else
    darkman get 2>/dev/null || printf '%s\n' light
fi
