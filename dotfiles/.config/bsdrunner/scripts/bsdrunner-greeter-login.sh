#!/bin/sh

set -eu

username="${1:-}"
session_name="${2:-BSDRunner}"
service="${3:-login}"
helper="$HOME/.local/libexec/bsdrunner-greeter-login-helper"

if [ -z "$username" ]; then
    printf '%s\n' "A username is required." >&2
    exit 64
fi

if [ ! -x "$helper" ]; then
    printf '%s\n' "Greeter login helper is not installed. Run sh ~/.config/bsdrunner/scripts/bsdrunner-build-greeter-backend.sh first." >&2
    exit 127
fi

if command -v mdo >/dev/null 2>&1; then
    exec mdo "$helper" "$username" "$session_name" "$service"
fi

if command -v doas >/dev/null 2>&1; then
    exec doas "$helper" "$username" "$session_name" "$service"
fi

if [ "$(id -u)" -eq 0 ]; then
    exec "$helper" "$username" "$session_name" "$service"
fi

printf '%s\n' "No privilege helper was found for greeter login. Configure mdo or doas first." >&2
exit 1
