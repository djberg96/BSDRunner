#!/bin/sh

set -eu

action="${1:-snapshot}"
script_dir="$HOME/.config/bsdrunner/scripts"

case "$action" in
    snapshot)
        exec sh "$script_dir/bsdrunner-software-query.sh" "$@"
        ;;
    install|reinstall|upgrade|upgrade-all|remove)
        exec sh "$script_dir/bsdrunner-software-action.sh" "$@"
        ;;
    *)
        printf '{"ok":false,"message":"Unknown backend action: %s","packages":[],"summary":{"total":0,"installed":0,"updates":0}}\n' "$action"
        exit 1
        ;;
esac
