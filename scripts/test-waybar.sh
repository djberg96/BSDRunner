#!/bin/sh

set -eu

repo_root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
launcher="$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-start-waybar.sh"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/bsdrunner-waybar-tests.XXXXXX")"
processes="$test_root/processes.txt"

cleanup() {
    rm -rf "$test_root"
}
trap cleanup EXIT HUP INT TERM

fail() {
    printf 'not ok - %s\n' "$1" >&2
    exit 1
}

check_running() {
    BSDRUNNER_WAYBAR_CHECK_ONLY=yes \
    BSDRUNNER_WAYBAR_PS_FILE="$processes" \
        sh "$launcher"
}

printf 'Z  waybar\n' >"$processes"
if check_running; then
    fail "a zombie Waybar must not count as running"
fi
printf 'ok - zombie Waybar is rejected\n'

printf 'S  waybar\n' >"$processes"
check_running || fail "a sleeping Waybar should count as running"
printf 'ok - live Waybar is accepted\n'

printf 'S  swaybg\n' >"$processes"
if check_running; then
    fail "an unrelated process must not count as Waybar"
fi
printf 'ok - unrelated processes are rejected\n'

grep -Fq 'daemon -f -o "$waybar_log"' "$launcher" || fail "Waybar should use FreeBSD daemon startup"
grep -Fq 'discover_session_bus' "$launcher" || fail "Waybar should recover a stale inherited D-Bus address"
if grep -Fq 'pgrep -x waybar' "$launcher"; then
    fail "Waybar health checks must not use zombie-blind pgrep"
fi
printf 'ok - launcher uses detached zombie-safe startup\n'

printf 'All Waybar launcher tests passed.\n'
