#!/bin/sh

set -eu
PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}"

config_home="$HOME/.config"
waybar_config="$config_home/waybar/config"
waybar_style="$config_home/waybar/style.css"
waybar_log="${BSDRUNNER_WAYBAR_LOG:-/tmp/bsdrunner-waybar.log}"

waybar_process_snapshot() {
    if [ -n "${BSDRUNNER_WAYBAR_PS_FILE:-}" ]; then
        cat "$BSDRUNNER_WAYBAR_PS_FILE"
    else
        ps ax -o stat= -o comm= 2>/dev/null
    fi
}

waybar_running() {
    # FreeBSD's pgrep includes zombie processes. A defunct Waybar has no
    # visible layer surface and must not count as a successful launch.
    waybar_process_snapshot | awk '
        $1 !~ /^Z/ && $2 == "waybar" { found = 1; exit }
        END { exit found ? 0 : 1 }
    '
}

if [ "${BSDRUNNER_WAYBAR_CHECK_ONLY:-no}" = "yes" ]; then
    if waybar_running; then
        exit 0
    fi
    exit 1
fi

command -v waybar >/dev/null 2>&1 || exit 0

session_bus_usable() {
    [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ] || return 1
    command -v dbus-send >/dev/null 2>&1 || return 1
    dbus-send --session --print-reply=literal --reply-timeout=500 \
        --dest=org.freedesktop.DBus / org.freedesktop.DBus.ListNames \
        >/dev/null 2>&1
}

discover_session_bus() {
    best_socket=""
    best_score=0
    current_uid="$(id -u)"

    for bus_socket in "${XDG_RUNTIME_DIR:-/tmp}/bus" /tmp/dbus-*; do
        [ -S "$bus_socket" ] || continue
        [ "$(stat -f '%u' "$bus_socket" 2>/dev/null || printf 'unknown')" = "$current_uid" ] || continue

        bus_names="$(
            DBUS_SESSION_BUS_ADDRESS="unix:path=$bus_socket" \
                dbus-send --session --print-reply=literal --reply-timeout=500 \
                    --dest=org.freedesktop.DBus / org.freedesktop.DBus.ListNames \
                    2>/dev/null || true
        )"
        [ -n "$bus_names" ] || continue

        bus_score="$(printf '%s\n' "$bus_names" | awk '{ count += NF } END { print count + 0 }')"
        case "$bus_names" in
            *org.freedesktop.Notifications*) bus_score=$((bus_score + 1000)) ;;
        esac

        if [ "$bus_score" -gt "$best_score" ]; then
            best_score="$bus_score"
            best_socket="$bus_socket"
        fi
    done

    [ -n "$best_socket" ] || return 1
    printf 'unix:path=%s\n' "$best_socket"
}

if ! session_bus_usable; then
    recovered_bus="$(discover_session_bus || true)"
    if [ -n "$recovered_bus" ]; then
        DBUS_SESSION_BUS_ADDRESS="$recovered_bus"
        export DBUS_SESSION_BUS_ADDRESS
    fi
fi

launch_detached() {
    if command -v daemon >/dev/null 2>&1; then
        daemon -f -o "$waybar_log" "$@"
    else
        (nohup "$@" >>"$waybar_log" 2>&1 &) >/dev/null 2>&1
    fi
}

launch_waybar_direct() {
    launch_detached waybar -c "$waybar_config" -s "$waybar_style"
}

launch_waybar_private_bus() {
    if command -v dbus-run-session >/dev/null 2>&1; then
        launch_detached env -u DBUS_SESSION_BUS_ADDRESS \
            dbus-run-session -- waybar -c "$waybar_config" -s "$waybar_style"
    elif command -v dbus-launch >/dev/null 2>&1; then
        launch_detached env -u DBUS_SESSION_BUS_ADDRESS \
            dbus-launch waybar -c "$waybar_config" -s "$waybar_style"
    fi
}

pkill -x waybar 2>/dev/null || true
pkill -f "dbus-launch waybar" 2>/dev/null || true

waybar_wait=0
while waybar_running; do
    sleep 0.1
    waybar_wait=$((waybar_wait + 1))
    if [ "$waybar_wait" -ge 20 ]; then
        pkill -9 -x waybar 2>/dev/null || true
        break
    fi
done

if session_bus_usable; then
    launch_waybar_direct
    first_mode="direct"
else
    launch_waybar_private_bus
    first_mode="private"
fi

sleep 0.7

if ! waybar_running; then
    if [ "$first_mode" = "direct" ]; then
        launch_waybar_private_bus
    else
        launch_waybar_direct
    fi
    sleep 0.7
fi

if ! waybar_running; then
    echo ":: Failed to start waybar" >&2
    exit 1
fi
