#!/bin/sh

set -eu
PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}"

config_home="$HOME/.config"
waybar_config="$config_home/waybar/config"
waybar_style="$config_home/waybar/style.css"

command -v dbus-launch >/dev/null 2>&1 || exit 0
command -v waybar >/dev/null 2>&1 || exit 0

launch_waybar_direct() {
    waybar -c "$waybar_config" -s "$waybar_style" >/tmp/bsdrunner-waybar.log 2>&1 &
}

launch_waybar_dbus() {
    dbus-launch waybar -c "$waybar_config" -s "$waybar_style" >/tmp/bsdrunner-waybar.log 2>&1 &
}

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

if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then
    launch_waybar_direct
    first_mode="direct"
else
    launch_waybar_dbus
    first_mode="dbus"
fi

sleep 0.7

if ! pgrep -x waybar >/dev/null 2>&1; then
    if [ "$first_mode" = "direct" ]; then
        launch_waybar_dbus
    else
        launch_waybar_direct
    fi
    sleep 0.7
fi

if ! pgrep -x waybar >/dev/null 2>&1; then
    echo ":: Failed to start waybar" >&2
    exit 1
fi
