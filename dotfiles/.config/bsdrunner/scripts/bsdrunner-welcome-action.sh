#!/bin/sh

set -eu

action="${1:-}"
home_config="$HOME/.config"

case "$action" in
    theme:default)
        exec sh "$home_config/bsdrunner/scripts/bsdrunner-apply-theme.sh" default
        ;;
    theme:jinteki)
        exec sh "$home_config/bsdrunner/scripts/bsdrunner-apply-theme.sh" jinteki
        ;;
    theme:haas-bioroid)
        exec sh "$home_config/bsdrunner/scripts/bsdrunner-apply-theme.sh" haas-bioroid
        ;;
    theme:nbn)
        exec sh "$home_config/bsdrunner/scripts/bsdrunner-apply-theme.sh" nbn
        ;;
    theme:weyland)
        exec sh "$home_config/bsdrunner/scripts/bsdrunner-apply-theme.sh" weyland
        ;;
    terminal)
        exec kitty
        ;;
    files)
        exec dolphin
        ;;
    browser)
        exec firefox
        ;;
    apps)
        exec sh "$home_config/bsdrunner/scripts/bsdrunner-apps-menu.sh"
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
