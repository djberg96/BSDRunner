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
    BSDRUNNER_JAILS_TEST_BASTILLE_CONFIG="${BSDRUNNER_JAILS_TEST_BASTILLE_CONFIG:-$fixtures/etc/bastille/bastille.conf}" \
    BSDRUNNER_JAILS_TEST_BASTILLE_PREFIX="${BSDRUNNER_JAILS_TEST_BASTILLE_PREFIX:-$fixtures/etc/bastille-root}" \
    BSDRUNNER_JAILS_TEST_PF_BACKEND="$fixtures/bin/bsdrunner-pf-backend" \
    BSDRUNNER_JAILS_TEST_HOST_RESOLV_CONF="${BSDRUNNER_JAILS_TEST_HOST_RESOLV_CONF:-$fixtures/etc/resolv.conf}" \
    BSDRUNNER_JAILS_TEST_RESOLVCONF_INTERFACES_DIR="${BSDRUNNER_JAILS_TEST_RESOLVCONF_INTERFACES_DIR:-$fixtures/etc/resolvconf/interfaces}" \
    BSDRUNNER_JAILS_TEST_DNS_COPY_FAIL="${BSDRUNNER_JAILS_TEST_DNS_COPY_FAIL:-0}" \
    BSDRUNNER_JAILS_TEST_NETWORK_READY="${BSDRUNNER_JAILS_TEST_NETWORK_READY:-1}" \
    BSDRUNNER_JAILS_TEST_PF_STATE="${BSDRUNNER_JAILS_TEST_PF_STATE:-}" \
    BSDRUNNER_JAILS_TEST_LOOPBACK_STATE="${BSDRUNNER_JAILS_TEST_LOOPBACK_STATE:-}" \
    BSDRUNNER_JAILS_TEST_LOOPBACK_SOURCE_STATE="${BSDRUNNER_JAILS_TEST_LOOPBACK_SOURCE_STATE:-}" \
    sh "$backend" "$@"
}

command -v jq >/dev/null 2>&1 || fail "jq is required to run the Jails backend tests"

demo_output="$test_root/demo.json"
BSDRUNNER_JAILS_FIXTURE="$demo_fixture"
export BSDRUNNER_JAILS_FIXTURE
run_backend snapshot >"$demo_output"
assert_json "$demo_output" \
    '.ok == true and .demo == true and .message == "Loaded Jails demo data." and (.running | length) == 1 and (.configured | length) == 1 and (.bastille | length) == 1 and .outbound_policies[0].policy == "internet-only" and .port_forwards == [{"name":"build","ipv4":"10.0.0.22","protocol":"tcp","host_port":8080,"jail_port":80}] and .simple_services[0].service == "nginx"' \
    "demo fixture should satisfy the snapshot contract"
pass "demo fixture satisfies the snapshot contract"

: >"$command_log"
demo_preview_output="$test_root/demo-preview.json"
run_backend preview demo-web 15.0-RELEASE 10.0.0.40/24 no >"$demo_preview_output"
assert_json "$demo_preview_output" \
    '.ok == true and .mutates == false and .backend == "bastille" and .ready == true and .checks.release_bootstrapped == true and .checks.dns_ready == true and .commands[0] == "bastille create --thick --no-boot demo-web 15.0-RELEASE 10.0.0.40/24" and (.commands[1] | endswith("/etc/resolv.conf"))' \
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
    '.storage.configured == true and .storage.initialized == true and (.storage.prefix | endswith("/tests/fixtures/jails/etc/bastille-root")) and .storage.zfs_prefix == "bastille" and .storage.pools == ["zroot","tank"]' \
    "snapshot should report Bastille storage and detected pools"
assert_json "$snapshot_output" \
    '.network == {"ready":true,"loopback_ready":true,"pf_running":true,"nat_ready":true,"rdr_anchor_ready":true,"filter_anchor_ready":true,"loopback_interface":"bastille0","external_interface":"wlan0","recommended_address":"10.0.0.20/24"}' \
    "snapshot should report fixture-backed Bastille network readiness"
assert_json "$snapshot_output" \
    '(.running | length) == 2 and .running[0].name == "api" and .running[1].ipv6 == "none"' \
    "snapshot should parse jls output"
