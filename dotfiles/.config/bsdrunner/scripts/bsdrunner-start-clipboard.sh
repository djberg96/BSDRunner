#!/bin/sh
set -eu
PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}"
script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
. "$script_dir/bsdrunner-clipboard-common.sh"
command -v cliphist >/dev/null 2>&1 || exit 0
command -v wl-paste >/dev/null 2>&1 || exit 0
command -v lockf >/dev/null 2>&1 || exit 0
clipboard_init
start_watch() {
    kind="$1"
    if command -v daemon >/dev/null 2>&1; then
        daemon -f -o "$clipboard_dir/$kind-watch.log" lockf -t 0 "$clipboard_dir/$kind.lock" \
            wl-paste --type "$kind" --watch sh "$script_dir/bsdrunner-clipboard-store.sh"
    else
        (nohup lockf -t 0 "$clipboard_dir/$kind.lock" \
            wl-paste --type "$kind" --watch sh "$script_dir/bsdrunner-clipboard-store.sh" \
            >>"$clipboard_dir/$kind-watch.log" 2>&1 &) >/dev/null 2>&1
    fi
}
start_watch text
start_watch image
