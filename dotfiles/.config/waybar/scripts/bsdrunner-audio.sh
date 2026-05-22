#!/bin/sh

set -eu

volume="0"
muted="0"
server_name=""

if command -v pactl >/dev/null 2>&1; then
    server_name="$(pactl info 2>/dev/null | awk -F': ' '/^Server Name:/{print $2; exit}')"
fi

get_pactl_state() {
    pactl_volume="$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | awk '
        {
            for (i = 1; i <= NF; i++) {
                if ($i ~ /^[0-9]+%$/) {
                    gsub(/%/, "", $i)
                    print $i
                    exit
                }
            }
        }
    ')"

    if [ -n "${pactl_volume:-}" ]; then
        volume="$pactl_volume"
    fi

    case "$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null || true)" in
        *yes*)
            muted="1"
            ;;
    esac
}

get_wpctl_state() {
    wpctl_output="$(wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null || true)"

    case "$wpctl_output" in
        *MUTED*)
            muted="1"
            ;;
    esac

    wpctl_volume="$(printf '%s\n' "$wpctl_output" | awk '
        {
            for (i = 1; i <= NF; i++) {
                if ($i ~ /^[0-9]*\.[0-9]+$/ || $i ~ /^[0-9]+$/) {
                    printf "%d", ($i * 100) + 0.5
                    exit
                }
            }
        }
    ')"

    if [ -n "${wpctl_volume:-}" ]; then
        volume="$wpctl_volume"
    fi
}

if [ -n "$server_name" ] && printf '%s\n' "$server_name" | grep -qi 'pulseaudio'; then
    get_pactl_state
elif [ -n "$server_name" ] && printf '%s\n' "$server_name" | grep -qi 'pipewire' && command -v wpctl >/dev/null 2>&1; then
    get_wpctl_state
elif command -v pactl >/dev/null 2>&1; then
    get_pactl_state
elif command -v wpctl >/dev/null 2>&1; then
    get_wpctl_state
fi

if [ "$muted" = "1" ]; then
    printf '{"text":"MUTE","tooltip":"Audio muted","class":"muted"}\n'
else
    printf '{"text":"%s%%","tooltip":"Volume: %s%%","class":"active"}\n' "$volume" "$volume"
fi
