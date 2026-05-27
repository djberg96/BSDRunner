#!/bin/sh

set -eu

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
test_root="$(mktemp -d "${TMPDIR:-/tmp}/bsdrunner-lightdm-tests.XXXXXX")"
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

pass() {
    echo "PASS: $*"
}

test_home="$test_root/home"
bundle="$test_root/bundle"
prefix="$test_root/usr/local"
mkdir -p "$test_home"

HOME="$test_home" sh \
    "$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-render-lightdm.sh" \
    --output "$bundle" --prefix "$prefix"

[ -f "$bundle/.bsdrunner-lightdm-bundle" ] || fail "renderer marker is missing"
grep -Fx 'user-session=hyprland' \
    "$bundle/etc/lightdm/lightdm.conf.d/50-bsdrunner.conf" >/dev/null || \
    fail "Hyprland is not the default LightDM session"
grep -F "Exec=$prefix/share/bsdrunner/lightdm/bsdrunner-lightdm-gtk-greeter" \
    "$bundle/share/xgreeters/bsdrunner-lightdm-gtk-greeter.desktop" >/dev/null || \
    fail "greeter desktop entry has the wrong prefix"
pass "renderer creates a complete prefixed bundle"

HOME="$test_home" sh \
    "$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-render-lightdm.sh" \
    --output "$bundle" --prefix "$prefix" >/dev/null
pass "renderer can safely refresh its own bundle"

unmanaged_output="$test_root/unmanaged"
mkdir -p "$unmanaged_output"
printf '%s\n' 'not a BSDRunner bundle' > "$unmanaged_output/keep"
if HOME="$test_home" sh \
    "$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-render-lightdm.sh" \
    --output "$unmanaged_output" --prefix "$prefix" >/dev/null 2>&1; then
    fail "renderer replaced an unmanaged directory"
fi
[ -f "$unmanaged_output/keep" ] || fail "renderer damaged an unmanaged directory"
pass "renderer refuses unmanaged output directories"

sh "$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-install-lightdm.sh" \
    --bundle "$bundle" --prefix "$prefix"

[ -x "$prefix/share/bsdrunner/lightdm/bsdrunner-lightdm-gtk-greeter" ] || \
    fail "greeter wrapper was not installed executable"
[ -f "$prefix/etc/lightdm/lightdm-gtk-greeter.conf" ] || \
    fail "greeter config was not installed"
[ -f "$prefix/share/xgreeters/bsdrunner-lightdm-gtk-greeter.desktop" ] || \
    fail "xgreeter entry was not installed"
pass "installer copies every required LightDM component"

refused_prefix="$test_root/refused-prefix"
if sh "$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-install-lightdm.sh" \
    --bundle "$bundle" --prefix "$refused_prefix" --enable >/dev/null 2>&1; then
    fail "installer enabled a non-system prefix"
fi
[ ! -e "$refused_prefix" ] || fail "failed installer changed its target prefix"
pass "installer performs enablement checks before writing"

profile_home="$test_root/profile-home"
profile="$profile_home/.profile"
mkdir -p "$profile_home"
printf '%s\n' \
    'export EDITOR=vi' \
    'if [ -z "${SSH_CONNECTION:-}" ] && [ "$(tty)" = "/dev/ttyv0" ]; then' \
    '  export XDG_RUNTIME_DIR="/var/run/user/$(id -u)"' \
    '  exec start-hyprland' \
    'fi' \
    '. "$HOME/.cargo/env"' > "$profile"

HOME="$profile_home" sh \
    "$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-disable-console-autostart.sh" \
    --check >/dev/null
HOME="$profile_home" sh \
    "$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-disable-console-autostart.sh" \
    >/dev/null

grep -F 'exec start-hyprland' "$profile" >/dev/null && \
    fail "console autostart remains in the migrated profile"
grep -F '. "$HOME/.cargo/env"' "$profile" >/dev/null || \
    fail "profile migration removed unrelated content"
grep -F 'exec start-hyprland' "$profile.pre-bsdrunner-lightdm" >/dev/null || \
    fail "profile backup does not contain the original block"
pass "profile migration removes only the ttyv0 autostart block"

if grep -F 'vidcontrol' "$repo_root/dotfiles/.config/wlogout/layout" >/dev/null; then
    fail "logout still forces a VT switch"
fi
pass "logout lets LightDM reclaim the seat"

echo "All LightDM tests passed."
