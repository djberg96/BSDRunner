#!/bin/sh
set -eu

repo_root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
helper="$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-brightness-step.sh"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/bsdrunner-brightness-tests.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT HUP INT TERM
mkdir -p "$test_root/bin"

cat > "$test_root/bin/uname" <<'MOCK'
#!/bin/sh
printf 'FreeBSD\n'
MOCK
cat > "$test_root/bin/backlight" <<'MOCK'
#!/bin/sh
if [ "$1" = -q ]; then
    cat "$BRIGHTNESS_TEST_STATE"
else
    printf '%s\n' "$1" > "$BRIGHTNESS_TEST_STATE"
fi
MOCK
chmod 755 "$test_root/bin/uname" "$test_root/bin/backlight"
run_helper() {
    env PATH="$test_root/bin:/usr/bin:/bin" BRIGHTNESS_TEST_STATE="$test_root/state" sh "$helper" "$1"
}
assert_level() {
    [ "$(cat "$test_root/state")" = "$1" ] || { printf 'unexpected brightness, expected %s\n' "$1" >&2; exit 1; }
}
printf '32\n' > "$test_root/state"
run_helper up
assert_level 37
run_helper down
assert_level 32
printf '98\n' > "$test_root/state"
run_helper up
assert_level 100
printf '7\n' > "$test_root/state"
run_helper down
assert_level 5
if run_helper invalid >/dev/null 2>&1; then
    printf 'invalid brightness action accepted\n' >&2; exit 1
fi
printf 'Brightness control tests passed.\n'
