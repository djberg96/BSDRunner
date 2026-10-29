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
base_rendered="$test_root/base-pf.conf"
nat_rendered="$test_root/nat-pf.conf"
invalid_rendered="$test_root/invalid-pf.conf"

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
