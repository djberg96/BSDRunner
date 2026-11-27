#!/bin/sh
set -eu
repo_root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
backend="$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-notifications-backend.sh"
watcher="$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-thinkpad-notifications-watch.sh"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/bsdrunner-notifications-tests.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT HUP INT TERM
mkdir -p "$test_root/bin"
cat > "$test_root/bin/makoctl" <<'MOCK'
#!/bin/sh
if [ "${TEST_MAKO_FAIL:-no}" = yes ]; then printf 'invalid\n'; exit 0; fi
case "$1" in
  list) printf '%s\n' '[{"id":1,"app_name":"Example","summary":"Current","body":"Hello"}]' ;;
  history) printf '%s\n' '[{"id":2,"app_name":"Example","summary":"Earlier","body":"World"}]' ;;
  *) exit 1 ;;
esac
MOCK
cat > "$test_root/bin/dbus-send" <<'MOCK'
#!/bin/sh
exit 1
MOCK
cat > "$test_root/bin/ps" <<'MOCK'
#!/bin/sh
if [ "${TEST_LOCKED:-no}" = yes ]; then printf 'S hyprlock\n'; else printf 'S other\n'; fi
MOCK
cat > "$test_root/bin/launcher" <<'MOCK'
#!/bin/sh
printf 'opened\n' >> "$TEST_ROOT/launches"
MOCK
chmod 755 "$test_root/bin/"*
run_backend() {
    env TEST_MAKO_FAIL="${TEST_MAKO_FAIL:-no}" BSDRUNNER_MAKOCTL_BIN="$test_root/bin/makoctl" BSDRUNNER_NOTIFICATIONS_PATH="$test_root/bin:/usr/local/bin:/usr/bin:/bin" sh "$backend"
}
snapshot="$(run_backend)"
printf '%s\n' "$snapshot" | jq -e '.ok == true and (.notifications | length == 2) and .notifications[0].title == "Current" and .notifications[0].status == "Active" and .notifications[1].title == "Earlier" and .notifications[1].status == "Recent"' >/dev/null || { printf 'Mako snapshot was not parsed correctly\n' >&2; exit 1; }
TEST_MAKO_FAIL=yes run_backend | jq -e '.ok == false and (.notifications | length == 0)' >/dev/null || { printf 'Unavailable Mako was not reported\n' >&2; exit 1; }
run_events() {
    printf '%s\n' '!system=ACPI subsystem=IBM type=HKEY notify=0x17' '!system=ACPI subsystem=IBM type=HKEY notify=0x05' '!system=ACPI subsystem=OTHER type=HKEY notify=0x17' | \
        env TEST_ROOT="$test_root" TEST_LOCKED="${TEST_LOCKED:-no}" BSDRUNNER_NOTIFICATION_LAUNCHER="$test_root/bin/launcher" BSDRUNNER_NOTIFICATION_WATCH_PATH="$test_root/bin:/usr/bin:/bin" sh "$watcher" --events
}
run_events
[ "$(wc -l < "$test_root/launches" | tr -d ' ')" = 1 ] || { printf 'Incorrect hotkey event matching\n' >&2; exit 1; }
TEST_LOCKED=yes run_events
[ "$(wc -l < "$test_root/launches" | tr -d ' ')" = 1 ] || { printf 'Notification center opened during lock\n' >&2; exit 1; }
printf 'Notification center tests passed.\n'
