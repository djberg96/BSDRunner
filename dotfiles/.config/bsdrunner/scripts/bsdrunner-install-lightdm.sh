#!/bin/sh

set -eu

install_prefix="/usr/local"
bundle_root=""
login_profile=""
enable_service=false

usage() {
    cat <<'EOF'
Usage: bsdrunner-install-lightdm.sh --bundle DIR [--profile FILE] [--prefix DIR] [--enable]

Installs a rendered BSDRunner LightDM bundle. --enable updates rc.conf for the
next boot, but this script deliberately does not start LightDM in the current
graphical session.
EOF
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --bundle)
            [ "$#" -ge 2 ] || {
                echo ":: Missing value for $1" >&2
                exit 1
            }
            bundle_root="$2"
            shift
            ;;
        --prefix)
            [ "$#" -ge 2 ] || {
                echo ":: Missing value for $1" >&2
                exit 1
            }
            install_prefix="$2"
            shift
            ;;
        --profile)
            [ "$#" -ge 2 ] || {
                echo ":: Missing value for $1" >&2
                exit 1
            }
            login_profile="$2"
            shift
            ;;
        --enable)
            enable_service=true
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

[ -n "$bundle_root" ] || {
    echo ":: --bundle is required" >&2
    usage >&2
    exit 1
}

if [ "$install_prefix" = /usr/local ] && [ "$(id -u)" -ne 0 ]; then
    echo ":: System installation must run as root (use doas or sudo)." >&2
    exit 1
fi

required_bundle_files="
etc/lightdm/lightdm.conf.d/50-bsdrunner.conf
etc/lightdm/lightdm-gtk-greeter.conf
share/bsdrunner/lightdm/bsdrunner-lightdm-gtk-greeter
share/bsdrunner/lightdm/pick-random-wallpaper.sh
share/xgreeters/bsdrunner-lightdm-gtk-greeter.desktop
"

for relative_path in $required_bundle_files; do
    [ -f "$bundle_root/$relative_path" ] || {
        echo ":: Incomplete LightDM bundle; missing $relative_path" >&2
        exit 1
    }
done

find "$bundle_root/share/bsdrunner/lightdm/backgrounds" -type f -maxdepth 1 2>/dev/null | \
    grep -q . || {
        echo ":: The LightDM bundle contains no backgrounds." >&2
        exit 1
    }

if [ "$install_prefix" = /usr/local ]; then
    pkg info lightdm >/dev/null 2>&1 || {
        echo ":: Required package is not installed: lightdm" >&2
        exit 1
    }
    pkg info lightdm-gtk-greeter >/dev/null 2>&1 || {
        echo ":: Required package is not installed: lightdm-gtk-greeter" >&2
        exit 1
    }
    [ -x /usr/local/sbin/lightdm-gtk-greeter ] || {
        echo ":: Missing /usr/local/sbin/lightdm-gtk-greeter" >&2
        exit 1
    }
    [ -f /usr/local/share/wayland-sessions/hyprland.desktop ] || {
        echo ":: Missing the Hyprland Wayland session entry." >&2
        exit 1
    }
fi

if [ "$enable_service" = true ]; then
    [ "$install_prefix" = /usr/local ] || {
        echo ":: --enable is only valid for the /usr/local system installation." >&2
        exit 1
    }
    [ -n "$login_profile" ] && [ -f "$login_profile" ] || {
        echo ":: --enable requires --profile with the desktop user's .profile." >&2
        exit 1
    }
    if grep -Eq '^[[:space:]]*exec[[:space:]]+start-hyprland([[:space:]]|$)' "$login_profile"; then
        echo ":: Refusing to enable LightDM while .profile still autostarts Hyprland." >&2
        echo ":: Run bsdrunner-disable-console-autostart.sh first." >&2
        exit 1
    fi
    [ "$(sysrc -n dbus_enable 2>/dev/null || true)" = YES ] || {
        echo ":: dbus_enable must be YES before enabling LightDM." >&2
        exit 1
    }
    [ "$(sysrc -n seatd_enable 2>/dev/null || true)" = YES ] || {
        echo ":: seatd_enable must be YES before enabling LightDM." >&2
        exit 1
    }
    if service lightdm status >/dev/null 2>&1; then
        echo ":: Refusing activation while LightDM is already running." >&2
        exit 1
    fi
fi

backup_file() {
    target="$1"
    if [ -f "$target" ] && [ ! -e "${target}.pre-bsdrunner" ]; then
        cp -p "$target" "${target}.pre-bsdrunner"
    fi
}

