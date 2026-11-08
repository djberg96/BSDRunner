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
    "$scripts_dir/bsdrunner-audio-mute.sh" \
    "$audio_qml"; do
    [ -f "$required" ] || fail "missing audio component: $required"
done
pass "audio slider components are present"

grep -Fq 'property bool dragging: false' "$audio_qml" || fail "slider does not guard state refreshes while dragging"
grep -Fq 'property bool applyInFlight: false' "$audio_qml" || fail "slider does not guard state refreshes while applying"
grep -Fq 'Slider {' "$audio_qml" || fail "audio panel does not use the native Qt slider"
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

audio_env sh "$scripts_dir/bsdrunner-audio-mute.sh"
grep -Fx 'volume=42' "$cache_dir/audio-state" >/dev/null || fail "mute toggle changed the volume"
grep -Fx 'muted=1' "$cache_dir/audio-state" >/dev/null || fail "mute toggle did not refresh slider state"
pass "audio mute toggles the master sink"

printf 'All audio tests passed.\n'
