#!/bin/sh
set -eu
repo_root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
helper="$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-wireless-toggle.sh"
watcher="$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-thinkpad-wireless-watch.sh"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/bsdrunner-wireless-tests.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT HUP INT TERM
mkdir -p "$test_root/bin" "$test_root/state"
cat > "$test_root/bin/uname" <<'MOCK'
#!/bin/sh
printf 'FreeBSD\n'
MOCK
cat > "$test_root/bin/lockf" <<'MOCK'
#!/bin/sh
shift 3
exec "$@"
MOCK
cat > "$test_root/bin/mdo" <<'MOCK'
#!/bin/sh
exec "$@"
MOCK
cat > "$test_root/bin/ifconfig" <<'MOCK'
#!/bin/sh
if [ "$*" = '-g wlan -l' ]; then
    printf 'wlan0 wlan1\n'
elif [ "$*" = '-u -g wlan -l' ]; then
    [ "$(cat "$TEST_ROOT/wlan0")" != up ] || printf 'wlan0 '
    [ "$(cat "$TEST_ROOT/wlan1")" != up ] || printf 'wlan1 '
    printf '\n'
else
    [ "$2" != down ] || [ "${TEST_FAIL_DOWN:-no}" != yes ] || exit 1
    [ "$2" != up ] || [ "${TEST_FAIL_UP:-no}" != yes ] || exit 1
    case "$1:$2" in wlan0:up|wlan0:down|wlan1:up|wlan1:down) printf '%s\n' "$2" > "$TEST_ROOT/$1" ;; *) exit 1 ;; esac
fi
MOCK
cat > "$test_root/bin/sysctl" <<'MOCK'
#!/bin/sh
case "$*" in
    '-n dev.acpi_ibm.0.bluetooth') cat "$TEST_ROOT/bluetooth" ;;
    'dev.acpi_ibm.0.bluetooth=0') [ "${TEST_FAIL_BT:-no}" != yes ] || exit 1; printf '0\n' > "$TEST_ROOT/bluetooth" ;;
    'dev.acpi_ibm.0.bluetooth=1') printf '1\n' > "$TEST_ROOT/bluetooth" ;;
    *) exit 1 ;;
esac
MOCK
cat > "$test_root/bin/notify-send" <<'MOCK'
#!/bin/sh
[ "${TEST_NOTIFY_FAIL:-no}" != yes ] || exit 1
printf 'notification\n' >> "$TEST_ROOT/notifications"
MOCK
cat > "$test_root/bin/dbus-send" <<'MOCK'
#!/bin/sh
exit 1
MOCK
cat > "$test_root/bin/hyprctl" <<'MOCK'
#!/bin/sh
[ "$1" = notify ] || exit 1
printf 'fallback\n' >> "$TEST_ROOT/fallback-notifications"
MOCK
chmod 755 "$test_root/bin/"*
run_toggle() {
    env TEST_ROOT="$test_root" TEST_FAIL_DOWN="${TEST_FAIL_DOWN:-no}" TEST_FAIL_UP="${TEST_FAIL_UP:-no}" TEST_FAIL_BT="${TEST_FAIL_BT:-no}" TEST_NOTIFY_FAIL="${TEST_NOTIFY_FAIL:-no}" BSDRUNNER_WIRELESS_PATH="$test_root/bin:/usr/bin:/bin" BSDRUNNER_WIRELESS_STATE_DIR="$test_root/state" sh "$helper" "$@"
}
assert_value() { [ "$(cat "$test_root/$1")" = "$2" ] || { printf 'Unexpected %s state\n' "$1" >&2; exit 1; }; }
printf 'up\n' > "$test_root/wlan0"
printf 'down\n' > "$test_root/wlan1"
printf '1\n' > "$test_root/bluetooth"
run_toggle
assert_value wlan0 down
assert_value wlan1 down
assert_value bluetooth 0
[ -s "$test_root/notifications" ] || { printf 'Desktop notification was not sent\n' >&2; exit 1; }
run_toggle
assert_value wlan0 up
assert_value wlan1 down
assert_value bluetooth 1
[ ! -e "$test_root/state/restore.conf" ] || exit 1
printf '0\n' > "$test_root/bluetooth"
run_toggle
run_toggle
assert_value wlan0 up
assert_value bluetooth 0
printf '1\n' > "$test_root/bluetooth"
if TEST_FAIL_DOWN=yes run_toggle >/dev/null 2>&1; then
    printf 'Failure to disable Wi-Fi was not reported\n' >&2; exit 1
fi
assert_value wlan0 up
assert_value bluetooth 1
[ ! -e "$test_root/state/restore.conf" ] || exit 1
if TEST_FAIL_BT=yes run_toggle >/dev/null 2>&1; then
    printf 'Failure to disable Bluetooth was not reported\n' >&2; exit 1
fi
assert_value wlan0 up
assert_value bluetooth 1
[ ! -e "$test_root/state/restore.conf" ] || exit 1
run_toggle
if TEST_FAIL_UP=yes run_toggle >/dev/null 2>&1; then
    printf 'Failure to restore Wi-Fi was not reported\n' >&2; exit 1
fi
[ -e "$test_root/state/restore.conf" ] || { printf 'Restore state was lost after a failure\n' >&2; exit 1; }
run_toggle
assert_value wlan0 up
assert_value bluetooth 1
[ ! -e "$test_root/state/restore.conf" ] || exit 1
TEST_NOTIFY_FAIL=yes run_toggle
[ -s "$test_root/fallback-notifications" ] || { printf 'Hyprland notification fallback was not used\n' >&2; exit 1; }
run_toggle
cat > "$test_root/bin/record-toggle" <<'MOCK'
#!/bin/sh
printf 'toggle\n' >> "$TEST_ROOT/events"
MOCK
chmod 755 "$test_root/bin/record-toggle"
printf '%s\n' '!system=ACPI subsystem=IBM type=HKEY notify=0x05' '!system=ACPI subsystem=IBM type=HKEY notify=0x1b' '!system=ACPI subsystem=OTHER type=HKEY notify=0x05' | \
    env TEST_ROOT="$test_root" BSDRUNNER_WIRELESS_TOGGLE_SCRIPT="$test_root/bin/record-toggle" sh "$watcher" --events
[ "$(wc -l < "$test_root/events" | tr -d ' ')" = 1 ] || { printf 'Incorrect ACPI event matching\n' >&2; exit 1; }
printf 'Wireless toggle tests passed.\n'
