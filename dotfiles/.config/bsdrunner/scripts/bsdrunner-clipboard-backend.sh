#!/bin/sh
set -eu
set -o pipefail
PATH="${BSDRUNNER_CLIPBOARD_PATH:-/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}}"
script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
. "$script_dir/bsdrunner-clipboard-common.sh"
clipboard_init
command -v cliphist >/dev/null 2>&1 || { printf 'Cliphist is not installed.\n' >&2; exit 1; }
case "${1:-list}" in
    list)
        entries="$(clipboard_hist list)"
        printf '%s\n' "$entries" | jq -Rsc 'split("\n") | map(select(test("^[0-9]+\\t")) | capture("^(?<id>[0-9]+)\\t(?<preview>.*)$"))'
        ;;
    copy|delete)
        item="${2:-}"
        case "$item" in ''|*[!0-9]*) printf 'Invalid clipboard item.\n' >&2; exit 2 ;; esac
        if [ "$1" = copy ]; then
            command -v wl-copy >/dev/null 2>&1 || { printf 'wl-copy is not installed.\n' >&2; exit 1; }
            clipboard_hist decode "$item" | wl-copy
        else
            printf '%s\n' "$item" | clipboard_hist delete
        fi
        ;;
    clear) clipboard_hist wipe ;;
    *) printf 'Usage: %s list|copy ID|delete ID|clear\n' "$0" >&2; exit 2 ;;
esac
