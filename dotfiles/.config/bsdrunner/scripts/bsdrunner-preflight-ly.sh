#!/bin/sh

set -eu

system_root="/"
install_prefix="/usr/local"
login_profile=""
ly_tty="ttyv1"
activation_ready=false

usage() {
    cat <<'EOF'
Usage: bsdrunner-preflight-ly.sh [--root DIR] [--prefix DIR] [--tty ttyvN]
                                 [--profile FILE] [--activation-ready]

Validates Ly without starting it, reloading init, or changing system state.
EOF
}

fail() {
    echo ":: FAIL: $*" >&2
    exit 1
}

pass() {
    echo ":: PASS: $*"
}

profile_has_console_autostart() {
    candidate="$1"
    [ -f "$candidate" ] || return 1
    grep -Eq 'BSDRUNNER GREETER AUTOSTART|bsdrunner-login-dispatch\.sh|^[[:space:]]*exec[[:space:]]+start-hyprland([[:space:]]|$)' "$candidate"
}

root_path() {
    if [ "$system_root" = / ]; then
        printf '%s\n' "$1"
    else
        printf '%s%s\n' "${system_root%/}" "$1"
    fi
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --root)
            [ "$#" -ge 2 ] || fail "Missing value for $1"
            system_root="$2"
            shift
            ;;
        --prefix)
            [ "$#" -ge 2 ] || fail "Missing value for $1"
            install_prefix="$2"
            shift
            ;;
        --tty)
            [ "$#" -ge 2 ] || fail "Missing value for $1"
            ly_tty="$2"
            shift
            ;;
        --profile)
            [ "$#" -ge 2 ] || fail "Missing value for $1"
            login_profile="$2"
            shift
            ;;
        --activation-ready)
            activation_ready=true
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo ":: Unknown argument: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
    shift
done

case "$ly_tty" in
    ttyv[1-7]) ;;
    *) fail "Ly TTY must be ttyv1 through ttyv7; ttyv0 is reserved for recovery" ;;
esac

gettytab="$(root_path /etc/gettytab)"
ttys="$(root_path /etc/ttys)"
ly_binary="$install_prefix/bin/ly"
ly_wrapper="$install_prefix/bin/ly_wrapper"
ly_config="$install_prefix/etc/ly/config.ini"
ly_setup="$install_prefix/etc/ly/setup.sh"
hyprland_session="$install_prefix/share/wayland-sessions/hyprland.desktop"

[ -x "$ly_binary" ] || fail "Missing executable $ly_binary"
[ -x "$ly_wrapper" ] || fail "Missing executable $ly_wrapper"
[ -f "$ly_config" ] || fail "Missing Ly configuration $ly_config"
[ -x "$ly_setup" ] || fail "Missing executable $ly_setup"
grep -Fx "setup_cmd = $ly_setup" "$ly_config" >/dev/null || \
    fail "Ly configuration does not select $ly_setup"
grep -Fx "waylandsessions = $install_prefix/share/wayland-sessions" "$ly_config" >/dev/null || \
    fail "Ly configuration does not scan the packaged Wayland sessions"
[ -f "$hyprland_session" ] || fail "Missing Hyprland session $hyprland_session"
grep -Eq '^Exec=.*/start-hyprland([[:space:]]|$)' "$hyprland_session" || \
    fail "Hyprland session does not launch start-hyprland"
pass "Ly and the Hyprland Wayland session are installed"

[ -f "$gettytab" ] || fail "Missing $gettytab"
[ "$(grep -c '^# >>> BSDRUNNER LY GETTY >>>$' "$gettytab")" -eq 1 ] || \
    fail "BSDRunner Ly getty block is missing or duplicated"
[ "$(grep -c '^# <<< BSDRUNNER LY GETTY <<<$' "$gettytab")" -eq 1 ] || \
    fail "BSDRunner Ly getty block is malformed"
grep -Eq '^BSDRunnerLy:\\$' "$gettytab" || fail "BSDRunnerLy capability is missing"
grep -F ":lo=$ly_wrapper:" "$gettytab" >/dev/null || \
    fail "BSDRunnerLy capability does not launch $ly_wrapper"
pass "BSDRunner Ly getty capability is staged"

if [ "$system_root" = / ] && [ "$install_prefix" = /usr/local ]; then
    pkg info ly >/dev/null 2>&1 || fail "Package is not installed: ly"
    [ "$(sysrc -n dbus_enable 2>/dev/null || true)" = YES ] || fail "dbus_enable is not YES"
    [ "$(sysrc -n seatd_enable 2>/dev/null || true)" = YES ] || fail "seatd_enable is not YES"
    if pgrep -x ly >/dev/null 2>&1; then
        fail "Ly is already running; preflight must not inspect an active login manager"
    fi
fi

if [ "$activation_ready" = true ]; then
    [ -n "$login_profile" ] && [ -f "$login_profile" ] || \
        fail "--activation-ready requires --profile FILE"
    login_zprofile="$(dirname -- "$login_profile")/.zprofile"
    profile_has_console_autostart "$login_profile" && \
        fail "A BSDRunner console autostart remains in $login_profile"
    profile_has_console_autostart "$login_zprofile" && \
        fail "A BSDRunner console autostart remains in $login_zprofile"

    [ -f "$ttys" ] || fail "Missing $ttys"
    expected_tty_line="$ly_tty\t\"/usr/libexec/getty BSDRunnerLy\"\txterm\tonifexists secure"
    [ "$(awk -v tty="$ly_tty" '$1 == tty { print }' "$ttys")" = "$(printf '%b' "$expected_tty_line")" ] || \
        fail "$ly_tty is not assigned exclusively to BSDRunnerLy"
    [ "$(grep -c '/usr/libexec/getty BSDRunnerLy' "$ttys")" -eq 1 ] || \
        fail "BSDRunnerLy must be assigned to exactly one TTY"
    [ "$(awk '$1 == "ttyv0" { count++ } END { print count + 0 }' "$ttys")" -eq 1 ] || \
        fail "Expected exactly one ttyv0 recovery entry"
    ttyv0_line="$(awk '$1 == "ttyv0" { print }' "$ttys")"
    printf '%s\n' "$ttyv0_line" | grep -F '/usr/libexec/getty Pc' >/dev/null || \
        fail "ttyv0 is not an ordinary recovery console"
    printf '%s\n' "$ttyv0_line" | grep -Eq '[[:space:]]on(ifexists)?[[:space:]]+secure([[:space:]]|$)' || \
        fail "ttyv0 recovery console is not enabled"

    if [ "$system_root" = / ]; then
        [ "$(sysrc -n lightdm_enable 2>/dev/null || true)" = NO ] || \
            fail "lightdm_enable must be NO"
        [ "$(sysrc -n greetd_enable 2>/dev/null || true)" = NO ] || \
            fail "greetd_enable must be NO"
    fi
    pass "Ly owns $ly_tty for the next boot and ttyv0 remains a recovery console"
fi

echo ":: Ly preflight completed without starting it or reloading init."