assert_json "$snapshot_output" \
    '(.configured | length) == 3 and ([.configured[].name] | sort) == ["api","metrics","worker"]' \
    "snapshot should parse jail.conf fixtures"
assert_json "$snapshot_output" \
    '(.bastille | length) == 2 and .bastille[0].state == "running" and .bastille[0].release == "15.0-RELEASE" and .bastille[0].autostart == "YES" and .bastille[1].state == "stopped" and .bastille[1].release == "14.3-RELEASE" and .bastille[1].autostart == "NO"' \
    "snapshot should parse rich Bastille metadata"
assert_json "$snapshot_output" \
    '.outbound_policies == [{"name":"cache","ipv4":"10.0.0.9","policy":"internet-only","resolver":"192.0.2.53"},{"name":"build","ipv4":"10.0.0.10","policy":"none","resolver":"192.0.2.53"}]' \
    "snapshot should expose persisted jail outbound policies"
assert_json "$snapshot_output" \
    '.port_forwards == [{"name":"cache","ipv4":"10.0.0.9","protocol":"tcp","host_port":8080,"jail_port":80},{"name":"build","ipv4":"10.0.0.10","protocol":"udp","host_port":5353,"jail_port":5353}]' \
    "snapshot should expose persisted jail port forwards"
assert_json "$snapshot_output" \
    '(.simple_services | length) == 2 and (.simple_services[] | select(.name == "cache")) == {"name":"cache","ipv4":"10.0.0.9","service":"nginx","package":"nginx","label":"nginx","description":"Static web server and reverse proxy","port":80,"status_known":true,"installed":true,"enabled":true,"running":true} and (.simple_services[] | select(.name == "build")) == {"name":"build","ipv4":"10.0.0.10","service":"nginx","package":"nginx","label":"nginx","description":"Static web server and reverse proxy","port":80,"status_known":true,"installed":false,"enabled":false,"running":false}' \
    "snapshot should expose guarded nginx service status for Bastille jails"
pass "snapshot parses native and Bastille fixtures"

unready_prefix="$test_root/unready-bastille"
mkdir -p "$unready_prefix"
unready_snapshot="$test_root/unready-snapshot.json"
BSDRUNNER_JAILS_TEST_BASTILLE_PREFIX="$unready_prefix" run_backend snapshot >"$unready_snapshot"
assert_json "$unready_snapshot" \
    '.ok == true and .tools.bastille == true and .bastille_setup == false and .bastille_releases == [] and .storage.configured == false and .storage.initialized == false' \
    "an installed Bastille without initialized storage should not be reported ready"
: >"$command_log"
unready_bootstrap="$test_root/unready-bootstrap.json"
if BSDRUNNER_JAILS_TEST_BASTILLE_PREFIX="$unready_prefix" run_backend bootstrap 15.0-RELEASE 15.0-RELEASE >"$unready_bootstrap"; then
    fail "release bootstrap should require initialized Bastille storage"
fi
assert_json "$unready_bootstrap" \
    '.ok == false and .message == "Bastille storage is not configured."' \
    "release bootstrap should explain missing Bastille storage"
[ ! -s "$command_log" ] || fail "missing Bastille storage should block mutation commands"
pass "Bastille storage readiness is checked before provisioning"

: >"$command_log"
storage_preview="$test_root/storage-preview.json"
run_backend storage-preview zroot >"$storage_preview"
assert_json "$storage_preview" \
    '.ok == true and .mutates == false and .pool == "zroot" and (.prefix | endswith("/tests/fixtures/jails/etc/bastille-root")) and .target_dataset == "zroot/bastille" and .target_exists == false and .command == "bastille setup storage zroot"' \
    "storage preview should describe the conventional Bastille dataset"
[ ! -s "$command_log" ] || fail "storage preview should not execute Bastille"

run_backend storage-preview tank >"$storage_preview"
assert_json "$storage_preview" \
    '.target_dataset == "tank/bastille" and .target_exists == true' \
    "storage preview should report an existing conventional dataset"

storage_setup="$test_root/storage-setup.json"
if BSDRUNNER_JAILS_TEST_BASTILLE_PREFIX="$unready_prefix" run_backend storage-setup zroot wrong >"$storage_setup"; then
    fail "storage setup should require exact pool confirmation"
