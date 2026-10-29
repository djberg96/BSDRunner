#!/bin/sh

set -eu
PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}"

case "${1:-}" in
    "")
        ;;
    --demo)
        fixture_file="${HOME}/.config/bsdrunner/jails/demo-snapshot.json"
        if [ ! -r "$fixture_file" ]; then
            printf 'Jails demo data is missing: %s\n' "$fixture_file" >&2
            exit 1
        fi
        BSDRUNNER_JAILS_FIXTURE="$fixture_file"
        export BSDRUNNER_JAILS_FIXTURE
        ;;
    *)
        printf 'Usage: %s [--demo]\n' "$0" >&2
        exit 2
        ;;
esac

if command -v qs >/dev/null 2>&1; then
    exec qs -c bsdrunner-jails
fi

if command -v quickshell >/dev/null 2>&1; then
    exec quickshell -c bsdrunner-jails
fi

exit 0
