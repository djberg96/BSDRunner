#!/bin/sh

# Toggle FreeBSD WLAN interfaces and the ThinkPad Bluetooth switch. Record
# precisely which radios were enabled, so a second press restores only those.
set -efu
PATH="${BSDRUNNER_WIRELESS_PATH:-/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}}"
state_dir="${BSDRUNNER_WIRELESS_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/bsdrunner/wireless-toggle}"
state_file="$state_dir/restore.conf"
bluetooth_key="dev.acpi_ibm.0.bluetooth"
umask 077

notify() {
    if command -v notify-send >/dev/null 2>&1; then
        if notify-send -t 7000 "Wireless controls" "$1" >/dev/null 2>&1; then
            return 0
        fi
        # The session can inherit a stale bus address. Find the current
        # user's bus that actually hosts the desktop notification service.
        if command -v dbus-send >/dev/null 2>&1; then
            set +f
            for bus_socket in "${XDG_RUNTIME_DIR:-/tmp}/bus" /tmp/dbus-*; do
                [ -S "$bus_socket" ] || continue
                [ "$(stat -f '%u' "$bus_socket" 2>/dev/null || true)" = "$(id -u)" ] || continue
                bus_names="$(DBUS_SESSION_BUS_ADDRESS="unix:path=$bus_socket" \
                    dbus-send --session --print-reply=literal --reply-timeout=500 \
                    --dest=org.freedesktop.DBus / org.freedesktop.DBus.ListNames 2>/dev/null || true)"
                case "$bus_names" in
                    *org.freedesktop.Notifications*)
                        if DBUS_SESSION_BUS_ADDRESS="unix:path=$bus_socket" \
                            notify-send -t 7000 "Wireless controls" "$1" >/dev/null 2>&1; then
                            set -f
                            return 0
                        fi
                        ;;
                esac
            done
            set -f
        fi
    fi
    if command -v hyprctl >/dev/null 2>&1 && \
        hyprctl notify 1 7000 'rgb(89b4fa)' "Wireless controls: $1" >/dev/null 2>&1; then
        return 0
    fi
    printf 'Unable to show wireless notification: %s\n' "$1" >&2
}
fail() {
    printf '%s\n' "$1" >&2
    notify "$1"
    exit 1
}
privileged() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    elif command -v mdo >/dev/null 2>&1; then
        mdo "$@"
    elif command -v doas >/dev/null 2>&1; then
        doas -n "$@"
    else
        return 1
    fi
}
valid_interface() {
    case "$1" in ''|*[!A-Za-z0-9_.:-]*|.*) return 1 ;; esac
}
restore_radios() {
    failed=no
    wlan_interfaces="$(ifconfig -g wlan -l 2>/dev/null)" || return 1
    while IFS= read -r entry; do
        case "$entry" in
            wifi=*)
                iface="${entry#wifi=}"
                valid_interface "$iface" || { failed=yes; continue; }
                case " $wlan_interfaces " in
                    *" $iface "*) privileged ifconfig "$iface" up >/dev/null 2>&1 || failed=yes ;;
                    *) failed=yes ;;
                esac
                ;;
            bluetooth=1) privileged sysctl "$bluetooth_key=1" >/dev/null 2>&1 || failed=yes ;;
            *) failed=yes ;;
        esac
    done < "$state_file"
    [ "$failed" = no ]
}

case "${1:-toggle}" in
    toggle)
        [ "$(uname -s)" = FreeBSD ] || fail "This wireless control requires FreeBSD."
        command -v lockf >/dev/null 2>&1 || fail "Unable to lock wireless controls."
        mkdir -p "$state_dir" || fail "Unable to save the wireless state."
        exec lockf -t 0 "$state_dir/lock" sh "$0" --locked
        ;;
    --locked)
        if [ -f "$state_file" ]; then
            if restore_radios; then
                rm -f "$state_file"
                notify "Previous Wi-Fi and Bluetooth settings restored. Wi-Fi may take a moment to reconnect."
            else
                fail "Could not restore all wireless settings. Press F8 again to retry."
            fi
            exit 0
        fi

        all_wlan="$(ifconfig -g wlan -l 2>/dev/null)" || fail "Unable to list Wi-Fi interfaces."
        up_wlan="$(ifconfig -u -g wlan -l 2>/dev/null)" || fail "Unable to read Wi-Fi state."
        bluetooth="$(sysctl -n "$bluetooth_key" 2>/dev/null)" || fail "ThinkPad Bluetooth control is unavailable."
        case "$bluetooth" in 0|1) ;; *) fail "Unable to read Bluetooth state." ;; esac
        [ -n "$up_wlan" ] || [ "$bluetooth" = 1 ] || fail "Wi-Fi and ThinkPad Bluetooth are already off."

        tmp_state="$(mktemp "$state_dir/restore.XXXXXX")" || fail "Unable to save the wireless state."
        trap 'rm -f "$tmp_state"' EXIT HUP INT TERM
        for iface in $up_wlan; do
            valid_interface "$iface" || fail "Invalid Wi-Fi interface name."
            case " $all_wlan " in *" $iface "*) ;; *) fail "Could not verify the Wi-Fi interface." ;; esac
            printf 'wifi=%s\n' "$iface" >> "$tmp_state"
        done
        [ "$bluetooth" != 1 ] || printf 'bluetooth=1\n' >> "$tmp_state"
        mv "$tmp_state" "$state_file" || fail "Unable to save the wireless state."
        trap - EXIT HUP INT TERM

        disabled=yes
        for iface in $up_wlan; do
            if ! privileged ifconfig "$iface" down >/dev/null 2>&1; then disabled=no; break; fi
        done
        if [ "$disabled" = yes ] && [ "$bluetooth" = 1 ]; then
            privileged sysctl "$bluetooth_key=0" >/dev/null 2>&1 || disabled=no
        fi
        if [ "$disabled" != yes ]; then
            if restore_radios; then
                rm -f "$state_file"
                fail "Could not turn off wireless controls; previous settings were restored."
            fi
            fail "Could not turn off wireless controls or restore everything. Press F8 again to retry restoration."
        fi
        notify "Wi-Fi interfaces are down and ThinkPad Bluetooth is off. Press F8 to restore their previous settings."
        ;;
    *) fail "Usage: $0 [toggle]" ;;
esac
