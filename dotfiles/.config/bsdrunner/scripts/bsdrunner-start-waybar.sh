#!/bin/sh

set -eu

config_home="$HOME/.config"
waybar_config="$config_home/waybar/config"
waybar_style="$config_home/waybar/style.css"

command -v dbus-launch >/dev/null 2>&1 || exit 0
command -v waybar >/dev/null 2>&1 || exit 0

pkill -x waybar 2>/dev/null || true
pkill -f "dbus-launch waybar" 2>/dev/null || true

waybar_wait=0
while pgrep -x waybar >/dev/null 2>&1; do
    sleep 0.1
    waybar_wait=$((waybar_wait + 1))
    if [ "$waybar_wait" -ge 20 ]; then
        pkill -9 waybar 2>/dev/null || true
        break
    fi
done

exec dbus-launch waybar -c "$waybar_config" -s "$waybar_style"
