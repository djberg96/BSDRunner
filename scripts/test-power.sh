#!/bin/sh

set -eu

repo_root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
backend="$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-power-backend.sh"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/bsdrunner-power-tests.XXXXXX")"
profile_file="$test_root/profile.conf"
idle_config="$test_root/hypridle.conf"

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

run_backend() {
    BSDRUNNER_POWER_PROFILE_FILE="$profile_file" \
    BSDRUNNER_HYPRIDLE_CONFIG="$idle_config" \
    BSDRUNNER_LOCK_SCRIPT="$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-lock.sh" \
    BSDRUNNER_POWER_SKIP_RESTART=yes \
    sh "$backend" "$@"
}

default_output="$test_root/default.json"
run_backend apply >"$default_output"
jq -e '.ok == true and .enabled == true and .timeout_minutes == 15' "$default_output" >/dev/null || fail "default profile should enable a 15-minute lock"
grep -Fx 'lock_enabled=yes' "$profile_file" >/dev/null || fail "default enabled state should persist"
grep -Fx 'lock_timeout_minutes=15' "$profile_file" >/dev/null || fail "default timeout should persist"
grep -Fx '    timeout = 900' "$idle_config" >/dev/null || fail "default timeout should render as 900 seconds"
grep -Fx '    ignore_systemd_inhibit = true' "$idle_config" >/dev/null || fail "FreeBSD config should not query systemd inhibitors"
grep -Fx '    ignore_wayland_inhibit = false' "$idle_config" >/dev/null || fail "Wayland idle inhibitors should remain enabled"
pass "power backend renders the enabled 15-minute default"

timeout_output="$test_root/timeout.json"
run_backend set-timeout 30 >"$timeout_output"
jq -e '.ok == true and .timeout_minutes == 30' "$timeout_output" >/dev/null || fail "custom timeout should be reported"
grep -Fx 'lock_timeout_minutes=30' "$profile_file" >/dev/null || fail "custom timeout should persist"
grep -Fx '    timeout = 1800' "$idle_config" >/dev/null || fail "custom timeout should render in seconds"
pass "power backend persists and renders a custom timeout"

for invalid_timeout in 0 121 invalid; do
    invalid_output="$test_root/invalid-$invalid_timeout.json"
    if run_backend set-timeout "$invalid_timeout" >"$invalid_output"; then
        fail "invalid timeout $invalid_timeout should be rejected"
    fi
    jq -e '.ok == false' "$invalid_output" >/dev/null || fail "invalid timeout should return structured failure"
done
grep -Fx 'lock_timeout_minutes=30' "$profile_file" >/dev/null || fail "invalid timeout should not replace the saved value"
pass "power backend rejects timeout values outside 1 through 120"

disabled_output="$test_root/disabled.json"
run_backend set-enabled no >"$disabled_output"
jq -e '.ok == true and .enabled == false' "$disabled_output" >/dev/null || fail "disabled state should be reported"
grep -Fx 'lock_enabled=no' "$profile_file" >/dev/null || fail "disabled state should persist"
pass "power backend can disable automatic locking"

grep -Fq 'bsdrunner-start-idle.sh' "$repo_root/dotfiles/.config/hypr/hyprland.lua" || fail "Lua session should autostart idle management"
grep -Fq 'bsdrunner-start-idle.sh' "$repo_root/dotfiles/.config/hypr/conf/autostart.conf" || fail "legacy session should autostart idle management"
grep -Fq 'bsdrunner-lock.sh' "$repo_root/dotfiles/.config/wlogout/layout" || fail "power menu should use the guarded lock helper"
pass "desktop entry points use the managed idle and lock helpers"

for process_script in "$backend" "$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-start-idle.sh"; do
    grep -Fq '$1 !~ /^Z/ && $2 == "hypridle"' "$process_script" || fail "idle health checks should ignore zombie processes"
    if grep -Fq 'pgrep -x hypridle' "$process_script"; then
        fail "idle health checks should not treat zombie pgrep results as active"
    fi
done
pass "idle health checks reject stale FreeBSD zombie processes"

grep -Fq 'daemon -f -o "$idle_log" hypridle' "$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-start-idle.sh" || fail "FreeBSD idle daemon should detach from the settings window"
pass "idle daemon uses FreeBSD session-independent startup"

power_launcher="$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-power.sh"
grep -Fq '$1 !~ /^Z/' "$power_launcher" || fail "power launcher should ignore zombie Quickshell processes"
grep -Fq 'daemon -f -o /tmp/bsdrunner-power-window.log qs -c bsdrunner-power' "$power_launcher" || fail "power panel should detach from short-lived launchers"
pass "power panel launcher handles zombies and short-lived callers"

lock_helper="$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-lock.sh"
grep -Fq '$1 !~ /^Z/ && $2 == "hyprlock"' "$lock_helper" || fail "lock helper should ignore zombie processes"
if grep -Fq 'pgrep -x hyprlock' "$lock_helper"; then
    fail "lock helper should not treat zombie pgrep results as an active lock"
fi
pass "lock health check rejects stale FreeBSD zombie processes"

printf 'All power settings tests passed.\n'
