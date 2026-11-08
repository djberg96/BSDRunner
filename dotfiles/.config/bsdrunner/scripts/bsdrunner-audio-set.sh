#!/bin/sh

set -eu

value="${1:-}"
script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
cache_dir="${BSDRUNNER_AUDIO_CACHE_DIR:-$HOME/.cache/bsdrunner}"
state_script="${BSDRUNNER_AUDIO_STATE_SCRIPT:-$script_dir/bsdrunner-audio-state.sh}"
use_oss_mixer="no"

case "$value" in
    ''|*[!0-9]*)
        printf 'Volume must be a whole number from 0 through 100.\n' >&2
        exit 2
        ;;
esac

if [ "$value" -gt 100 ]; then
    value=100
fi

if [ "${BSDRUNNER_AUDIO_FORCE_OSS_MIXER:-no}" = "yes" ]; then
    use_oss_mixer="yes"
elif [ "$(uname -s 2>/dev/null || true)" = "FreeBSD" ] && \
     command -v mixer >/dev/null 2>&1 && \
     command -v pactl >/dev/null 2>&1 && \
     pactl info >/dev/null 2>&1; then
    default_sink="$(pactl get-default-sink 2>/dev/null || true)"
    default_driver="$(pactl list sinks 2>/dev/null | awk -v sink="$default_sink" '
        /^[[:space:]]*Name:/ {
            active = ($2 == sink)
            next
        }
        active && /^[[:space:]]*Driver:/ {
            print $2
            exit
        }
    ')"
    if [ "$default_driver" = "module-oss.c" ]; then
        use_oss_mixer="yes"
    fi
fi

if [ "$use_oss_mixer" = "yes" ] && command -v mixer >/dev/null 2>&1; then
    mixer_value="$(awk -v volume="$value" 'BEGIN { printf "%.2f", volume / 100 }')"
    mixer "vol=$mixer_value" >/dev/null
elif command -v pactl >/dev/null 2>&1 && pactl info >/dev/null 2>&1; then
    pactl set-sink-volume @DEFAULT_SINK@ "${value}%"
elif command -v wpctl >/dev/null 2>&1; then
    wpctl set-volume @DEFAULT_AUDIO_SINK@ "${value}%"
else
    printf 'No supported audio control tool was found.\n' >&2
    exit 1
fi

mkdir -p "$cache_dir"
state_tmp="$(mktemp "$cache_dir/audio-state.XXXXXX")"
if sh "$state_script" > "$state_tmp"; then
    mv "$state_tmp" "$cache_dir/audio-state"
else
    rm -f "$state_tmp"
    exit 1
fi
