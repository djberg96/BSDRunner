#!/bin/sh

set -eu

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
helper="$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-power-action.sh"
backend="$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-shutdown-backend.sh"
layout="$repo_root/dotfiles/.config/wlogout/layout"
prompt="$repo_root/dotfiles/.config/quickshell/bsdrunner-shutdown/shell.qml"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/bsdrunner-power-action-tests.XXXXXX")"
command_log="$test_root/commands.log"
client_state="$test_root/clients.json"
background_state="$test_root/background.state"

cleanup() { rm -rf -- "$test_root"; }
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

fail() { printf 'not ok - %s\n' "$1" >&2; exit 1; }
pass() { printf 'ok - %s\n' "$1"; }

printf '%s\n' \
    '#!/bin/sh' \
    'printf "backend %s\n" "$*" >>"$BSDRUNNER_POWER_TEST_LOG"' \
    >"$test_root/backend"
printf '%s\n' \
    '#!/bin/sh' \
    'printf "qs action=%s %s\n" "$BSDRUNNER_POWER_ACTION" "$*" >>"$BSDRUNNER_POWER_TEST_LOG"' \
    >"$test_root/qs"
printf '%s\n' \
    '#!/bin/sh' \
    'printf "pkill %s\n" "$*" >>"$BSDRUNNER_POWER_TEST_LOG"' \
    >"$test_root/pkill"
printf '%s\n' \
    '#!/bin/sh' \
    'if [ "$1" = -j ] && [ "$2" = clients ]; then' \
    '    cat "$BSDRUNNER_POWER_TEST_CLIENTS"' \
    'elif [ "$1" = dispatch ] && [ "$2" = closewindow ]; then' \
    '    printf "hyprctl %s\n" "$*" >>"$BSDRUNNER_POWER_TEST_LOG"' \
    'else' \
    '    exit 1' \
    'fi' \
    >"$test_root/hyprctl"
printf '%s\n' \
    '#!/bin/sh' \
    'if [ -f "$BSDRUNNER_POWER_TEST_BACKGROUND" ]; then printf "400\n401\n"; fi' \
    >"$test_root/pgrep"
printf '%s\n' \
    '#!/bin/sh' \
    'printf "kill %s\n" "$*" >>"$BSDRUNNER_POWER_TEST_LOG"' \
    'case "$*" in "-TERM 400 401") rm -f "$BSDRUNNER_POWER_TEST_BACKGROUND" ;; esac' \
    >"$test_root/kill"
printf '%s\n' \
    '#!/bin/sh' \
    'printf "sleep %s\n" "$*" >>"$BSDRUNNER_POWER_TEST_LOG"' \
    >"$test_root/sleep"
printf '%s\n' \
    '#!/bin/sh' \
    'printf "mdo %s\n" "$*" >>"$BSDRUNNER_POWER_TEST_LOG"' \
    >"$test_root/mdo"

chmod 755 "$test_root/backend" "$test_root/qs" "$test_root/pkill" \
    "$test_root/hyprctl" "$test_root/pgrep" "$test_root/kill" \
    "$test_root/sleep" "$test_root/mdo"

run_helper() {
    : >"$command_log"
    BSDRUNNER_POWER_BACKEND="$test_root/backend" \
    BSDRUNNER_POWER_QS="$test_root/qs" \
    BSDRUNNER_POWER_PKILL="$test_root/pkill" \
    BSDRUNNER_POWER_TEST_LOG="$command_log" \
        sh "$helper" "$1" >/dev/null
}

run_helper reboot
grep -Fx 'pkill wlogout' "$command_log" >/dev/null || fail "launcher was not dismissed"
grep -Fx 'backend begin reboot' "$command_log" >/dev/null || fail "apps were not asked to close"
grep -Fx 'qs action=reboot -c bsdrunner-shutdown' "$command_log" >/dev/null || fail "handoff window did not open"
pkill_line="$(grep -n '^pkill ' "$command_log" | cut -d: -f1)"
backend_line="$(grep -n '^backend ' "$command_log" | cut -d: -f1)"
prompt_line="$(grep -n '^qs ' "$command_log" | cut -d: -f1)"
[ "$pkill_line" -lt "$backend_line" ] && [ "$backend_line" -lt "$prompt_line" ] || fail "handoff steps ran out of order"
pass "reboot leaves the desktop usable while opening the handoff window"

