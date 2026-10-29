#!/bin/sh

set -eu

command -v rofi >/dev/null 2>&1 || exit 0
launcher="${ROFI_CMD:-rofi -dmenu}"

printf '%s\n' \
    'SUPER+Q  Open terminal' \
    'SUPER+C  Close focused window' \
    'SUPER+M  Shut down Hyprland' \
    'SUPER+E  Open files' \
    'SUPER+F  Open browser' \
    'SUPER+D  Open app launcher' \
    'SUPER+R  Open Hyprlauncher' \
    'SUPER+W  Open welcome window' \
    'SUPER+X  Exit Hyprland' \
    'SUPER+V  Toggle floating window' \
    'SUPER+P  Toggle pseudotile' \
    'SUPER+J  Toggle split direction' \
    'SUPER+S  Toggle scratchpad workspace' \
    'SUPER+SHIFT+S  Move window to scratchpad' \
    'SUPER+1..0  Switch workspaces 1-10' \
    'SUPER+SHIFT+1..0  Move window to workspace 1-10' \
    'SUPER+Arrow keys  Move focus' \
    'SUPER+Mouse wheel  Cycle workspaces' \
    'SUPER+Left drag  Move window' \
    'SUPER+Right drag  Resize window' \
    'Volume Up/Down  Adjust output volume' \
    'Mute  Toggle output mute' \
    'Mic Mute  Toggle microphone mute' \
    'Media keys  Previous, play/pause, and next' \
    'Brightness Up/Down  Adjust screen brightness' \
    'PRINT  Save a full-screen screenshot' \
    'SHIFT+PRINT  Select and save a screenshot region' \
    'CTRL+PRINT  Copy a screenshot region to clipboard' \
    | $launcher -i -p "BSDRunner Keys" -mesg "Esc to close" >/dev/null 2>/dev/null
