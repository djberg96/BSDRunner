#!/bin/sh

set -eu

repo_root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
renderer="$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-pf-profile.sh"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/bsdrunner-pf-profile-tests.XXXXXX")"

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

base_profile="$test_root/base-profile.conf"
nat_profile="$test_root/nat-profile.conf"
invalid_profile="$test_root/invalid-profile.conf"
policy_profile="$test_root/policy-profile.conf"
base_rendered="$test_root/base-pf.conf"
nat_rendered="$test_root/nat-pf.conf"
invalid_rendered="$test_root/invalid-pf.conf"
policy_rendered="$test_root/policy-pf.conf"

printf '%s\n' \
    'allow_outbound=yes' \
    'block_unsolicited=yes' \
    'allow_diagnostics=yes' \
    'allow_ipv6=yes' \
    'allow_dhcp=yes' \
    'allow_mdns=yes' \
    'allow_ssh_lan=no' \
    'allow_ssh_tarpit=no' \
    'log_blocked=no' >"$base_profile"

sh "$renderer" "$base_profile" >"$base_rendered"
grep -Fx 'set skip on lo0' "$base_rendered" >/dev/null || fail "default profile should skip only lo0"
if grep -Eq 'table <jails>|nat on \$jail_ext_if|rdr-anchor "rdr/\*"|anchor "bastille/\*"' "$base_rendered"; then
    fail "default profile should not enable jail networking"
fi
pass "default profile leaves jail networking disabled"

cp "$base_profile" "$nat_profile"
printf '%s\n' \
    'jail_nat=yes' \
    'jail_interface=bastille0' \
    'jail_ext_if=wlan0' >>"$nat_profile"

sh "$renderer" "$nat_profile" >"$nat_rendered"
grep -Fx 'jail_ext_if = "wlan0"' "$nat_rendered" >/dev/null || fail "jail NAT should name the external interface"
grep -Fx 'jail_if = "bastille0"' "$nat_rendered" >/dev/null || fail "jail NAT should name the loopback interface"
grep -Fx 'table <jails> persist' "$nat_rendered" >/dev/null || fail "jail NAT should define Bastille's address table"
grep -Fx 'set skip on lo' "$nat_rendered" >/dev/null || fail "jail NAT should skip the loopback interface group"
grep -Fx 'nat on $jail_ext_if inet from <jails> to any -> ($jail_ext_if:0)' "$nat_rendered" >/dev/null || fail "jail NAT should translate the Bastille table"
grep -Fx 'rdr-anchor "rdr/*"' "$nat_rendered" >/dev/null || fail "jail NAT should expose Bastille's redirect anchor"
grep -Fx 'anchor "bastille/*"' "$nat_rendered" >/dev/null || fail "jail NAT should expose Bastille's filter anchor"
pass "enabled jail networking renders the conventional Bastille PF integration"

cp "$nat_profile" "$policy_profile"
printf '%s\n' \
    'web|10.0.0.20|internet-only|192.168.1.254' \
    'build|10.0.0.21|none|192.168.1.254' \
    'media|10.0.0.22|lan|192.168.1.254' >"$test_root/jail-policies.conf"

sh "$renderer" "$policy_profile" >"$policy_rendered"
grep -F 'private_nets = "{ 10.0.0.0/8, 100.64.0.0/10, 127.0.0.0/8, 169.254.0.0/16, 172.16.0.0/12, 192.168.0.0/16 }"' "$policy_rendered" >/dev/null || fail "internet-only policy should define blocked private destinations"
grep -Fx 'pass out quick on $jail_ext_if inet proto { tcp udp } from 10.0.0.20 to 192.168.1.254 port 53 keep state' "$policy_rendered" >/dev/null || fail "internet-only policy should preserve DNS to the selected resolver"
grep -Fx 'block return out quick on $jail_ext_if inet from 10.0.0.20 to $private_nets' "$policy_rendered" >/dev/null || fail "internet-only policy should block private destinations"
grep -Fx 'pass out quick on $jail_ext_if inet from 10.0.0.20 to any keep state' "$policy_rendered" >/dev/null || fail "internet-only policy should allow public destinations"
grep -Fx 'block return out quick on $jail_ext_if inet from 10.0.0.21 to any' "$policy_rendered" >/dev/null || fail "no-outbound policy should block all destinations"
grep -Fx 'pass out quick on $jail_ext_if inet from 10.0.0.22 to any keep state' "$policy_rendered" >/dev/null || fail "LAN policy should allow all destinations"
policy_rule_line="$(grep -nF 'block return out quick on $jail_ext_if inet from 10.0.0.21 to any' "$policy_rendered" | cut -d: -f1)"
general_rule_line="$(grep -nF 'pass out all keep state' "$policy_rendered" | cut -d: -f1)"
[ "$policy_rule_line" -lt "$general_rule_line" ] || fail "per-jail rules must be evaluated before the general outbound allow"
pass "per-jail outbound policies render before the general host outbound rule"

cp "$base_profile" "$invalid_profile"
printf '%s\n' \
    'jail_nat=yes' \
    'jail_interface=bad interface' \
    'jail_ext_if=wlan0' >>"$invalid_profile"

sh "$renderer" "$invalid_profile" >"$invalid_rendered"
if grep -Eq 'table <jails>|nat on \$jail_ext_if|rdr-anchor "rdr/\*"|anchor "bastille/\*"' "$invalid_rendered"; then
    fail "invalid jail interfaces should disable jail networking"
fi
pass "invalid jail networking values fail closed"

printf 'All PF profile tests passed.\n'
