#!/bin/sh

set -eu

repo_root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
backend="$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-jails-backend.sh"
demo_fixture="$repo_root/dotfiles/.config/bsdrunner/jails/demo-snapshot.json"
fixtures="$repo_root/tests/fixtures/jails"
fixture_path="$fixtures/bin:/usr/bin:/bin"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/bsdrunner-jails-tests.XXXXXX")"
state_dir="$test_root/state"
command_log="$test_root/commands.log"

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

assert_json() {
    file="$1"
    filter="$2"
    description="$3"
    jq -e "$filter" "$file" >/dev/null || fail "$description"
}

run_backend() {
    BSDRUNNER_JAILS_TEST_MODE=1 \
    BSDRUNNER_JAILS_TEST_PATH="$fixture_path" \
    BSDRUNNER_JAILS_TEST_ETC_DIR="$fixtures/etc" \
    BSDRUNNER_JAILS_TEST_STATE_DIR="$state_dir" \
    BSDRUNNER_JAILS_TEST_FIXTURES="$fixtures" \
    BSDRUNNER_JAILS_TEST_LOG="$command_log" \
    sh "$backend" "$@"
}

command -v jq >/dev/null 2>&1 || fail "jq is required to run the Jails backend tests"

demo_output="$test_root/demo.json"
BSDRUNNER_JAILS_FIXTURE="$demo_fixture"
export BSDRUNNER_JAILS_FIXTURE
run_backend snapshot >"$demo_output"
assert_json "$demo_output" \
    '.ok == true and .message == "Loaded Jails demo data." and (.running | length) == 1 and (.configured | length) == 1 and (.bastille | length) == 1' \
    "demo fixture should satisfy the snapshot contract"
pass "demo fixture satisfies the snapshot contract"

: >"$command_log"
demo_preview_output="$test_root/demo-preview.json"
run_backend preview demo-web 15.0-RELEASE 10.0.0.40/24 no >"$demo_preview_output"
assert_json "$demo_preview_output" \
    '.ok == true and .mutates == false and .backend == "bastille" and .ready == true and .checks.release_bootstrapped == true and .commands == ["bastille create --thick --no-boot demo-web 15.0-RELEASE 10.0.0.40/24"]' \
    "demo mode should allow a read-only create preview"
[ ! -s "$command_log" ] || fail "create preview should not execute fixture commands"
pass "demo mode allows the read-only create preview"

demo_action_output="$test_root/demo-action.json"
if run_backend start web native >"$demo_action_output"; then
    fail "demo mode should reject lifecycle actions"
fi
assert_json "$demo_action_output" \
    '.ok == false and .message == "Actions are disabled in demo mode."' \
    "demo mode should explain why lifecycle actions are disabled"
pass "demo mode rejects lifecycle actions"

BSDRUNNER_JAILS_FIXTURE="$test_root/missing-demo.json"
missing_demo_output="$test_root/missing-demo-output.json"
if run_backend snapshot >"$missing_demo_output"; then
    fail "a missing demo fixture should fail safely"
fi
assert_json "$missing_demo_output" \
    '.ok == false and .message == "Unable to load Jails demo data."' \
    "a missing demo fixture should return a structured error"
pass "missing demo data fails safely"
unset BSDRUNNER_JAILS_FIXTURE

snapshot_output="$test_root/snapshot.json"
run_backend snapshot >"$snapshot_output"
assert_json "$snapshot_output" \
    '.ok == true and .tools == {"jls":true,"jail":true,"service":true,"bastille":true,"mdo":true}' \
    "snapshot should report fixture-backed tools"
assert_json "$snapshot_output" \
    '.services == {"jail":"YES","bastille":"NO"}' \
    "snapshot should report fixture-backed service settings"
assert_json "$snapshot_output" \
    '.host_release == "15.0-RELEASE" and .bastille_setup == true and .bastille_releases == ["14.3-RELEASE","15.0-RELEASE"]' \
    "snapshot should report host and Bastille release readiness"
assert_json "$snapshot_output" \
    '(.running | length) == 2 and .running[0].name == "api" and .running[1].ipv6 == "none"' \
    "snapshot should parse jls output"
assert_json "$snapshot_output" \
    '(.configured | length) == 3 and ([.configured[].name] | sort) == ["api","metrics","worker"]' \
    "snapshot should parse jail.conf fixtures"
assert_json "$snapshot_output" \
    '(.bastille | length) == 2 and .bastille[0].state == "running" and .bastille[0].release == "15.0-RELEASE" and .bastille[0].autostart == "YES" and .bastille[1].state == "stopped" and .bastille[1].release == "14.3-RELEASE" and .bastille[1].autostart == "NO"' \
    "snapshot should parse rich Bastille metadata"
pass "snapshot parses native and Bastille fixtures"

: >"$command_log"
preview_output="$test_root/preview.json"
run_backend preview web 15.0-RELEASE 10.0.0.20/24 yes >"$preview_output"
assert_json "$preview_output" \
    '.ok == true and .mutates == false and .ready == true and .inputs == {"name":"web","release":"15.0-RELEASE","address":"10.0.0.20/24","autostart":"yes","jail_type":"thick"} and .checks == {"bastille_installed":true,"bastille_setup":true,"release_bootstrapped":true,"name_available":true,"address_available":true,"host_release":"15.0-RELEASE","host_compatible":true} and .commands == ["bastille create --thick web 15.0-RELEASE 10.0.0.20/24"]' \
    "create preview should return an exact non-mutating Bastille plan"
[ ! -s "$command_log" ] || fail "create preview should not execute Bastille"

