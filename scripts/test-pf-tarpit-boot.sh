#!/bin/sh

set -eu

repo_root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
boot_helper="$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-pf-tarpit-boot"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/bsdrunner-pf-tarpit-tests.XXXXXX")"
fixture_bin="$test_root/bin"
profile_file="$test_root/profile.conf"
pf_config_file="$test_root/pf.conf"
sshd_config_file="$test_root/sshd_config"
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

mkdir -p "$fixture_bin"

cat >"$fixture_bin/pfctl" <<'EOF'
#!/bin/sh
printf 'pfctl %s\n' "$*" >>"$BSDRUNNER_PF_TARPIT_TEST_LOG"
grep -q '^ssh_real_port = "22277"$' "$2"
EOF

cat >"$fixture_bin/sshd" <<'EOF'
#!/bin/sh
printf 'sshd %s\n' "$*" >>"$BSDRUNNER_PF_TARPIT_TEST_LOG"
grep -q '^Port 22277$' "$3"
EOF

chmod +x "$fixture_bin/pfctl" "$fixture_bin/sshd"

cat >"$profile_file" <<'EOF'
allow_ssh_lan=yes
allow_ssh_tarpit=yes
ssh_real_port=22245
EOF

sh "$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-pf-profile.sh" "$profile_file" >"$pf_config_file"
old_profile_checksum="$(sed -n 's/^# bsdrunner_pf_profile_checksum=//p' "$pf_config_file")"

cat >"$sshd_config_file" <<'EOF'
# BEGIN BSDRunner firewall SSH tarpit
# Real sshd is moved away from port 22 while endlessh owns the tarpit.
Port 22245
# END BSDRunner firewall SSH tarpit
EOF

: >"$command_log"

PATH="$fixture_bin:/usr/bin:/bin" \
BSDRUNNER_PF_TARPIT_STANDALONE=yes \
BSDRUNNER_PF_TARPIT_TEST_PORT=22277 \
BSDRUNNER_PF_TARPIT_TEST_LOG="$command_log" \
bsdrunner_pf_tarpit_profile="$profile_file" \
bsdrunner_pf_tarpit_pf_config="$pf_config_file" \
bsdrunner_pf_tarpit_sshd_config="$sshd_config_file" \
bsdrunner_pf_tarpit_renderer="$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-pf-profile.sh" \
sh "$boot_helper" >"$test_root/output"

grep -Fx 'ssh_real_port=22277' "$profile_file" >/dev/null || fail "profile should persist the rotated port"
grep -Fx 'ssh_real_port = "22277"' "$pf_config_file" >/dev/null || fail "PF should use the rotated port"
grep -Fx 'Port 22277' "$sshd_config_file" >/dev/null || fail "sshd should use the rotated port"
new_profile_checksum="$(sed -n 's/^# bsdrunner_pf_profile_checksum=//p' "$pf_config_file")"
[ -n "$new_profile_checksum" ] && [ "$new_profile_checksum" != "$old_profile_checksum" ] || fail "PF checksum should track the rotated profile"
grep -Fx "pfctl -nf $test_root/pf.conf" "$command_log" >/dev/null && fail "PF validation should use the temporary configuration"
grep -F 'pfctl -nf ' "$command_log" >/dev/null || fail "rotated PF configuration should be validated"
grep -F 'sshd -t -f ' "$command_log" >/dev/null || fail "rotated sshd configuration should be validated"
grep -Fx 'Rotated BSDRunner real SSH port from 22245 to 22277.' "$test_root/output" >/dev/null || fail "rotation should report both ports"
pass "boot helper rotates and validates the shared SSH port"

sed -i '' 's/^allow_ssh_tarpit=yes$/allow_ssh_tarpit=no/' "$profile_file"
before_profile="$(cksum "$profile_file")"
before_pf="$(cksum "$pf_config_file")"
before_sshd="$(cksum "$sshd_config_file")"

PATH="$fixture_bin:/usr/bin:/bin" \
BSDRUNNER_PF_TARPIT_STANDALONE=yes \
BSDRUNNER_PF_TARPIT_TEST_PORT=22288 \
BSDRUNNER_PF_TARPIT_TEST_LOG="$command_log" \
bsdrunner_pf_tarpit_profile="$profile_file" \
bsdrunner_pf_tarpit_pf_config="$pf_config_file" \
bsdrunner_pf_tarpit_sshd_config="$sshd_config_file" \
bsdrunner_pf_tarpit_renderer="$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-pf-profile.sh" \
sh "$boot_helper" >"$test_root/disabled-output"

