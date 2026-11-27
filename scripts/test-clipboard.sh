#!/bin/sh
set -eu
repo_root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
scripts_dir="$repo_root/dotfiles/.config/bsdrunner/scripts"
backend="$scripts_dir/bsdrunner-clipboard-backend.sh"
store="$scripts_dir/bsdrunner-clipboard-store.sh"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/bsdrunner-clipboard-tests.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT HUP INT TERM
mkdir -m 700 "$test_root/runtime" "$test_root/bin"
cat > "$test_root/bin/ps" <<'MOCK'
#!/bin/sh
if [ "${TEST_LOCKED:-no}" = yes ]; then printf 'S hyprlock\n'; else printf 'S other\n'; fi
MOCK
cat > "$test_root/bin/wl-copy" <<'MOCK'
#!/bin/sh
cat > "$TEST_ROOT/copied"
MOCK
chmod 755 "$test_root/bin/ps" "$test_root/bin/wl-copy"
test_env() {
    env XDG_RUNTIME_DIR="$test_root/runtime" TEST_ROOT="$test_root" CLIPBOARD_STATE="${CLIPBOARD_STATE:-data}" TEST_LOCKED="${TEST_LOCKED:-no}" \
        BSDRUNNER_CLIPBOARD_PATH="$test_root/bin:/usr/local/bin:/usr/bin:/bin:/sbin" "$@"
}
printf 'fixture clipboard text' | test_env sh "$store"
printf 'sensitive fixture' | CLIPBOARD_STATE=sensitive test_env sh "$store"
printf 'locked fixture' | TEST_LOCKED=yes test_env sh "$store"
snapshot="$(test_env sh "$backend" list)"
printf '%s\n' "$snapshot" | jq -e 'length == 1 and .[0].preview == "fixture clipboard text"' >/dev/null || { printf 'Clipboard history or sensitive filtering failed\n' >&2; exit 1; }
id="$(printf '%s\n' "$snapshot" | jq -r '.[0].id')"
test_env sh "$backend" copy "$id"
[ "$(cat "$test_root/copied")" = 'fixture clipboard text' ] || { printf 'Clipboard restore failed\n' >&2; exit 1; }
if test_env sh "$backend" copy 'invalid;id' >/dev/null 2>&1; then printf 'Invalid clipboard ID accepted\n' >&2; exit 1; fi
test_env sh "$backend" delete "$id"
[ "$(test_env sh "$backend" list | jq length)" = 0 ] || { printf 'Clipboard deletion failed\n' >&2; exit 1; }
printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+nmZkAAAAASUVORK5CYII=' | base64 -d > "$test_root/image.png"
test_env sh "$store" < "$test_root/image.png"
image_id="$(test_env sh "$backend" list | jq -r '.[0].id')"
test_env sh "$backend" copy "$image_id"
cmp -s "$test_root/image.png" "$test_root/copied" || { printf 'Clipboard image restore failed\n' >&2; exit 1; }
printf 'another fixture' | test_env sh "$store"
test_env sh "$backend" clear
[ "$(test_env sh "$backend" list | jq length)" = 0 ] || { printf 'Clipboard clear failed\n' >&2; exit 1; }
[ "$(stat -f '%Lp' "$test_root/runtime/bsdrunner-clipboard")" = 700 ] || { printf 'Clipboard directory permissions are not private\n' >&2; exit 1; }
grep -Fq 'hl.bind("F12",' "$repo_root/dotfiles/.config/hypr/hyprland.lua" || { printf 'F12 binding is missing\n' >&2; exit 1; }
printf 'Clipboard manager tests passed.\n'