bootstrap_preview_output="$test_root/bootstrap-preview.json"
run_backend preview web 14.4-RELEASE 10.0.0.20/24 no >"$bootstrap_preview_output"
assert_json "$bootstrap_preview_output" \
    '.ready == true and .checks.release_bootstrapped == false and .checks.host_compatible == true and .commands == ["bastille bootstrap --update 14.4-RELEASE","bastille create --thick --no-boot web 14.4-RELEASE 10.0.0.20/24"]' \
    "create preview should bootstrap a missing compatible release"

collision_preview_output="$test_root/collision-preview.json"
run_backend preview cache 15.0-RELEASE 10.0.0.10/24 yes >"$collision_preview_output"
assert_json "$collision_preview_output" \
    '.ok == true and .ready == false and .checks.name_available == false and .checks.address_available == false and .message == "Create preview needs attention. Nothing was changed."' \
    "create preview should report name and address collisions"

newer_preview_output="$test_root/newer-preview.json"
run_backend preview future 16.0-RELEASE 10.0.0.30/24 yes >"$newer_preview_output"
assert_json "$newer_preview_output" \
    '.ok == true and .ready == false and .checks.host_release == "15.0-RELEASE" and .checks.host_compatible == false' \
    "create preview should flag a jail release newer than the host"
[ ! -s "$command_log" ] || fail "host-aware previews should remain read-only"

invalid_preview_output="$test_root/invalid-preview.json"
if run_backend preview 'bad name' 15.0-RELEASE 10.0.0.20 yes >"$invalid_preview_output"; then
    fail "create preview should reject invalid jail names"
fi
assert_json "$invalid_preview_output" \
    '.ok == false and .message == "Invalid jail name."' \
    "create preview should return structured validation errors"
if run_backend preview web 15.0-RELEASE '10.0.0.20;reboot' yes >"$invalid_preview_output"; then
    fail "create preview should reject unsafe addresses"
fi
assert_json "$invalid_preview_output" \
    '.ok == false and .message == "Invalid jail address."' \
    "create preview should reject unsafe address characters"
pass "create preview is exact, read-only, and validated"

empty_bin="$test_root/empty-bin"
mkdir -p "$empty_bin"
for utility in awk cat date mkdir; do
    ln -s "$(command -v "$utility")" "$empty_bin/$utility"
done
missing_tools_output="$test_root/missing-tools.json"
BSDRUNNER_JAILS_TEST_MODE=1 \
BSDRUNNER_JAILS_TEST_PATH="$empty_bin" \
BSDRUNNER_JAILS_TEST_ETC_DIR="$fixtures/etc" \
BSDRUNNER_JAILS_TEST_STATE_DIR="$state_dir" \
sh "$backend" snapshot >"$missing_tools_output"
assert_json "$missing_tools_output" \
    '.ok == true and .tools == {"jls":false,"jail":false,"service":false,"bastille":false,"mdo":false} and .running == [] and .bastille == [] and (.configured | length) == 3' \
    "snapshot should remain useful when jail commands are unavailable"
pass "missing host tools produce a valid read-only snapshot"

: >"$command_log"
native_action_output="$test_root/native-action.json"
run_backend start api native >"$native_action_output"
assert_json "$native_action_output" \
    '.ok == true and .message == "start api." and .details == "Native jail action completed."' \
    "native lifecycle action should return command output"
grep -Fx 'mdo service jail start api' "$command_log" >/dev/null || fail "native lifecycle action should use mdo"
grep -Fx 'service jail start api' "$command_log" >/dev/null || fail "native lifecycle action should call service(8)"
pass "native lifecycle action uses the guarded command path"

: >"$command_log"
bastille_action_output="$test_root/bastille-action.json"
run_backend restart cache bastille >"$bastille_action_output"
assert_json "$bastille_action_output" \
    '.ok == true and .message == "restart cache." and .details == "Bastille action completed."' \
    "Bastille lifecycle action should return command output"
grep -Fx 'mdo bastille restart cache' "$command_log" >/dev/null || fail "Bastille lifecycle action should use mdo"
grep -Fx 'bastille restart cache' "$command_log" >/dev/null || fail "Bastille lifecycle action should call Bastille"
pass "Bastille lifecycle action uses the guarded command path"

invalid_output="$test_root/invalid.json"
if run_backend stop 'bad name' native >"$invalid_output"; then
    fail "invalid jail names should be rejected"
fi
assert_json "$invalid_output" \
    '.ok == false and .message == "Invalid jail name."' \
    "invalid jail names should return structured errors"

if run_backend stop api unsupported >"$invalid_output"; then
    fail "unknown jail backends should be rejected"
fi
assert_json "$invalid_output" \
    '.ok == false and .message == "Unknown jail backend."' \
    "unknown jail backends should return structured errors"
pass "invalid names and backends are rejected"

missing_console_output="$test_root/missing-console.json"
if run_backend console api native >"$missing_console_output"; then
    fail "native console should require jexec(8)"
fi
assert_json "$missing_console_output" \
    '.ok == false and .message == "The jexec command is unavailable."' \
    "missing jexec should return a structured error"
pass "missing console dependencies fail safely"

refreshed_snapshot="$test_root/refreshed-snapshot.json"
run_backend snapshot >"$refreshed_snapshot"
assert_json "$refreshed_snapshot" \
    '.message == "restart cache." and .last_result.tone == "success" and .last_result.message == "restart cache." and (.last_result.timestamp | length) > 0' \
    "successful actions should persist the last result"
pass "successful actions persist status for the next snapshot"

printf 'All Jails backend tests passed.\n'