[ "$(cksum "$profile_file")" = "$before_profile" ] || fail "disabled tarpit should not change the profile"
[ "$(cksum "$pf_config_file")" = "$before_pf" ] || fail "disabled tarpit should not change PF"
[ "$(cksum "$sshd_config_file")" = "$before_sshd" ] || fail "disabled tarpit should not change sshd"
pass "boot helper leaves disabled tarpit configurations unchanged"

backend_bin="$test_root/backend-bin"
backend_boot_target="$test_root/bsdrunner_pf_tarpit"
backend_renderer_target="$test_root/bsdrunner-pf-profile"
backend="$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-pf-backend.sh"
cp -R "$repo_root/tests/fixtures/pf/bin" "$backend_bin"

cat >"$backend_bin/sysrc" <<'EOF'
#!/bin/sh
printf 'sysrc %s\n' "$*" >>"$BSDRUNNER_PF_TEST_LOG"
if [ "${1:-}" = "-n" ]; then
    case "${2:-}" in
        pf_enable) printf 'YES\n' ;;
        *) printf 'NO\n' ;;
    esac
fi
EOF

cat >"$backend_bin/sshd" <<'EOF'
#!/bin/sh
printf 'sshd %s\n' "$*" >>"$BSDRUNNER_PF_TEST_LOG"
if [ "${1:-}" = "-t" ] && [ "${2:-}" = "-f" ]; then
    grep -q '^Port 22245$' "$3"
fi
EOF

cat >"$backend_bin/endlessh" <<'EOF'
#!/bin/sh
exit 0
EOF

chmod +x "$backend_bin/sysrc" "$backend_bin/sshd" "$backend_bin/endlessh"

cat >"$profile_file" <<'EOF'
allow_outbound=yes
block_unsolicited=yes
allow_diagnostics=yes
allow_ipv6=yes
allow_dhcp=yes
allow_mdns=yes
dns_leak_protection=yes
allow_ssh_lan=yes
allow_ssh_tarpit=yes
ssh_real_port=22245
log_blocked=yes
EOF

sh "$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-pf-profile.sh" "$profile_file" >"$pf_config_file"
cat >"$sshd_config_file" <<'EOF'
Port 22
EOF
: >"$command_log"

PATH="$backend_bin:/usr/bin:/bin" \
BSDRUNNER_PF_PROFILE_DIR="$test_root" \
BSDRUNNER_PF_PROFILE_SCRIPT="$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-pf-profile.sh" \
BSDRUNNER_PF_CONFIG_FILE="$pf_config_file" \
BSDRUNNER_PF_SSHD_CONFIG_FILE="$sshd_config_file" \
BSDRUNNER_PF_TARPIT_BOOT_SCRIPT="$boot_helper" \
BSDRUNNER_PF_TARPIT_BOOT_TARGET="$backend_boot_target" \
BSDRUNNER_PF_TARPIT_RENDERER_TARGET="$backend_renderer_target" \
BSDRUNNER_PF_TEST_LOG="$command_log" \
sh "$backend" apply >"$test_root/backend-output"

jq -e '.ok == true' "$test_root/backend-output" >/dev/null || fail "backend apply should succeed"
[ -x "$backend_boot_target" ] || fail "backend should install the boot helper"
[ -x "$backend_renderer_target" ] || fail "backend should install the profile renderer"
grep -Fx "sysrc bsdrunner_pf_tarpit_profile=$test_root/profile.conf" "$command_log" >/dev/null || fail "backend should configure the boot profile path"
grep -Fx "sysrc bsdrunner_pf_tarpit_renderer=$backend_renderer_target" "$command_log" >/dev/null || fail "backend should configure the root-owned renderer"
grep -Fx 'sysrc bsdrunner_pf_tarpit_enable=YES' "$command_log" >/dev/null || fail "backend should enable rotation with PF boot"
pass "backend installs and enables boot-time tarpit rotation"

printf 'All PF tarpit boot tests passed.\n'