run_helper shutdown
grep -Fx 'backend begin shutdown' "$command_log" >/dev/null || fail "shutdown did not ask apps to close"
grep -Fx 'qs action=shutdown -c bsdrunner-shutdown' "$command_log" >/dev/null || fail "shutdown action was not passed to the prompt"
pass "shutdown uses the same interactive handoff"

if BSDRUNNER_POWER_BACKEND="$test_root/missing" BSDRUNNER_POWER_QS="$test_root/qs" sh "$helper" reboot >/dev/null 2>&1; then
    fail "power action continued without its backend"
fi
pass "power actions fail safely when the backend is unavailable"

if sh "$helper" invalid >/dev/null 2>&1; then fail "invalid power action was accepted"; fi
pass "invalid power actions are rejected"

cat >"$client_state" <<'JSON'
[
  {"address":"0x1","class":"firefox","title":"Unsaved form — Mozilla Firefox","pid":101,"mapped":true},
  {"address":"0x2","class":"code-oss","title":"BSDRunner - Code - OSS","pid":202,"mapped":true},
  {"address":"0x3","class":"quickshell","title":"BSDRunner — Restart BSDRunner","pid":303,"mapped":true},
  {"address":"0x4","class":"wlogout","title":"wlogout","pid":404,"mapped":true},
  {"address":"0x5","class":"kitty","title":"hidden","pid":505,"mapped":false}
]
JSON

run_backend() {
    BSDRUNNER_POWER_HYPRCTL="$test_root/hyprctl" \
    BSDRUNNER_POWER_JQ="$(command -v jq)" \
    BSDRUNNER_POWER_PGREP="$test_root/pgrep" \
    BSDRUNNER_POWER_KILL="$test_root/kill" \
    BSDRUNNER_POWER_SLEEP="$test_root/sleep" \
    BSDRUNNER_POWER_MDO="$test_root/mdo" \
    BSDRUNNER_POWER_DOAS="$test_root/missing-doas" \
    BSDRUNNER_POWER_SHUTDOWN=shutdown \
    BSDRUNNER_POWER_TEST_LOG="$command_log" \
    BSDRUNNER_POWER_TEST_CLIENTS="$client_state" \
    BSDRUNNER_POWER_TEST_BACKGROUND="$background_state" \
        sh "$backend" "$@"
}

: >"$command_log"
run_backend begin reboot
grep -Fx 'hyprctl dispatch closewindow address:0x1' "$command_log" >/dev/null || fail "Firefox missed graceful close"
grep -Fx 'hyprctl dispatch closewindow address:0x2' "$command_log" >/dev/null || fail "Code missed graceful close"
if grep -Eq 'address:0x(3|4|5)$' "$command_log"; then fail "non-app window was closed"; fi
pass "graceful close targets real application windows only"

snapshot="$(run_backend snapshot)"
[ "$(printf '%s' "$snapshot" | jq -r '.count')" = 2 ] || fail "snapshot included non-app windows"
[ "$(printf '%s' "$snapshot" | jq -r '.apps[0].class')" = firefox ] || fail "snapshot omitted app metadata"
pass "status snapshot excludes the prompt and launcher"

: >"$command_log"
run_backend force reboot
for expected in 'kill -TERM 101' 'kill -TERM 202' 'kill -KILL 101' 'kill -KILL 202'; do
    grep -Fx "$expected" "$command_log" >/dev/null || fail "explicit force close missed: $expected"
done
pass "force close escalates only after an explicit request"

: >"$background_state"
: >"$command_log"
run_backend commit reboot
grep -Fx 'kill -TERM 400 401' "$command_log" >/dev/null || fail "background services were not stopped"
grep -Fx 'mdo shutdown -r now' "$command_log" >/dev/null || fail "restart command was not reached"
pass "restart cleans session infrastructure after applications"

: >"$background_state"
: >"$command_log"
run_backend commit shutdown
grep -Fx 'mdo shutdown -p now' "$command_log" >/dev/null || fail "poweroff command was not reached"
pass "shutdown requests FreeBSD poweroff"

grep -F 'bsdrunner-power-action.sh reboot' "$layout" >/dev/null || fail "wlogout reboot bypasses helper"
grep -F 'bsdrunner-power-action.sh shutdown' "$layout" >/dev/null || fail "wlogout shutdown bypasses helper"
grep -F 'FloatingWindow {' "$prompt" >/dev/null || fail "prompt is not an ordinary window"
if grep -F 'PanelWindow {' "$prompt" >/dev/null; then fail "prompt still uses a layer window"; fi
pass "power menu delegates to a non-blocking BSDRunner prompt"

printf '%s\n' 'All power action tests passed.'
