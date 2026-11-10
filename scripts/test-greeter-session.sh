#!/bin/sh

set -eu

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
session_helper="$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-greeter-session.sh"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/bsdrunner-session-tests.XXXXXX")"
test_home="$test_root/home"
state_home="$test_root/state"
launcher="$test_home/.config/bsdrunner/scripts/bsdrunner-launch-hyprland.sh"

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

mkdir -p "$(dirname -- "$launcher")" "$state_home"
printf '%s\n' \
    '#!/bin/sh' \
    'printf "stdout: %s\n" "$BSDRUNNER_SESSION_TEST_MESSAGE"' \
    'printf "stderr: %s\n" "$BSDRUNNER_SESSION_TEST_MESSAGE" >&2' \
    >"$launcher"
chmod 755 "$launcher"

visible_output="$test_root/visible.log"
HOME="$test_home" \
XDG_STATE_HOME="$state_home" \
BSDRUNNER_SESSION_TEST_MESSAGE=first \
    sh "$session_helper" BSDRunner >"$visible_output" 2>&1

[ ! -s "$visible_output" ] || fail "compositor output leaked to the login VT"
grep -Fx 'stdout: first' "$state_home/bsdrunner/session.log" >/dev/null || \
    fail "session stdout was not logged"
grep -Fx 'stderr: first' "$state_home/bsdrunner/session.log" >/dev/null || \
    fail "session stderr was not logged"

HOME="$test_home" \
XDG_STATE_HOME="$state_home" \
BSDRUNNER_SESSION_TEST_MESSAGE=second \
    sh "$session_helper" BSDRunner >"$visible_output" 2>&1

grep -Fx 'stdout: second' "$state_home/bsdrunner/session.log" >/dev/null || \
    fail "the current session log was not refreshed"
grep -Fx 'stdout: first' "$state_home/bsdrunner/session.previous.log" >/dev/null || \
    fail "the previous session log was not retained"

mode="$(stat -f '%Lp' "$state_home/bsdrunner/session.log" 2>/dev/null || stat -c '%a' "$state_home/bsdrunner/session.log")"
[ "$mode" = 600 ] || fail "session log permissions are not private"

printf '%s\n' 'Greeter session logging tests passed.'
