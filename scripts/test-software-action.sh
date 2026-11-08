#!/bin/sh

set -eu

repo_root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
action_script="$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-software-action.sh"
software_qml="$repo_root/dotfiles/.config/quickshell/bsdrunner-software/shell.qml"
fixture_bin="$repo_root/tests/fixtures/software/bin"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/bsdrunner-software-action-tests.XXXXXX")"
command_log="$test_root/commands.log"
state_file="$test_root/installed.state"

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

run_action() {
    HOME="$test_root/home" \
    BSDRUNNER_SOFTWARE_TEST_PATH="$fixture_bin" \
    BSDRUNNER_SOFTWARE_TEST_COMMAND_LOG="$command_log" \
    BSDRUNNER_SOFTWARE_TEST_STATE="$state_file" \
    BSDRUNNER_SOFTWARE_TEST_PREVIEW="${BSDRUNNER_SOFTWARE_TEST_PREVIEW:-valid-nonzero}" \
    sh "$action_script" "$@"
}

mkdir -p "$test_root/home"
: >"$command_log"

valid_output="$test_root/valid-nonzero.json"
run_action install keybase >"$valid_output" || fail "a complete pkg plan with status 1 should continue to installation"
jq -e '.ok == true and .package == "keybase" and .message == "Installed keybase."' "$valid_output" >/dev/null || fail "valid nonzero preview should return structured success"
[ -f "$state_file" ] || fail "valid nonzero preview should execute the package action"
grep -Fx 'pkg install -y -- keybase' "$command_log" >/dev/null || fail "valid nonzero preview should reach the privileged install"
pass "software action accepts pkg 2.8.x valid dry-run status 1"

rm -f "$state_file"
: >"$command_log"
zero_output="$test_root/valid-zero.json"
BSDRUNNER_SOFTWARE_TEST_PREVIEW=valid-zero run_action install keybase >"$zero_output" || fail "a status 0 preview should continue to installation"
jq -e '.ok == true' "$zero_output" >/dev/null || fail "status 0 preview should still return success"
pass "software action preserves normal successful previews"

rm -f "$state_file"
: >"$command_log"
invalid_one_output="$test_root/invalid-one.json"
if BSDRUNNER_SOFTWARE_TEST_PREVIEW=invalid-one run_action install keybase >"$invalid_one_output"; then
    fail "status 1 without a complete plan should be rejected"
fi
jq -e '.ok == false and .message == "pkg could not plan install for keybase."' "$invalid_one_output" >/dev/null || fail "invalid status 1 preview should return a planning failure"
[ ! -s "$command_log" ] || fail "invalid status 1 preview should not invoke mdo"
pass "software action rejects status 1 when pkg did not emit a plan"

: >"$command_log"
invalid_other_output="$test_root/invalid-other.json"
if BSDRUNNER_SOFTWARE_TEST_PREVIEW=invalid-other run_action install keybase >"$invalid_other_output"; then
    fail "nonstandard pkg failures should be rejected"
fi
jq -e '.ok == false and .message == "pkg could not plan install for keybase."' "$invalid_other_output" >/dev/null || fail "nonstandard pkg failure should remain structured"
[ ! -s "$command_log" ] || fail "failed solver preview should not invoke mdo"
pass "software action preserves genuine pkg planning failures"

: >"$command_log"
removal_output="$test_root/removal.json"
if BSDRUNNER_SOFTWARE_TEST_PREVIEW=removal-nonzero run_action install keybase >"$removal_output"; then
    fail "a valid plan containing removals should be blocked"
fi
jq -e '.ok == false and .message == "Safety stop: pkg planned unexpected removals." and (.details | contains("conflicting-package"))' "$removal_output" >/dev/null || fail "removal plan should reach the existing safety guard"
[ ! -s "$command_log" ] || fail "blocked removal plan should not invoke mdo"
pass "software action still blocks valid plans that remove packages"

if grep -Fq 'pkg install -n -y' "$action_script"; then
    fail "preview must never combine pkg -n and -y"
fi
pass "software action keeps previews non-mutating"

grep -Fq 'model: root.pendingActionId.length > 0 ? [] :' "$software_qml" || \
    fail "package action buttons should be hidden while confirmation is pending"
pass "software confirmation hides competing package actions"

printf 'All software action tests passed.\n'
