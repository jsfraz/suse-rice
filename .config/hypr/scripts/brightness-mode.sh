#!/bin/sh
# light or dark. Automatic follows darkman; otherwise the manual rcm value wins.
# Same rule as ~/.config/matugen/matugen.sh.
if [ "$(rcm get autoBrightnessMode 2>/dev/null)" = true ]; then
    darkman get 2>/dev/null || printf '%s\n' light
else
    rcm get brightnessMode
fi
