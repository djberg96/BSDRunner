#!/bin/sh

set -eu

system_root="/"
install_prefix="/usr/local"
login_profile=""
ly_tty="ttyv1"
enable_login=false

usage() {
    cat <<'EOF'
Usage: bsdrunner-install-ly.sh [--root DIR] [--prefix DIR] [--tty ttyvN]
                               [--profile FILE] [--enable]

Stages BSDRunner's FreeBSD getty capability for Ly. --enable also assigns Ly
to the selected virtual terminal for the next boot. It never reloads init or
starts Ly in the current graphical session.
EOF
}

fail() {
    echo ":: FAIL: $*" >&2
    exit 1
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
        --enable)
            enable_login=true
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

if [ "$system_root" = / ] && [ "$(id -u)" -ne 0 ]; then
    fail "System installation must run as root (use doas or sudo)"
fi

gettytab="$(root_path /etc/gettytab)"
ttys="$(root_path /etc/ttys)"
ly_wrapper="$install_prefix/bin/ly_wrapper"
ly_config="$install_prefix/etc/ly/config.ini"
ly_setup="$install_prefix/etc/ly/setup.sh"
hyprland_session="$install_prefix/share/wayland-sessions/hyprland.desktop"

[ -f "$gettytab" ] || fail "Missing $gettytab"
[ -f "$ttys" ] || fail "Missing $ttys"
[ -x "$ly_wrapper" ] || fail "Missing executable $ly_wrapper"
[ -f "$ly_config" ] || fail "Missing Ly configuration $ly_config"
[ -x "$ly_setup" ] || fail "Missing executable $ly_setup"
[ -f "$hyprland_session" ] || fail "Missing Hyprland session $hyprland_session"

[ "$(awk -v tty="$ly_tty" '$1 == tty { count++ } END { print count + 0 }' "$ttys")" -eq 1 ] || \
    fail "Expected exactly one $ly_tty entry in $ttys"

if [ "$system_root" = / ] && [ "$install_prefix" = /usr/local ]; then
    pkg info ly >/dev/null 2>&1 || fail "Required package is not installed: ly"
fi

if [ "$enable_login" = true ]; then
    [ -n "$login_profile" ] && [ -f "$login_profile" ] || \
        fail "--enable requires --profile with the desktop user's .profile"
    login_zprofile="$(dirname -- "$login_profile")/.zprofile"
    if profile_has_console_autostart "$login_profile" || \
        profile_has_console_autostart "$login_zprofile"; then
        fail "A console autostart remains; run bsdrunner-disable-console-autostart.sh first"
    fi

    ttyv0_line="$(awk '$1 == "ttyv0" { print }' "$ttys")"
    printf '%s\n' "$ttyv0_line" | grep -F '/usr/libexec/getty Pc' >/dev/null || \
        fail "ttyv0 is not an ordinary recovery console"
    printf '%s\n' "$ttyv0_line" | grep -Eq '[[:space:]]on(ifexists)?[[:space:]]+secure([[:space:]]|$)' || \
        fail "ttyv0 is not enabled as a secure recovery console"
    other_ly_ttys="$(awk -v tty="$ly_tty" '$1 != tty && /\/usr\/libexec\/getty BSDRunnerLy/ { print $1 }' "$ttys")"
    [ -z "$other_ly_ttys" ] || \
        fail "BSDRunnerLy is already assigned to another TTY: $other_ly_ttys"

    if [ "$system_root" = / ]; then
        [ "$(sysrc -n dbus_enable 2>/dev/null || true)" = YES ] || \
            fail "dbus_enable must be YES before enabling Ly"
        [ "$(sysrc -n seatd_enable 2>/dev/null || true)" = YES ] || \
            fail "seatd_enable must be YES before enabling Ly"
        if pgrep -x ly >/dev/null 2>&1; then
            fail "Ly is already running; refusing to alter its active TTY"
        fi
    fi
fi

backup_once() {
    target="$1"
    [ -e "${target}.pre-bsdrunner-ly" ] || cp -p "$target" "${target}.pre-bsdrunner-ly"
}

backup_once "$gettytab"

temporary_gettytab="$(mktemp "${TMPDIR:-/tmp}/bsdrunner-gettytab.XXXXXX")"
awk '
    BEGIN { managed = 0 }
    /^# >>> BSDRUNNER LY GETTY >>>$/ { managed = 1; next }
    /^# <<< BSDRUNNER LY GETTY <<<$/{ managed = 0; next }
    !managed { print }
' "$gettytab" > "$temporary_gettytab"

if grep -Eq '^BSDRunnerLy([|:]|$)' "$temporary_gettytab"; then
    rm -f "$temporary_gettytab"
    fail "An unmanaged BSDRunnerLy capability already exists in $gettytab"
fi

{
    cat "$temporary_gettytab"
    printf '%s\n' \
        '# >>> BSDRUNNER LY GETTY >>>' \
        'BSDRunnerLy:\' \
        "\t:lo=$ly_wrapper:\\" \
        '\t:al=root:' \
        '# <<< BSDRUNNER LY GETTY <<<'
} > "${temporary_gettytab}.new"
install -m 644 "${temporary_gettytab}.new" "$gettytab"
rm -f "$temporary_gettytab" "${temporary_gettytab}.new"

if [ "$enable_login" = true ]; then
    backup_once "$ttys"
    temporary_ttys="$(mktemp "${TMPDIR:-/tmp}/bsdrunner-ttys.XXXXXX")"
    awk -v tty="$ly_tty" '
        $1 == tty {
            printf "%s\t\"/usr/libexec/getty BSDRunnerLy\"\txterm\tonifexists secure\n", tty
            next
        }
        { print }
    ' "$ttys" > "$temporary_ttys"
    install -m 644 "$temporary_ttys" "$ttys"
    rm -f "$temporary_ttys"

    if [ "$system_root" = / ]; then
        sysrc lightdm_enable=NO >/dev/null
        sysrc greetd_enable=NO >/dev/null
    fi
fi

echo ":: Installed the BSDRunner Ly getty capability"
if [ "$enable_login" = true ]; then
    echo ":: Ly will use $ly_tty after the next reboot; init was not reloaded"
    echo ":: ttyv0 remains an ordinary recovery console"
else
    echo ":: Ly was not assigned to a TTY; run the preflight before activation"
fi
