#!/bin/sh

set -eu

system_root="/"

if [ "${1:-}" = --root ]; then
    [ "$#" -eq 2 ] || {
        echo ":: Usage: bsdrunner-rollback-ly.sh [--root DIR]" >&2
        exit 1
    }
    system_root="$2"
elif [ "$#" -ne 0 ]; then
    echo ":: Usage: bsdrunner-rollback-ly.sh [--root DIR]" >&2
    exit 1
fi

if [ "$system_root" = / ] && [ "$(id -u)" -ne 0 ]; then
    echo ":: Run this rollback as root (use doas or sudo)." >&2
    exit 1
fi

root_path() {
    if [ "$system_root" = / ]; then
        printf '%s\n' "$1"
    else
        printf '%s%s\n' "${system_root%/}" "$1"
    fi
}

restore_backup() {
    target="$1"
    backup="${target}.pre-bsdrunner-ly"
    if [ -f "$backup" ]; then
        cp -p "$backup" "$target"
        echo ":: Restored $target"
    fi
}

restore_backup "$(root_path /etc/gettytab)"
restore_backup "$(root_path /etc/ttys)"
if [ "$system_root" = / ]; then
    sysrc lightdm_enable=NO >/dev/null
    sysrc greetd_enable=NO >/dev/null
fi

echo ":: Ly is removed from the next boot configuration."
echo ":: init was not reloaded; reboot to return every VT to its restored getty."