fi
assert_json "$storage_setup" \
    '.ok == false and .message == "Storage confirmation did not match."' \
    "storage setup should explain a mismatched confirmation"
[ ! -s "$command_log" ] || fail "rejected storage setup should not execute Bastille"

BSDRUNNER_JAILS_TEST_BASTILLE_PREFIX="$unready_prefix" run_backend storage-setup zroot zroot >"$storage_setup"
assert_json "$storage_setup" \
    '.ok == true and .message == "Configured Bastille storage on zroot." and .details == "Bastille action completed."' \
    "storage setup should return structured success"
grep -Fx 'mdo bastille setup storage zroot' "$command_log" >/dev/null || fail "storage setup should use mdo"
grep -Fx 'bastille setup storage zroot' "$command_log" >/dev/null || fail "storage setup should call only the Bastille storage subcommand"
pass "storage setup is previewed, confirmed, and narrowly dispatched"

: >"$command_log"
network_preview="$test_root/network-preview.json"
run_backend network-preview 10.0.0.20/24 >"$network_preview"
assert_json "$network_preview" \
    '.ok == true and .mutates == false and .ready == true and .address == "10.0.0.20/24" and .loopback_interface == "bastille0" and .external_interface == "wlan0" and .checks == {"loopback_ready":true,"pf_running":true,"nat_ready":true,"rdr_anchor_ready":true,"filter_anchor_ready":true,"address_route_safe":true}' \
    "network preview should report a ready non-overlapping jail network"
[ ! -s "$command_log" ] || fail "network preview should not execute setup commands"

run_backend network-preview 192.168.1.20/24 >"$network_preview"
assert_json "$network_preview" \
    '.ok == true and .ready == false and .checks.address_route_safe == false' \
    "network preview should reject an address on the host LAN"

network_setup="$test_root/network-setup.json"
if run_backend network-setup 10.0.0.20/24 wrong >"$network_setup"; then
    fail "network setup should require exact address confirmation"
fi
assert_json "$network_setup" \
    '.ok == false and .message == "Network confirmation did not match."' \
    "network setup should explain a mismatched confirmation"
[ ! -s "$command_log" ] || fail "rejected network setup should not execute setup commands"

loopback_state="$test_root/loopback-ready"
pf_state="$test_root/pf-ready"
BSDRUNNER_JAILS_TEST_LOOPBACK_STATE="$loopback_state" \
BSDRUNNER_JAILS_TEST_NETWORK_READY=0 \
BSDRUNNER_JAILS_TEST_PF_STATE="$pf_state" \
run_backend network-setup 10.0.0.20/24 10.0.0.20/24 >"$network_setup"
assert_json "$network_setup" \
    '.ok == true and .message == "Configured Bastille jail networking."' \
    "network setup should return structured success"
grep -Fx 'mdo bastille setup --yes loopback' "$command_log" >/dev/null || fail "network setup should configure Bastille loopback without a hidden prompt"
grep -Fx 'bastille setup --yes loopback' "$command_log" >/dev/null || fail "network setup should call Bastille's narrow noninteractive loopback subcommand"
grep -Fx 'pf-backend jail-network bastille0 wlan0' "$command_log" >/dev/null || fail "network setup should delegate NAT to BSDRunner PF"

network_snapshot="$test_root/network-snapshot.json"
BSDRUNNER_JAILS_TEST_LOOPBACK_STATE="$loopback_state" \
BSDRUNNER_JAILS_TEST_NETWORK_READY=0 \
BSDRUNNER_JAILS_TEST_PF_STATE="$pf_state" \
run_backend snapshot >"$network_snapshot"
assert_json "$network_snapshot" \
    '.network.ready == true and .network.loopback_ready == true and .network.nat_ready == true and .network.rdr_anchor_ready == true and .network.filter_anchor_ready == true' \
    "network setup should satisfy the next readiness snapshot"
pass "network setup is host-aware, confirmed, and split between Bastille and BSDRunner PF"