write_main_greeter_selection() {
    source_conf="$1"
    target_conf="$2"
    temporary_conf="$(mktemp "${TMPDIR:-/tmp}/bsdrunner-lightdm-conf.XXXXXX")"

    if ! awk '
        BEGIN {
            in_seat = 0
            found_seat = 0
            wrote_greeter = 0
        }

        /^\[Seat:\*\][[:space:]]*$/ {
            if (in_seat && !wrote_greeter)
                print "greeter-session=bsdrunner-lightdm-gtk-greeter"
            in_seat = 1
            found_seat = 1
            wrote_greeter = 0
            print
            next
        }

        /^\[/ {
            if (in_seat && !wrote_greeter) {
                print "greeter-session=bsdrunner-lightdm-gtk-greeter"
                wrote_greeter = 1
            }
            in_seat = 0
        }

        in_seat && /^[[:space:]]*greeter-session[[:space:]]*=/ {
            if (!wrote_greeter) {
                print "greeter-session=bsdrunner-lightdm-gtk-greeter"
                wrote_greeter = 1
            }
            next
        }

        { print }

        END {
            if (in_seat && !wrote_greeter)
                print "greeter-session=bsdrunner-lightdm-gtk-greeter"
            if (!found_seat)
                exit 42
        }
    ' "$source_conf" > "$temporary_conf"; then
        rm -f "$temporary_conf"
        echo ":: Could not find [Seat:*] in $source_conf" >&2
        exit 1
    fi

    install -m 644 "$temporary_conf" "$target_conf"
    rm -f "$temporary_conf"
}

lightdm_etc="$install_prefix/etc/lightdm"
lightdm_share="$install_prefix/share/bsdrunner/lightdm"
xgreeters_share="$install_prefix/share/xgreeters"

install -d -m 755 "$lightdm_etc/lightdm.conf.d"
install -d -m 755 "$lightdm_share/backgrounds"
install -d -m 755 "$xgreeters_share"

lightdm_main_conf="$lightdm_etc/lightdm.conf"
[ -f "$lightdm_main_conf" ] || {
    echo ":: Missing LightDM main config: $lightdm_main_conf" >&2
    exit 1
}

for target in \
    "$lightdm_main_conf" \
    "$lightdm_etc/lightdm.conf.d/50-bsdrunner.conf" \
    "$lightdm_etc/lightdm-gtk-greeter.conf" \
    "$xgreeters_share/bsdrunner-lightdm-gtk-greeter.desktop"; do
    backup_file "$target"
done

write_main_greeter_selection "$lightdm_main_conf" "$lightdm_main_conf"

install -m 644 \
    "$bundle_root/etc/lightdm/lightdm.conf.d/50-bsdrunner.conf" \
    "$lightdm_etc/lightdm.conf.d/50-bsdrunner.conf"
install -m 644 \
    "$bundle_root/etc/lightdm/lightdm-gtk-greeter.conf" \
    "$lightdm_etc/lightdm-gtk-greeter.conf"
install -m 755 \
    "$bundle_root/share/bsdrunner/lightdm/bsdrunner-lightdm-gtk-greeter" \
    "$lightdm_share/bsdrunner-lightdm-gtk-greeter"
install -m 755 \
    "$bundle_root/share/bsdrunner/lightdm/pick-random-wallpaper.sh" \
    "$lightdm_share/pick-random-wallpaper.sh"
install -m 644 \
    "$bundle_root/share/xgreeters/bsdrunner-lightdm-gtk-greeter.desktop" \
    "$xgreeters_share/bsdrunner-lightdm-gtk-greeter.desktop"

find "$bundle_root/share/bsdrunner/lightdm/backgrounds" -type f -maxdepth 1 | \
    while IFS= read -r background; do
        install -m 644 "$background" "$lightdm_share/backgrounds/$(basename "$background")"
    done

if [ "$enable_service" = true ]; then
    combined_config="$(/usr/local/sbin/lightdm --show-config 2>&1)" || {
        echo ":: LightDM rejected the installed configuration." >&2
        exit 1
    }
    printf '%s\n' "$combined_config" | \
        grep -F 'greeter-session=bsdrunner-lightdm-gtk-greeter' >/dev/null || {
            echo ":: Installed LightDM config does not select the BSDRunner greeter." >&2
            exit 1
        }
    printf '%s\n' "$combined_config" | grep -F 'user-session=hyprland' >/dev/null || {
        echo ":: Installed LightDM config does not select Hyprland." >&2
        exit 1
    }
    sysrc greetd_enable=NO >/dev/null
    sysrc lightdm_enable=YES >/dev/null
fi

echo ":: Installed the BSDRunner LightDM bundle under $install_prefix"
if [ "$enable_service" = true ]; then
    echo ":: LightDM is enabled for the next boot; it was not started now."
else
    echo ":: LightDM was not enabled. Run bsdrunner-preflight-lightdm.sh before activation."
fi
