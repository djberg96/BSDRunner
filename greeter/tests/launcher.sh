#!/bin/sh

set -eu

if [ "${BSDRUNNER_LAUNCHER_TEST_CHILD:-}" = 1 ]; then
    [ -n "${XDG_RUNTIME_DIR:-}" ]
    [ -d "$XDG_RUNTIME_DIR" ]
    [ ! -L "$XDG_RUNTIME_DIR" ]
    [ -O "$XDG_RUNTIME_DIR" ]
    printf '%s\n' "$XDG_RUNTIME_DIR" \
        >"$BSDRUNNER_LAUNCHER_TEST_ROOT/$BSDRUNNER_LAUNCHER_TEST_CASE.runtime"
    exit 0
fi

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)"
launcher="$repo_root/greeter/start-greeter-hyprland.sh"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/bsdrunner-launcher-test.XXXXXX")"

cleanup() {
    rm -rf -- "$test_root"
}
trap cleanup EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 143' TERM

mkdir -p \
    "$test_root/bin" \
    "$test_root/logs" \
    "$test_root/tmp" \
    "$test_root/existing-runtime"
chmod 700 "$test_root/logs" "$test_root/existing-runtime"
ln -s "$repo_root/greeter/tests/launcher.sh" "$test_root/bin/start-hyprland"
ln -s "$test_root/existing-runtime" "$test_root/symlink-runtime"

run_launcher() {
    test_case="$1"
    shift
    env "$@" \
        BSDRUNNER_GREETER_LOG_ROOT="$test_root/logs" \
        BSDRUNNER_LAUNCHER_TEST_CASE="$test_case" \
        BSDRUNNER_LAUNCHER_TEST_CHILD=1 \
        BSDRUNNER_LAUNCHER_TEST_ROOT="$test_root" \
        TMPDIR="$test_root/tmp" \
        PATH="$test_root/bin:/bin:/usr/bin:/usr/local/bin" \
        "$launcher"
}

run_launcher fallback -u XDG_RUNTIME_DIR
run_launcher existing XDG_RUNTIME_DIR="$test_root/existing-runtime"
run_launcher symlink XDG_RUNTIME_DIR="$test_root/symlink-runtime"

fallback_runtime="$(sed -n '1p' "$test_root/fallback.runtime")"
existing_runtime="$(sed -n '1p' "$test_root/existing.runtime")"
symlink_runtime="$(sed -n '1p' "$test_root/symlink.runtime")"

[ ! -e "$fallback_runtime" ]
case "$fallback_runtime" in
    /tmp/bsdg.*) ;;
    *) exit 1 ;;
esac
[ "${#fallback_runtime}" -lt 32 ]
[ "$existing_runtime" = "$test_root/existing-runtime" ]
[ -d "$existing_runtime" ]
[ "$symlink_runtime" != "$test_root/symlink-runtime" ]
[ ! -e "$symlink_runtime" ]

log_count="$(find "$test_root/logs" -maxdepth 1 -type d \
    -name 'bsdrunner-greeter-log.*' | wc -l | tr -d ' ')"
[ "$log_count" = 3 ]

for log_dir in "$test_root"/logs/bsdrunner-greeter-log.*; do
    mode="$(stat -f '%Lp' "$log_dir" 2>/dev/null || stat -c '%a' "$log_dir")"
    [ "$mode" = 700 ]
    grep -Fx 'Hyprland exit status=0' "$log_dir/launcher.log" >/dev/null
done

printf '%s\n' 'launcher tests passed'
