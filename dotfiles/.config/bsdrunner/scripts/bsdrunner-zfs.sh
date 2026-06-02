#!/bin/sh

set -eu
PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/usr/sbin:/bin:/sbin${PATH:+:$PATH}"

command -v qs >/dev/null 2>&1 || exit 0

exec qs -c bsdrunner-zfs
