#!/bin/sh

set -eu

repo_root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
backend="$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-pf-backend.sh"
renderer="$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-pf-profile.sh"
fixture_bin="$repo_root/tests/fixtures/pf/bin"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/bsdrunner-pf-backend-tests.XXXXXX")"
profile_dir="$test_root/profile"
config_file="$test_root/pf.conf"
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

run_backend() {
    PATH="$fixture_bin:/usr/bin:/bin" \
    BSDRUNNER_PF_PROFILE_DIR="$profile_dir" \
    BSDRUNNER_PF_PROFILE_SCRIPT="$renderer" \
    BSDRUNNER_PF_CONFIG_FILE="$config_file" \
    BSDRUNNER_PF_TEST_LOG="$command_log" \
    BSDRUNNER_PF_TEST_VALIDATE_FAIL="${BSDRUNNER_PF_TEST_VALIDATE_FAIL:-0}" \
    sh "$backend" "$@"
}

mkdir -p "$profile_dir"
printf '%s\n' \
    'allow_outbound=yes' \
    'block_unsolicited=yes' \
    'allow_diagnostics=yes' \
    'allow_ipv6=yes' \
    'allow_dhcp=yes' \
    'allow_mdns=yes' \
    'allow_ssh_lan=no' \
    'allow_ssh_tarpit=no' \
    'log_blocked=no' \
    'jail_nat=yes' \
    'jail_interface=bastille0' \
    'jail_ext_if=wlan0' >"$profile_dir/profile.conf"
: >"$command_log"

policy_output="$test_root/policy.json"
run_backend jail-policy web 10.0.0.20 internet-only 192.168.1.254 >"$policy_output"
jq -e '.ok == true and .message == "Applied outbound policy to web."' "$policy_output" >/dev/null || fail "policy apply should return structured success"
grep -Fx 'web|10.0.0.20|internet-only|192.168.1.254' "$profile_dir/jail-policies.conf" >/dev/null || fail "policy apply should persist validated values"
grep -Fx 'block return out quick on $jail_ext_if inet from 10.0.0.20 to $private_nets' "$config_file" >/dev/null || fail "policy apply should install the rendered internet-only rule"
grep -Fx 'service pf reload' "$command_log" >/dev/null || fail "policy apply should reload PF"
grep -Fx 'pfctl -k 10.0.0.20' "$command_log" >/dev/null || fail "policy apply should clear existing jail states"
pass "PF backend persists, renders, reloads, and activates a jail policy"

invalid_output="$test_root/invalid.json"
if run_backend jail-policy web 10.0.0.20 unrestricted 192.168.1.254 >"$invalid_output"; then
    fail "invalid policies should be rejected"
fi
jq -e '.ok == false and .message == "Invalid jail outbound policy."' "$invalid_output" >/dev/null || fail "invalid policy errors should be structured"
pass "PF backend rejects invalid outbound policies"

previous_policy="$(cat "$profile_dir/jail-policies.conf")"
failed_output="$test_root/failed.json"
if BSDRUNNER_PF_TEST_VALIDATE_FAIL=1 run_backend jail-policy web 10.0.0.20 none 192.168.1.254 >"$failed_output"; then
    fail "failed PF validation should reject the policy change"
fi
[ "$(cat "$profile_dir/jail-policies.conf")" = "$previous_policy" ] || fail "failed policy apply should restore the previous policy file"
jq -e '.ok == false and .message == "Unable to apply outbound policy to web."' "$failed_output" >/dev/null || fail "failed policy apply should return structured error"
pass "PF backend rolls back policy persistence when validation fails"

printf 'All PF backend tests passed.\n'
