#!/bin/sh

set -eu

repo_root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
launcher="$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-start-waybar.sh"
cpu_summary="$repo_root/dotfiles/.config/waybar/scripts/bsdrunner-cpu-summary.sh"
waybar_config="$repo_root/dotfiles/.config/waybar/config"
waybar_style="$repo_root/dotfiles/.config/waybar/style.css"
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

cpu_output="$(
    BSDRUNNER_CPU_VMSTAT_JSON='{"vmstat":{"cpu":[{"name":0,"idle":70},{"name":1,"idle":50}]}}' \
    BSDRUNNER_CPU_TEMPERATURES='48.2
52.7' \
        sh "$cpu_summary"
)"
printf '%s\n' "$cpu_output" | grep -Fq '"text":" 40%"' || fail "CPU panel should show one overall percentage"
printf '%s\n' "$cpu_output" | grep -Fq 'Core 1: 30%\nCore 2: 50%' || fail "CPU tooltip should show per-core usage"
printf '%s\n' "$cpu_output" | grep -Fq '52.7°C' || fail "CPU summary should show the hottest sensor"
if printf '%s\n' "$cpu_output" | grep -Fq '"text":" 40% 52.7°C'; then
    fail "CPU temperature should only appear in the tooltip"
fi
if printf '%s\n' "$cpu_output" | grep -Fq 'Cool: under'; then
    fail "CPU tooltip should not repeat the temperature key"
fi
printf '%s\n' "$cpu_output" | grep -Fq '"class":"cool"' || fail "temperatures below 70°C should be cool"

warm_output="$(
    BSDRUNNER_CPU_VMSTAT_JSON='{"vmstat":{"cpu":[{"name":0,"idle":70},{"name":1,"idle":50}]}}' \
    BSDRUNNER_CPU_TEMPERATURES='70' \
        sh "$cpu_summary"
)"
printf '%s\n' "$warm_output" | grep -Fq '"class":"warm"' || fail "70°C should be warm"

hot_output="$(
    BSDRUNNER_CPU_VMSTAT_JSON='{"vmstat":{"cpu":[{"name":0,"idle":70},{"name":1,"idle":50}]}}' \
    BSDRUNNER_CPU_TEMPERATURES='85' \
        sh "$cpu_summary"
)"
printf '%s\n' "$hot_output" | grep -Fq '"class":"hot"' || fail "85°C should be hot"

grep -Fq '"custom/cpu"' "$waybar_config" || fail "Waybar should use the combined CPU summary"
grep -Fq '#custom-cpu.cool' "$waybar_style" || fail "CPU temperature states should have colors"
printf 'ok - CPU usage and temperature summary is classified correctly\n'

printf 'All Waybar launcher tests passed.\n'
