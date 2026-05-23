#!/bin/sh

set -eu

command -v rofi >/dev/null 2>&1 || exit 0

printf '%s\n' \
    'SUPER+Q  Open terminal' \
    'SUPER+E  Open files' \
    'SUPER+F  Open browser' \
    'SUPER+D  Open app launcher' \
    'SUPER+W  Open welcome window' \
    'SUPER+V  Toggle floating window' \
    'SUPER+P  Toggle pseudotile' \
    'SUPER+J  Toggle split direction' \
    'SUPER+S  Toggle scratchpad workspace' \
    'SUPER+1..0  Switch workspaces 1-10' \
    'SUPER+SHIFT+1..0  Move window to workspace 1-10' \
    'SUPER+Arrow keys  Move focus' \
    'SUPER+Mouse wheel  Cycle workspaces' \
    'SUPER+Left drag  Move window' \
    'SUPER+Right drag  Resize window' \
    'XF86Audio keys  Volume and media controls' \
    'XF86Brightness keys  Screen brightness' \
    | rofi -dmenu -i -p "BSDRunner Keys" -mesg "Esc to close" >/dev/null
