#!/bin/sh

set -eu

username="${1:-}"
service="${2:-login}"
helper="$HOME/.local/libexec/bsdrunner-greeter-auth-helper"

if [ -z "$username" ]; then
    printf '%s\n' "A username is required." >&2
    exit 64
fi

if [ ! -x "$helper" ]; then
    printf '%s\n' "Greeter auth helper is not installed. Run sh ~/.config/bsdrunner/scripts/bsdrunner-build-greeter-backend.sh first." >&2
    exit 127
fi

if command -v mdo >/dev/null 2>&1; then
    exec mdo "$helper" "$username" "$service"
fi

if command -v doas >/dev/null 2>&1; then
    exec doas "$helper" "$username" "$service"
fi

if [ "$(id -u)" -eq 0 ]; then
    exec "$helper" "$username" "$service"
fi

printf '%s\n' "No privilege helper was found for greeter authentication. Configure mdo or doas first." >&2
exit 1
