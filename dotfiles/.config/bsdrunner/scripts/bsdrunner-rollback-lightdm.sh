#!/bin/sh

set -eu

[ "$(id -u)" -eq 0 ] || {
    echo ":: Rollback must run as root (use doas or sudo)." >&2
    exit 1
}

restore_or_remove() {
    target="$1"
    backup="${target}.pre-bsdrunner"

    if [ -f "$backup" ]; then
        mv "$backup" "$target"
    else
        rm -f "$target"
    fi
}

sysrc lightdm_enable=NO >/dev/null
service lightdm onestop >/dev/null 2>&1 || true

restore_or_remove /usr/local/etc/lightdm/lightdm.conf.d/50-bsdrunner.conf
restore_or_remove /usr/local/etc/lightdm/lightdm-gtk-greeter.conf
restore_or_remove /usr/local/share/xgreeters/bsdrunner-lightdm-gtk-greeter.desktop

if [ -f /usr/local/etc/lightdm/lightdm.conf.pre-bsdrunner ]; then
    mv /usr/local/etc/lightdm/lightdm.conf.pre-bsdrunner \
        /usr/local/etc/lightdm/lightdm.conf
fi

echo ":: Disabled LightDM and restored the pre-BSDRunner LightDM configuration."
echo ":: Console login remains available; run start-hyprland manually if needed."