: >"$command_log"
rm -f "$loopback_state" "$pf_state"
loopback_source_state="$test_root/loopback-source-ready"
BSDRUNNER_JAILS_TEST_LOOPBACK_STATE="$loopback_state" \
BSDRUNNER_JAILS_TEST_LOOPBACK_SOURCE_STATE="$loopback_source_state" \
BSDRUNNER_JAILS_TEST_NETWORK_READY=0 \
BSDRUNNER_JAILS_TEST_PF_STATE="$pf_state" \
run_backend network-setup 10.0.0.20/24 10.0.0.20/24 >"$network_setup"
assert_json "$network_setup" \
    '.ok == true and .message == "Configured Bastille jail networking."' \
    "network setup should recover Bastille's configured but unrenamed loopback"
grep -Fx 'mdo bastille setup --yes loopback' "$command_log" >/dev/null || fail "loopback recovery should begin with Bastille's supported setup command"
grep -Fx 'mdo ifconfig lo1 name bastille0' "$command_log" >/dev/null || fail "loopback recovery should apply Bastille's explicit rc.conf rename"
grep -Fx 'pf-backend jail-network bastille0 wlan0' "$command_log" >/dev/null || fail "recovered loopback should be passed to BSDRunner PF"
pass "network setup repairs Bastille's configured but unrenamed loopback"

: >"$command_log"
configured_only_config="$test_root/configured-bastille.conf"
printf '%s\n' \
    'bastille_prefix="/usr/local/bastille"' \
    'bastille_zfs_enable="YES"' \
    'bastille_zfs_zpool="zroot"' \
    'bastille_zfs_prefix="bastille"' >"$configured_only_config"
configured_bootstrap="$test_root/configured-bootstrap.json"
BSDRUNNER_JAILS_TEST_BASTILLE_CONFIG="$configured_only_config" \
BSDRUNNER_JAILS_TEST_BASTILLE_PREFIX="$unready_prefix" \
run_backend bootstrap 14.4-RELEASE 14.4-RELEASE >"$configured_bootstrap"
assert_json "$configured_bootstrap" \
    '.ok == true and .message == "Bootstrapped 14.4-RELEASE."' \
    "a configured pool should allow the first bootstrap to initialize storage"
grep -Fx 'mdo bastille bootstrap --update 14.4-RELEASE' "$command_log" >/dev/null || fail "first bootstrap should run through mdo"
pass "configured ZFS storage can be initialized by the first bootstrap"

: >"$command_log"
preview_output="$test_root/preview.json"
run_backend preview web 15.0-RELEASE 10.0.0.20/24 yes >"$preview_output"
assert_json "$preview_output" \
    '.ok == true and .mutates == false and .ready == true and .inputs == {"name":"web","release":"15.0-RELEASE","address":"10.0.0.20/24","autostart":"yes","jail_type":"thick","outbound_policy":"internet-only"} and .checks == {"bastille_installed":true,"bastille_setup":true,"storage_configured":true,"network_ready":true,"dns_ready":true,"release_bootstrapped":true,"name_available":true,"address_available":true,"address_route_safe":true,"host_release":"15.0-RELEASE","host_compatible":true} and .commands[0] == "bastille create --thick web 15.0-RELEASE 10.0.0.20/24" and (.commands[1] | startswith("bastille cp web ") and endswith(" /etc/resolv.conf")) and .commands[2] == "bsdrunner-pf-backend.sh jail-policy web 10.0.0.20 internet-only 192.0.2.53"' \
    "create preview should return an exact non-mutating Bastille plan"
[ ! -s "$command_log" ] || fail "create preview should not execute Bastille"

thin_preview_output="$test_root/thin-preview.json"
run_backend preview web 15.0-RELEASE 10.0.0.20/24 yes thin >"$thin_preview_output"
assert_json "$thin_preview_output" \
    '.ok == true and .inputs.jail_type == "thin" and .commands[0] == "bastille create web 15.0-RELEASE 10.0.0.20/24" and (.commands[1] | endswith("/etc/resolv.conf")) and (.notes[0] | contains("thin service jail"))' \
    "thin preview should omit Bastille's thick-jail flag and explain shared userland"
[ ! -s "$command_log" ] || fail "thin preview should remain read-only"

offline_preview_output="$test_root/offline-preview.json"
run_backend preview web 15.0-RELEASE 10.0.0.20/24 yes thick none >"$offline_preview_output"
assert_json "$offline_preview_output" \
    '.ok == true and .inputs.outbound_policy == "none" and .commands[2] == "bsdrunner-pf-backend.sh jail-policy web 10.0.0.20 none 192.0.2.53" and any(.notes[]; contains("No outbound"))' \
    "create preview should expose the no-outbound policy"
