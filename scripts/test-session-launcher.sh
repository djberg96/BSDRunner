#!/bin/sh

set -eu

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
launcher="$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-launch-hyprland.sh"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/bsdrunner-session-launcher-tests.XXXXXX")"
test_bin="$test_root/bin"
runtime_dir="$test_root/runtime"
launch_log="$test_root/launch.log"

cleanup() {
    rm -rf -- "$test_root"
}
trap cleanup EXIT HUP INT TERM

fail() {
    printf 'not ok - %s\n' "$1" >&2
    exit 1
}

assert_line() {
    grep -Fx "$1" "$launch_log" >/dev/null || fail "$2"
}

mkdir -p "$test_bin" "$runtime_dir"
chmod 700 "$runtime_dir"

cat >"$test_bin/dbus-run-session" <<'EOF'
#!/bin/sh
printf 'dbus inherited: %s\n' "${DBUS_SESSION_BUS_ADDRESS-unset}" >>"$BSDRUNNER_LAUNCH_TEST_LOG"
[ "${1:-}" != "--" ] || shift
export DBUS_SESSION_BUS_ADDRESS="unix:path=/tmp/bsdrunner-test-bus"
exec "$@"
EOF

cat >"$test_bin/start-hyprland" <<'EOF'
#!/bin/sh
printf 'command: start-hyprland' >>"$BSDRUNNER_LAUNCH_TEST_LOG"
for argument in "$@"; do
    printf ' <%s>' "$argument" >>"$BSDRUNNER_LAUNCH_TEST_LOG"
done
printf '\naddress: %s\n' "${DBUS_SESSION_BUS_ADDRESS-unset}" >>"$BSDRUNNER_LAUNCH_TEST_LOG"
printf 'desktop: %s/%s/%s\n' \
    "${XDG_SESSION_TYPE-unset}" \
    "${XDG_CURRENT_DESKTOP-unset}" \
    "${XDG_SESSION_DESKTOP-unset}" >>"$BSDRUNNER_LAUNCH_TEST_LOG"
EOF

cat >"$test_bin/Hyprland" <<'EOF'
#!/bin/sh
printf 'command: Hyprland' >>"$BSDRUNNER_LAUNCH_TEST_LOG"
for argument in "$@"; do
    printf ' <%s>' "$argument" >>"$BSDRUNNER_LAUNCH_TEST_LOG"
done
printf '\naddress: %s\n' "${DBUS_SESSION_BUS_ADDRESS-unset}" >>"$BSDRUNNER_LAUNCH_TEST_LOG"
EOF

chmod 755 "$test_bin/dbus-run-session" "$test_bin/start-hyprland" "$test_bin/Hyprland"

PATH="$test_bin:/bin:/usr/bin" \
XDG_RUNTIME_DIR="$runtime_dir" \
DBUS_SESSION_BUS_ADDRESS="unix:path=/tmp/stale-bus" \
BSDRUNNER_LAUNCH_TEST_LOG="$launch_log" \
    sh "$launcher" "/tmp/terminal config.lua"

assert_line 'dbus inherited: unset' "the launcher should discard a stale inherited bus"
assert_line 'command: start-hyprland <--> <--config> </tmp/terminal config.lua>' \
    "the launcher should wrap start-hyprland and preserve its config arguments"
assert_line 'address: unix:path=/tmp/bsdrunner-test-bus' \
    "Hyprland should inherit the new desktop session bus"
assert_line 'desktop: wayland/Hyprland/Hyprland' \
    "the launcher should identify the Wayland desktop session"
printf '%s\n' 'ok - start-hyprland owns one fresh desktop D-Bus session'

rm -f "$test_bin/start-hyprland"
: >"$launch_log"

PATH="$test_bin:/bin:/usr/bin" \
XDG_RUNTIME_DIR="$runtime_dir" \
BSDRUNNER_LAUNCH_TEST_LOG="$launch_log" \
    sh "$launcher"

assert_line 'dbus inherited: unset' "the direct Hyprland path should start with a fresh bus"
assert_line 'command: Hyprland' "the launcher should fall back to Hyprland"
assert_line 'address: unix:path=/tmp/bsdrunner-test-bus' \
    "direct Hyprland should inherit the new desktop session bus"
printf '%s\n' 'ok - direct Hyprland fallback owns the same kind of D-Bus session'

rm -f "$test_bin/dbus-run-session"
: >"$launch_log"

PATH="$test_bin:/bin:/usr/bin" \
XDG_RUNTIME_DIR="$runtime_dir" \
BSDRUNNER_LAUNCH_TEST_LOG="$launch_log" \
    sh "$launcher" "/tmp/fallback.lua"

assert_line 'command: Hyprland <--config> </tmp/fallback.lua>' \
    "Hyprland should remain launchable when dbus-run-session is unavailable"
assert_line 'address: unset' "the no-D-Bus fallback should not retain a stale address"
printf '%s\n' 'ok - desktop remains launchable without dbus-run-session'

printf '%s\n' 'All desktop session launcher tests passed.'
