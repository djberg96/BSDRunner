#!/bin/sh
set -eu
PATH="${BSDRUNNER_CLIPBOARD_PATH:-/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}}"
case "${CLIPBOARD_STATE:-data}" in sensitive|nil|clear) exit 0 ;; esac
# Do not collect copies made while the screen is locked.
if ps ax -o stat= -o comm= | awk '$1 !~ /^Z/ && $2 == "hyprlock" {found=1} END {exit found ? 0 : 1}'; then
    exit 0
fi
script_dir="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
. "$script_dir/bsdrunner-clipboard-common.sh"
clipboard_init
command -v cliphist >/dev/null 2>&1 || exit 1
clipboard_hist store
