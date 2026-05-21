#!/bin/sh

set -eu

[ -f "$HOME/.config/bsdrunner/show-welcome-at-startup" ] || exit 0
command -v qs >/dev/null 2>&1 || exit 0

exec qs -c bsdrunner-welcome
