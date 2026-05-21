#!/bin/sh

set -eu

action="${1:-}"
home_config="$HOME/.config"

case "$action" in
    terminal)
        exec kitty
        ;;
    files)
        exec dolphin
        ;;
    browser)
        exec firefox
        ;;
    reload)
        exec hyprctl reload
        ;;
    power)
        exec wlogout -l "$home_config/wlogout/layout" -C "$home_config/wlogout/style.css" --buttons-per-row 3 --column-spacing 18 --row-spacing 18 --margin 40
        ;;
    *)
        exit 1
        ;;
esac