[ ! -s "$command_log" ] || fail "outbound policy previews should remain read-only"

bootstrap_preview_output="$test_root/bootstrap-preview.json"
run_backend preview web 14.4-RELEASE 10.0.0.20/24 no >"$bootstrap_preview_output"
assert_json "$bootstrap_preview_output" \
    '.ready == true and .checks.release_bootstrapped == false and .checks.host_compatible == true and .commands[0:2] == ["bastille bootstrap --update 14.4-RELEASE","bastille create --thick --no-boot web 14.4-RELEASE 10.0.0.20/24"] and (.commands[2] | endswith("/etc/resolv.conf"))' \
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

missing_dns_preview_output="$test_root/missing-dns-preview.json"
BSDRUNNER_JAILS_TEST_HOST_RESOLV_CONF="$test_root/missing-resolv.conf" \
BSDRUNNER_JAILS_TEST_RESOLVCONF_INTERFACES_DIR="$test_root/missing-resolvconf" \
run_backend preview web 15.0-RELEASE 10.0.0.20/24 yes >"$missing_dns_preview_output"
assert_json "$missing_dns_preview_output" \
    '.ok == true and .ready == false and .checks.dns_ready == false and any(.notes[]; contains("No non-loopback DNS resolver was detected"))' \
    "create preview should block a jail with no reachable resolver"
[ ! -s "$command_log" ] || fail "DNS readiness previews should remain read-only"

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
if run_backend preview web 15.0-RELEASE 10.0.0.20/24 yes clone >"$invalid_preview_output"; then
    fail "create preview should reject unsupported jail types"
fi
assert_json "$invalid_preview_output" \
    '.ok == false and .message == "Invalid jail type."' \
    "create preview should reject unsupported jail types"
if run_backend preview web 15.0-RELEASE 10.0.0.20/24 yes thick unrestricted >"$invalid_preview_output"; then
    fail "create preview should reject unsupported outbound policies"
fi
assert_json "$invalid_preview_output" \
    '.ok == false and .message == "Invalid outbound policy."' \
    "create preview should reject unsupported outbound policies"
pass "create preview is exact, read-only, and validated"

: >"$command_log"
bootstrap_output="$test_root/bootstrap.json"
run_backend bootstrap 14.4-RELEASE 14.4-RELEASE >"$bootstrap_output"
assert_json "$bootstrap_output" \
    '.ok == true and .message == "Bootstrapped 14.4-RELEASE." and .details == "Bastille action completed."' \
    "release bootstrap should return a structured success"
grep -Fx 'mdo bastille bootstrap --update 14.4-RELEASE' "$command_log" >/dev/null || fail "release bootstrap should use mdo"
grep -Fx 'bastille bootstrap --update 14.4-RELEASE' "$command_log" >/dev/null || fail "release bootstrap should call Bastille"
pass "release bootstrap uses the guarded command path"

: >"$command_log"
create_output="$test_root/create.json"
run_backend create basic 15.0-RELEASE 10.0.0.30/24 no basic >"$create_output"
assert_json "$create_output" \
    '.ok == true and .message == "Created basic." and (.details | contains("Configured jail DNS from"))' \
    "basic jail creation should return a structured success"
grep -Fx 'mdo bastille create --thick --no-boot basic 15.0-RELEASE 10.0.0.30/24' "$command_log" >/dev/null || fail "jail creation should use mdo"
grep -Fx 'bastille create --thick --no-boot basic 15.0-RELEASE 10.0.0.30/24' "$command_log" >/dev/null || fail "jail creation should call Bastille with exact arguments"
grep -Fx "mdo bastille cp basic $fixtures/etc/resolvconf/interfaces/wlan0 /etc/resolv.conf" "$command_log" >/dev/null || fail "jail creation should install the reachable upstream resolver through mdo"
grep -Fx "bastille cp basic $fixtures/etc/resolvconf/interfaces/wlan0 /etc/resolv.conf" "$command_log" >/dev/null || fail "jail creation should replace a host-only loopback resolver"
grep -Fx 'pf-backend jail-policy basic 10.0.0.30 internet-only 192.0.2.53' "$command_log" >/dev/null || fail "jail creation should apply the recommended internet-only policy"

