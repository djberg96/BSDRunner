#!/bin/sh

set -eu

install_prefix="/usr/local"
login_profile=""
activation_ready=false

usage() {
    cat <<'EOF'
Usage: bsdrunner-preflight-lightdm.sh [--prefix DIR] [--profile FILE] [--activation-ready]

Validates a staged BSDRunner LightDM installation without starting LightDM or
changing any system state. --activation-ready also requires a profile whose
old ttyv0 Hyprland autostart has already been removed.
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

while [ "$#" -gt 0 ]; do
    case "$1" in
        --prefix)
            [ "$#" -ge 2 ] || fail "Missing value for $1"
            install_prefix="$2"
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

lightdm_conf="$install_prefix/etc/lightdm/lightdm.conf.d/50-bsdrunner.conf"
greeter_conf="$install_prefix/etc/lightdm/lightdm-gtk-greeter.conf"
greeter_wrapper="$install_prefix/share/bsdrunner/lightdm/bsdrunner-lightdm-gtk-greeter"
picker="$install_prefix/share/bsdrunner/lightdm/pick-random-wallpaper.sh"
xgreeter="$install_prefix/share/xgreeters/bsdrunner-lightdm-gtk-greeter.desktop"
greeter_binary="$install_prefix/sbin/lightdm-gtk-greeter"
hyprland_session="$install_prefix/share/wayland-sessions/hyprland.desktop"

for required_file in "$lightdm_conf" "$greeter_conf" "$xgreeter"; do
    [ -f "$required_file" ] || fail "Missing $required_file"
done
for required_executable in "$greeter_wrapper" "$picker" "$greeter_binary"; do
    [ -x "$required_executable" ] || fail "Missing executable $required_executable"
done
[ -f "$hyprland_session" ] || fail "Missing Hyprland session entry $hyprland_session"
pass "all LightDM, greeter, and Hyprland session files are present"

expected_exec="Exec=$install_prefix/share/bsdrunner/lightdm/bsdrunner-lightdm-gtk-greeter"
grep -Fx "$expected_exec" "$xgreeter" >/dev/null || \
    fail "The xgreeter entry does not launch the installed BSDRunner wrapper"
grep -Fx "greeter-session=bsdrunner-lightdm-gtk-greeter" "$lightdm_conf" >/dev/null || \
    fail "The BSDRunner greeter is not selected"
grep -Fx "user-session=hyprland" "$lightdm_conf" >/dev/null || \
    fail "Hyprland is not the default user session"
pass "greeter and Hyprland session selection is consistent"

if [ "$install_prefix" = /usr/local ]; then
    pkg info lightdm >/dev/null 2>&1 || fail "Package is not installed: lightdm"
    pkg info lightdm-gtk-greeter >/dev/null 2>&1 || \
        fail "Package is not installed: lightdm-gtk-greeter"
    [ "$(sysrc -n dbus_enable 2>/dev/null || true)" = YES ] || \
        fail "dbus_enable is not YES"
    [ "$(sysrc -n seatd_enable 2>/dev/null || true)" = YES ] || \
        fail "seatd_enable is not YES"
    if service lightdm status >/dev/null 2>&1; then
        fail "LightDM is already running; staged validation must not take over the current seat"
    fi

    combined_config="$(/usr/local/sbin/lightdm --show-config 2>&1)" || \
        fail "LightDM rejected the combined configuration"
    printf '%s\n' "$combined_config" | \
        grep -F 'greeter-session=bsdrunner-lightdm-gtk-greeter' >/dev/null || \
        fail "Combined LightDM config does not select the BSDRunner greeter"
    printf '%s\n' "$combined_config" | grep -F 'user-session=hyprland' >/dev/null || \
        fail "Combined LightDM config does not select Hyprland"
    pass "LightDM accepts the combined configuration while stopped"
fi

if [ "$activation_ready" = true ]; then
    [ -n "$login_profile" ] && [ -f "$login_profile" ] || \
        fail "--activation-ready requires --profile FILE"
    login_zprofile="$(dirname -- "$login_profile")/.zprofile"
    profile_has_console_autostart "$login_profile" && \
        fail "A BSDRunner console autostart remains in $login_profile"
    profile_has_console_autostart "$login_zprofile" && \
        fail "A BSDRunner console autostart remains in $login_zprofile"
    pass "console login will return a recovery shell"
elif [ -n "$login_profile" ] && [ -f "$login_profile" ]; then
    login_zprofile="$(dirname -- "$login_profile")/.zprofile"
    if profile_has_console_autostart "$login_profile" || \
        profile_has_console_autostart "$login_zprofile"; then
        echo ":: NOTE: A console autostart remains active; staging is safe, activation is not ready."
    fi
fi

echo ":: LightDM preflight completed without starting or enabling it."
