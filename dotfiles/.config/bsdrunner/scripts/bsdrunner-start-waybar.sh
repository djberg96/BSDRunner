#!/bin/sh

set -eu

config_home="$HOME/.config"
waybar_config="$config_home/waybar/config"
waybar_style="$config_home/waybar/style.css"
waybar_log="${TMPDIR:-/tmp}/bsdrunner-waybar.log"
startup_wait_loops=50

command -v waybar >/dev/null 2>&1 || exit 0

launch_waybar_direct() {
    waybar -c "$waybar_config" -s "$waybar_style" >"$waybar_log" 2>&1 &
}

launch_waybar_dbus() {
    dbus-launch waybar -c "$waybar_config" -s "$waybar_style" >"$waybar_log" 2>&1 &
}

wait_for_waybar() {
    wait_loops=0
    while [ "$wait_loops" -lt "$startup_wait_loops" ]; do
        if pgrep -x waybar >/dev/null 2>&1; then
            return 0
        fi
        sleep 0.1
        wait_loops=$((wait_loops + 1))
    done
    return 1
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

launch_waybar_direct
first_mode="direct"

if ! wait_for_waybar; then
    if command -v dbus-launch >/dev/null 2>&1; then
        if [ "$first_mode" = "direct" ]; then
            launch_waybar_dbus
        else
            launch_waybar_direct
        fi
        if wait_for_waybar; then
            exit 0
        fi
    fi
fi

if ! pgrep -x waybar >/dev/null 2>&1; then
    echo ":: Failed to start waybar; see $waybar_log" >&2
    exit 1
fi