run_backend create lean 15.0-RELEASE 10.0.0.31/24 yes lean thin >"$create_output"
assert_json "$create_output" \
    '.ok == true and .message == "Created lean."' \
    "thin jail creation should return a structured success"
grep -Fx 'mdo bastille create lean 15.0-RELEASE 10.0.0.31/24' "$command_log" >/dev/null || fail "thin jail creation should use Bastille's default thin mode through mdo"
grep -Fx 'bastille create lean 15.0-RELEASE 10.0.0.31/24' "$command_log" >/dev/null || fail "thin jail creation should omit the thick-jail flag"
grep -Fx "mdo bastille cp lean $fixtures/etc/resolvconf/interfaces/wlan0 /etc/resolv.conf" "$command_log" >/dev/null || fail "thin jail creation should install the same reachable resolver"
grep -Fx 'pf-backend jail-policy lean 10.0.0.31 internet-only 192.0.2.53' "$command_log" >/dev/null || fail "thin jail creation should apply its outbound policy"
pass "thick and thin jail creation use guarded command paths with working DNS"

: >"$command_log"
dns_copy_warning_output="$test_root/dns-copy-warning.json"
BSDRUNNER_JAILS_TEST_DNS_COPY_FAIL=1 \
run_backend create dnswarn 15.0-RELEASE 10.0.0.32/24 yes dnswarn >"$dns_copy_warning_output"
assert_json "$dns_copy_warning_output" \
    '.ok == true and .message == "Created dnswarn, but DNS setup needs attention." and (.details | contains("The jail exists"))' \
    "a post-create DNS copy failure should preserve and clearly report the created jail"
grep -Fx 'mdo bastille create --thick dnswarn 15.0-RELEASE 10.0.0.32/24' "$command_log" >/dev/null || fail "DNS copy failure test should create the jail first"
grep -Fx "mdo bastille cp dnswarn $fixtures/etc/resolvconf/interfaces/wlan0 /etc/resolv.conf" "$command_log" >/dev/null || fail "DNS copy failure test should attempt the resolver copy"
pass "post-create DNS failures preserve the jail and report remediation"

: >"$command_log"
guarded_create_output="$test_root/guarded-create.json"
if run_backend create basic 15.0-RELEASE 10.0.0.30/24 yes wrong >"$guarded_create_output"; then
    fail "jail creation should require an exact name confirmation"
fi
assert_json "$guarded_create_output" \
    '.ok == false and .message == "Jail confirmation did not match."' \
    "jail creation should explain a mismatched confirmation"
if run_backend create future 14.4-RELEASE 10.0.0.31/24 yes future >"$guarded_create_output"; then
    fail "jail creation should require a bootstrapped release"
fi
assert_json "$guarded_create_output" \
    '.ok == false and .message == "The selected release is not bootstrapped."' \
    "jail creation should reject a missing release"
if run_backend create cache 15.0-RELEASE 10.0.0.31/24 yes cache >"$guarded_create_output"; then
    fail "jail creation should reject an existing name"
fi
assert_json "$guarded_create_output" \
    '.ok == false and .message == "The jail name is already in use."' \
    "jail creation should reject a last-minute collision"
if BSDRUNNER_JAILS_TEST_HOST_RESOLV_CONF="$test_root/missing-resolv.conf" \
   BSDRUNNER_JAILS_TEST_RESOLVCONF_INTERFACES_DIR="$test_root/missing-resolvconf" \
   run_backend create dnsless 15.0-RELEASE 10.0.0.32/24 yes dnsless >"$guarded_create_output"; then
    fail "jail creation should require a reachable DNS resolver"
fi
assert_json "$guarded_create_output" \
    '.ok == false and .message == "No jail-safe DNS resolver was detected."' \
    "jail creation should explain missing DNS before invoking Bastille"
[ ! -s "$command_log" ] || fail "rejected jail creation should not execute mutating commands"
pass "jail creation revalidates confirmation, release, and collisions"

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
policy_action_output="$test_root/policy-action.json"
run_backend policy-set cache 10.0.0.9 none cache >"$policy_action_output"
assert_json "$policy_action_output" \
    '.ok == true and .message == "Applied outbound policy to cache."' \
    "outbound policy changes should return a structured success"
