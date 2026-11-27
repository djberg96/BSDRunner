#!/bin/sh

set -eu

repo_root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
scripts_dir="$repo_root/dotfiles/.config/bsdrunner/scripts"
waybar_config="$repo_root/dotfiles/.config/waybar/config"
audio_qml="$repo_root/dotfiles/.config/quickshell/bsdrunner-audio/shell.qml"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/bsdrunner-audio-tests.XXXXXX")"
mock_bin="$test_root/bin"
audio_state="$test_root/mock-audio-state"
cache_dir="$test_root/cache"

cleanup() {
    rm -rf "$test_root"
}
trap cleanup EXIT HUP INT TERM

fail() {
    printf 'not ok - %s\n' "$1" >&2
    exit 1
}

pass() {
    printf 'ok - %s\n' "$1"
}

mkdir -p "$mock_bin"
printf 'volume=75\nmuted=no\n' > "$audio_state"

for required in \
    "$scripts_dir/bsdrunner-audio-popup.sh" \
    "$scripts_dir/bsdrunner-audio-state.sh" \
    "$scripts_dir/bsdrunner-audio-set.sh" \
    "$scripts_dir/bsdrunner-audio-step.sh" \
    "$scripts_dir/bsdrunner-audio-mute.sh" \
    "$scripts_dir/bsdrunner-microphone-mute.sh" \
    "$scripts_dir/bsdrunner-thinkpad-mic-watch.sh" \
    "$audio_qml"; do
    [ -f "$required" ] || fail "missing audio component: $required"
done
pass "audio slider components are present"

grep -Fq 'property bool dragging: false' "$audio_qml" || fail "slider does not guard state refreshes while dragging"
grep -Fq 'property bool applyInFlight: false' "$audio_qml" || fail "slider does not guard state refreshes while applying"
grep -Fq 'Slider {' "$audio_qml" || fail "audio panel does not use the native Qt slider"
grep -Fq 'if (root.applyInFlight)' "$audio_qml" || fail "slider does not preserve its optimistic release position"
grep -Fq 'root.commitVolume(root.currentVolume)' "$audio_qml" || fail "slider does not commit its displayed integer value"
if grep -Fq 'id: applyTimer' "$audio_qml"; then
    fail "slider still sends debounced writes during a drag"
fi
pass "audio slider applies volume once after dragging"

jq -e '.[0].pulseaudio["on-click"] | contains("bsdrunner-audio-popup.sh")' "$waybar_config" >/dev/null || \
    fail "left click does not open the master volume slider"
[ "$(jq -r '.[0].pulseaudio["on-click-right"]' "$waybar_config")" = "pavucontrol" ] || \
    fail "right click does not open pavucontrol"
pass "Waybar routes left and right audio clicks correctly"

cat > "$mock_bin/pactl" <<'EOF'
#!/bin/sh
set -eu

case "${1:-}" in
    info)
        printf 'Server Name: pulseaudio\n'
        ;;
    get-sink-volume)
        volume="$(sed -n 's/^volume=//p' "$BSDRUNNER_TEST_AUDIO_STATE")"
        printf 'Volume: front-left: 0 / %s%% / 0.00 dB, front-right: 0 / %s%% / 0.00 dB\n' "$volume" "$volume"
        ;;
    get-sink-mute)
        muted="$(sed -n 's/^muted=//p' "$BSDRUNNER_TEST_AUDIO_STATE")"
        printf 'Mute: %s\n' "$muted"
        ;;
    set-sink-volume)
        value="${3%%%}"
        muted="$(sed -n 's/^muted=//p' "$BSDRUNNER_TEST_AUDIO_STATE")"
        printf 'volume=%s\nmuted=%s\n' "$value" "$muted" > "$BSDRUNNER_TEST_AUDIO_STATE"
        ;;
    set-sink-mute)
        volume="$(sed -n 's/^volume=//p' "$BSDRUNNER_TEST_AUDIO_STATE")"
        muted="$(sed -n 's/^muted=//p' "$BSDRUNNER_TEST_AUDIO_STATE")"
        if [ "$muted" = "yes" ]; then muted=no; else muted=yes; fi
        printf 'volume=%s\nmuted=%s\n' "$volume" "$muted" > "$BSDRUNNER_TEST_AUDIO_STATE"
        ;;
    set-source-mute)
        [ "$2" = "@DEFAULT_SOURCE@" ] && [ "$3" = "toggle" ] || exit 2
        printf 'toggled\n' > "$BSDRUNNER_TEST_AUDIO_STATE.source"
        ;;
    *) exit 2 ;;
esac
EOF
chmod 755 "$mock_bin/pactl"

audio_env() {
    env \
        PATH="$mock_bin:/bin:/usr/bin" \
        BSDRUNNER_TEST_AUDIO_STATE="$audio_state" \
        BSDRUNNER_AUDIO_CACHE_DIR="$cache_dir" \
        "$@"
}

