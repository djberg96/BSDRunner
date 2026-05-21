#!/bin/sh

set -eu

[ -f "$HOME/.config/hypr/hyprpaper.conf" ] || exit 0
command -v hyprpaper >/dev/null 2>&1 || exit 0

exec hyprpaper
