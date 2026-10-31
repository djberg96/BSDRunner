#!/bin/sh

set -eu

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
helper="$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-logout.sh"
layout="$repo_root/dotfiles/.config/wlogout/layout"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/bsdrunner-logout-tests.XXXXXX")"

cleanup() {
    rm -rf -- "$test_root"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

fail() {
    printf 'not ok - %s\n' "$1" >&2
    exit 1
}

pass() {
    printf 'ok - %s\n' "$1"
}

fake_hyprctl="$test_root/hyprctl"
command_log="$test_root/command.log"
expected_log="$test_root/expected.log"

printf '%s\n' \
    '#!/bin/sh' \
    'printf "%s\n" "$@" > "$BSDRUNNER_LOGOUT_TEST_LOG"' \
    'exit "${BSDRUNNER_LOGOUT_TEST_STATUS:-0}"' \
    >"$fake_hyprctl"
chmod 755 "$fake_hyprctl"

BSDRUNNER_LOGOUT_HYPRCTL="$fake_hyprctl" \
BSDRUNNER_LOGOUT_TEST_LOG="$command_log" \
    sh "$helper"
printf '%s\n' 'dispatch' 'hl.dsp.exit()' >"$expected_log"
cmp -s "$expected_log" "$command_log" || \
    fail "logout did not request the current Hyprland session to exit"
pass "logout requests the current Hyprland session to exit"

set +e
BSDRUNNER_LOGOUT_HYPRCTL="$fake_hyprctl" \
BSDRUNNER_LOGOUT_TEST_LOG="$command_log" \
BSDRUNNER_LOGOUT_TEST_STATUS=23 \
    sh "$helper"
status="$?"
set -e
[ "$status" -eq 23 ] || fail "logout hid the hyprctl failure status"
pass "logout propagates hyprctl failures"

grep -F '"label" : "logout"' "$layout" >/dev/null || \
    fail "wlogout does not expose logout"
grep -F 'bsdrunner-logout.sh' "$layout" >/dev/null || \
    fail "wlogout bypasses the guarded logout helper"
if grep -E 'vidcontrol|chvt|service[[:space:]]+greetd' "$helper" "$layout" >/dev/null; then
    fail "logout attempts to manage the VT or greetd"
fi
if grep -E 'shutdown|doas|mdo' "$helper" >/dev/null; then
    fail "logout helper attempts to manage machine power or privileges"
fi
pass "wlogout delegates only session exit to the helper"

printf '%s\n' 'All logout tests passed.'
