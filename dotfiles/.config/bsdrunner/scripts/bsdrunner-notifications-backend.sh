#!/bin/sh
set -efu
PATH="${BSDRUNNER_NOTIFICATIONS_PATH:-/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}}"
makoctl_bin="${BSDRUNNER_MAKOCTL_BIN:-makoctl}"

read_notifications() {
    active="$("$makoctl_bin" list -j 2>/dev/null)" || return 1
    history="$("$makoctl_bin" history -j 2>/dev/null)" || return 1
    printf '%s\n' "$active" | jq -e 'type == "array"' >/dev/null 2>&1 || return 1
    printf '%s\n' "$history" | jq -e 'type == "array"' >/dev/null 2>&1 || return 1
}

if ! command -v "$makoctl_bin" >/dev/null 2>&1; then
    jq -nc '{ok:false, message:"Mako is not installed.", notifications:[]}'
    exit 0
fi

if ! read_notifications; then
    found=no
    if command -v dbus-send >/dev/null 2>&1; then
        set +f
        for socket in "${XDG_RUNTIME_DIR:-/tmp}/bus" /tmp/dbus-*; do
            [ -S "$socket" ] || continue
            [ "$(stat -f '%u' "$socket" 2>/dev/null || true)" = "$(id -u)" ] || continue
            names="$(DBUS_SESSION_BUS_ADDRESS="unix:path=$socket" dbus-send --session \
                --print-reply=literal --reply-timeout=500 --dest=org.freedesktop.DBus \
                / org.freedesktop.DBus.ListNames 2>/dev/null || true)"
            case "$names" in *org.freedesktop.Notifications*) ;; *) continue ;; esac
            DBUS_SESSION_BUS_ADDRESS="unix:path=$socket"
            export DBUS_SESSION_BUS_ADDRESS
            if read_notifications; then found=yes; break; fi
        done
        set -f
    fi
    if [ "$found" != yes ]; then
        jq -nc '{ok:false, message:"Could not reach the Mako notification service.", notifications:[]}'
        exit 0
    fi
fi

jq -nc --argjson active "$active" --argjson history "$history" '
    def simplify($status): map(select(type == "object") | {
        id: .id, app: (if (.app_name | type) == "string" and .app_name != "" then .app_name else "Notification" end),
        title: (if (.summary | type) == "string" then .summary else "" end),
        body: (if (.body | type) == "string" then .body else "" end), status: $status
    });
    {ok:true, message:"", notifications:(($active | simplify("Active")) + ($history | simplify("Recent")) | .[:100])}
'
