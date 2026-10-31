#!/bin/sh

set -eu

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/bsdrunner-ly-tests.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

pass() {
    echo "PASS: $*"
}

system_root="$test_root/root"
prefix="$test_root/usr/local"
profile_home="$test_root/home"
profile="$profile_home/.profile"

mkdir -p "$system_root/etc" "$prefix/bin" "$prefix/etc/ly" \
    "$prefix/share/wayland-sessions" "$profile_home"
printf '%s\n' \
    'default:\' \
    '\t:cb:ce:ck:lc:fd#1000:im=\\r\\n%s/%m (%h) (%t)\\r\\n\\r\\n:sp#1200:' \
    > "$system_root/etc/gettytab"
printf '%s\n' \
    'ttyv0  "/usr/libexec/getty Pc"  xterm  onifexists secure' \
    'ttyv1  "/usr/libexec/getty Pc"  xterm  onifexists secure' \
    'ttyv2  "/usr/libexec/getty Pc"  xterm  onifexists secure' \
    > "$system_root/etc/ttys"
printf '%s\n' '#!/bin/sh' 'exit 0' > "$prefix/bin/ly"
printf '%s\n' '#!/bin/sh' 'exec "$(dirname "$0")/ly"' > "$prefix/bin/ly_wrapper"
chmod 755 "$prefix/bin/ly" "$prefix/bin/ly_wrapper"
printf '%s\n' \
    "setup_cmd = $prefix/etc/ly/setup.sh" \
    "waylandsessions = $prefix/share/wayland-sessions" \
    'save = true' > "$prefix/etc/ly/config.ini"
printf '%s\n' '#!/bin/sh' 'exec "$@"' > "$prefix/etc/ly/setup.sh"
chmod 755 "$prefix/etc/ly/setup.sh"
printf '%s\n' \
    '[Desktop Entry]' \
    'Name=Hyprland' \
    "Exec=$prefix/bin/start-hyprland" \
    'Type=Application' \
    > "$prefix/share/wayland-sessions/hyprland.desktop"
printf '%s\n' 'export EDITOR=vi' > "$profile"
printf '\n' > "$profile_home/.zprofile"

installer="$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-install-ly.sh"
preflight="$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-preflight-ly.sh"

sh "$installer" --root "$system_root" --prefix "$prefix" >/dev/null
grep -F '# >>> BSDRUNNER LY GETTY >>>' "$system_root/etc/gettytab" >/dev/null || \
    fail "installer did not stage the getty capability"
grep -F '/usr/libexec/getty BSDRunnerLy' "$system_root/etc/ttys" >/dev/null && \
    fail "staging unexpectedly assigned Ly to a TTY"
sh "$preflight" --root "$system_root" --prefix "$prefix" >/dev/null
if command -v cap_mkdb >/dev/null 2>&1; then
    cap_mkdb -f "$test_root/gettytab.db" "$system_root/etc/gettytab"
fi
pass "staging adds the Ly capability without changing a TTY"

sh "$installer" --root "$system_root" --prefix "$prefix" \
    --profile "$profile" --enable >/dev/null
sh "$preflight" --root "$system_root" --prefix "$prefix" \
    --profile "$profile" --activation-ready >/dev/null
grep -F 'ttyv0  "/usr/libexec/getty Pc"' "$system_root/etc/ttys" >/dev/null || \
    fail "activation changed the recovery console"
grep -F 'ttyv1' "$system_root/etc/ttys" | grep -F '/usr/libexec/getty BSDRunnerLy' >/dev/null || \
    fail "activation did not assign Ly to ttyv1"
pass "activation assigns only ttyv1 and preserves ttyv0 recovery"

sh "$installer" --root "$system_root" --prefix "$prefix" \
    --profile "$profile" --enable >/dev/null
[ "$(grep -c '^# >>> BSDRUNNER LY GETTY >>>$' "$system_root/etc/gettytab")" -eq 1 ] || \
    fail "repeated installation duplicated the managed getty block"
pass "installer is idempotent"

stale_root="$test_root/stale-root"
mkdir -p "$stale_root/etc"
cp "$system_root/etc/gettytab.pre-bsdrunner-ly" "$stale_root/etc/gettytab"
cp "$system_root/etc/ttys.pre-bsdrunner-ly" "$stale_root/etc/ttys"
printf '%s\n' \
    'if [ "$(tty)" = /dev/ttyv0 ]; then' \
    '  exec start-hyprland' \
    'fi' > "$profile_home/stale-profile"
if sh "$installer" --root "$stale_root" --prefix "$prefix" \
    --profile "$profile_home/stale-profile" --enable >/dev/null 2>&1; then
    fail "installer accepted a stale console autostart"
fi
cmp -s "$stale_root/etc/ttys" "$system_root/etc/ttys.pre-bsdrunner-ly" || \
    fail "failed activation changed ttys"
pass "activation refuses stale console autostart before writing"

migration_home="$test_root/migration-home"
migration_profile="$migration_home/.profile"
mkdir -p "$migration_home"
printf '%s\n' \
    '# >>> BSDRUNNER GREETER AUTOSTART >>>' \
    '"$HOME/.config/bsdrunner/scripts/bsdrunner-login-dispatch.sh"' \
    '# <<< BSDRUNNER GREETER AUTOSTART <<<' \
    'export EDITOR=vi' \
    'if [ "$(tty)" = /dev/ttyv0 ]; then' \
    '  exec start-hyprland' \
    'fi' > "$migration_profile"
printf '\n' > "$migration_home/.zprofile"
HOME="$migration_home" sh \
    "$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-disable-console-autostart.sh" \
    --profile "$migration_profile" --zprofile "$migration_home/.zprofile" >/dev/null
grep -F 'exec start-hyprland' "$migration_profile" >/dev/null && \
    fail "profile migration left a direct Hyprland autostart"
grep -F 'bsdrunner-login-dispatch.sh' "$migration_profile" >/dev/null && \
    fail "profile migration left the old greeter dispatcher"
[ -f "$migration_profile.pre-bsdrunner-ly" ] || \
    fail "profile migration did not retain a Ly-named backup"
pass "profile migration removes old autostart and retains a Ly backup"

cp "$system_root/etc/gettytab.pre-bsdrunner-ly" "$test_root/expected-gettytab"
cp "$system_root/etc/ttys.pre-bsdrunner-ly" "$test_root/expected-ttys"
sh "$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-rollback-ly.sh" \
    --root "$system_root" >/dev/null
cmp -s "$system_root/etc/gettytab" "$test_root/expected-gettytab" || \
    fail "rollback did not restore gettytab"
cmp -s "$system_root/etc/ttys" "$test_root/expected-ttys" || \
    fail "rollback did not restore ttys"
pass "rollback restores the original gettytab and ttys"

if grep -F 'vidcontrol' "$repo_root/dotfiles/.config/wlogout/layout" >/dev/null; then
    fail "logout still forces a VT switch"
fi
pass "logout lets Ly reclaim the session naturally"

echo "All Ly tests passed."