grep -Fx 'pf-backend jail-policy cache 10.0.0.9 none 192.0.2.53' "$command_log" >/dev/null || fail "outbound policy changes should delegate exact values to the PF backend"
if run_backend policy-set cache 10.0.0.9 lan wrong >"$test_root/invalid-policy.json"; then
    fail "outbound policy changes should require exact jail confirmation"
fi
pass "existing Bastille jails can apply guarded outbound policies"

: >"$command_log"
forward_action_output="$test_root/forward-action.json"
run_backend forward-add cache 10.0.0.9 tcp 8443 443 cache >"$forward_action_output"
assert_json "$forward_action_output" \
    '.ok == true and .message == "Added port forward for cache."' \
    "port-forward additions should return a structured success"
grep -Fx 'pf-backend jail-forward-add cache 10.0.0.9 tcp 8443 443' "$command_log" >/dev/null || fail "port-forward additions should delegate exact values to the PF backend"
run_backend forward-remove cache 10.0.0.9 tcp 8443 443 cache >"$test_root/forward-remove.json"
assert_json "$test_root/forward-remove.json" \
    '.ok == true and .message == "Removed port forward from cache."' \
    "port-forward removals should return a structured success"
grep -Fx 'pf-backend jail-forward-remove cache 10.0.0.9 tcp 8443 443' "$command_log" >/dev/null || fail "port-forward removals should delegate exact values to the PF backend"
if run_backend forward-add cache 10.0.0.9 tcp 8443 443 wrong >"$test_root/invalid-forward-confirmation.json"; then
    fail "port-forward changes should require exact jail confirmation"
fi
if run_backend forward-add cache 10.0.0.9 sctp 8443 443 cache >"$test_root/invalid-forward-protocol.json"; then
    fail "port-forward changes should reject unsupported protocols"
fi
pass "existing Bastille jails can add and remove guarded port forwards"

: >"$command_log"
service_install_output="$test_root/service-install.json"
run_backend service-action cache 10.0.0.9 nginx install cache >"$service_install_output"
assert_json "$service_install_output" \
    '.ok == true and .message == "Installed, enabled, and started nginx in cache."' \
    "guided nginx installation should return a structured success"
grep -Fx 'mdo sudo -n bastille pkg -y cache install nginx' "$command_log" >/dev/null || fail "guided install should cross the jail attachment boundary through the narrow privilege path"
grep -Fx 'bastille pkg -y cache install nginx' "$command_log" >/dev/null || fail "guided install should use Bastille pkg auto-confirmation"
grep -Fx 'bastille sysrc cache nginx_enable=YES' "$command_log" >/dev/null || fail "guided install should enable nginx inside the jail"
grep -Fx 'bastille service cache nginx start' "$command_log" >/dev/null || fail "guided install should start nginx inside the jail"

: >"$command_log"
run_backend service-action cache 10.0.0.9 nginx restart cache >"$test_root/service-restart.json"
grep -Fx 'bastille service cache nginx restart' "$command_log" >/dev/null || fail "guided service lifecycle should delegate through Bastille"
run_backend service-action cache 10.0.0.9 nginx disable cache >"$test_root/service-disable.json"
grep -Fx 'bastille sysrc cache nginx_enable=NO' "$command_log" >/dev/null || fail "guided service boot changes should delegate through Bastille sysrc"
if run_backend service-action cache 10.0.0.9 sshd start cache >"$test_root/unsupported-service.json"; then
    fail "guided service actions should reject services outside the curated allowlist"
fi
if run_backend service-action cache 10.0.0.9 nginx start wrong >"$test_root/invalid-service-confirmation.json"; then
    fail "guided service actions should require exact jail confirmation"
fi
: >"$command_log"
if run_backend service-action build 10.0.0.10 nginx start build >"$test_root/stopped-service-jail.json"; then
    fail "guided service actions should require a running Bastille jail"
fi
[ ! -s "$command_log" ] || fail "stopped jail validation should block service mutations"
pass "guided nginx actions are confirmed, allowlisted, and require a running jail"

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
