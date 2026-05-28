#!/bin/sh

set -eu

command -v qs >/dev/null 2>&1 || exit 0

BSDRUNNER_GREETER_REAL_BACKEND=1 qs -c bsdrunner-greeter

if command -v hyprctl >/dev/null 2>&1; then
    hyprctl dispatch exit >/dev/null 2>&1 || true
fi