state_output="$(audio_env sh "$scripts_dir/bsdrunner-audio-state.sh")"
printf '%s\n' "$state_output" | grep -Fx 'volume=75' >/dev/null || fail "state helper did not read the master volume"
printf '%s\n' "$state_output" | grep -Fx 'muted=0' >/dev/null || fail "state helper reported the wrong mute state"
pass "audio state reads the PulseAudio master sink"

audio_env sh "$scripts_dir/bsdrunner-audio-set.sh" 42
grep -Fx 'volume=42' "$cache_dir/audio-state" >/dev/null || fail "volume setter did not refresh slider state"
grep -Fx 'muted=0' "$cache_dir/audio-state" >/dev/null || fail "volume setter changed mute state"
if audio_env sh "$scripts_dir/bsdrunner-audio-set.sh" invalid >/dev/null 2>&1; then
    fail "volume setter accepted an invalid value"
fi
pass "audio setter updates and validates the master volume"

audio_env sh "$scripts_dir/bsdrunner-audio-step.sh" up
grep -Fx 'volume=47' "$cache_dir/audio-state" >/dev/null || fail "volume up did not increase volume by five"
audio_env sh "$scripts_dir/bsdrunner-audio-step.sh" down
grep -Fx 'volume=42' "$cache_dir/audio-state" >/dev/null || fail "volume down did not decrease volume by five"
audio_env sh "$scripts_dir/bsdrunner-audio-set.sh" 99
audio_env sh "$scripts_dir/bsdrunner-audio-step.sh" up
grep -Fx 'volume=100' "$cache_dir/audio-state" >/dev/null || fail "volume up did not clamp at 100"
audio_env sh "$scripts_dir/bsdrunner-audio-set.sh" 2
audio_env sh "$scripts_dir/bsdrunner-audio-step.sh" down
grep -Fx 'volume=0' "$cache_dir/audio-state" >/dev/null || fail "volume down did not clamp at zero"
pass "volume keys adjust the master sink and respect its limits"

cat > "$mock_bin/mixer" <<'EOF'
#!/bin/sh
set -eu

case "${1:-}" in
    vol=*)
        value="${1#vol=}"
        percent="$(awk -v value="$value" 'BEGIN { printf "%d", (value * 100) + 0.5 }')"
        muted="$(sed -n 's/^muted=//p' "$BSDRUNNER_TEST_AUDIO_STATE")"
        printf 'volume=%s\nmuted=%s\n' "$percent" "$muted" > "$BSDRUNNER_TEST_AUDIO_STATE"
        ;;
    *) exit 2 ;;
esac
EOF
chmod 755 "$mock_bin/mixer"

audio_env env BSDRUNNER_AUDIO_FORCE_OSS_MIXER=yes sh "$scripts_dir/bsdrunner-audio-set.sh" 73
grep -Fx 'volume=73' "$cache_dir/audio-state" >/dev/null || fail "FreeBSD OSS setter lost one percent"
grep -Fx 'muted=0' "$cache_dir/audio-state" >/dev/null || fail "FreeBSD OSS setter changed mute state"
pass "FreeBSD OSS setter preserves the requested integer percent"

audio_env sh "$scripts_dir/bsdrunner-audio-mute.sh"
grep -Fx 'volume=73' "$cache_dir/audio-state" >/dev/null || fail "mute toggle changed the volume"
grep -Fx 'muted=1' "$cache_dir/audio-state" >/dev/null || fail "mute toggle did not refresh slider state"
pass "audio mute toggles the master sink"

audio_env sh "$scripts_dir/bsdrunner-microphone-mute.sh"
grep -Fx 'toggled' "$audio_state.source" >/dev/null || fail "microphone mute did not target the default source"
grep -Fx 'muted=yes' "$audio_state" >/dev/null || fail "microphone mute changed the output mute state"
pass "microphone mute targets the default source, independently of output"

cat > "$mock_bin/mic-toggle" <<'MOCK'
#!/bin/sh
printf 'toggle\n' >> "$BSDRUNNER_TEST_AUDIO_STATE.events"
MOCK
chmod 755 "$mock_bin/mic-toggle"
printf '%s\n' \
    '!system=ACPI subsystem=IBM type=HKEY notify=0x1b' \
    '!system=ACPI subsystem=IBM type=HKEY notify=0x1c' \
    '!system=ACPI subsystem=OTHER type=HKEY notify=0x1b' \
    '!system=OTHER subsystem=IBM type=HKEY notify=0x1b' | \
    audio_env env BSDRUNNER_MIC_MUTE_SCRIPT="$mock_bin/mic-toggle" \
        sh "$scripts_dir/bsdrunner-thinkpad-mic-watch.sh" --events
[ "$(wc -l < "$audio_state.events" | tr -d ' ')" = 1 ] || fail "ThinkPad watcher matched the wrong ACPI events"
pass "ThinkPad microphone watcher filters the observed ACPI event"

printf 'All audio tests passed.\n'
