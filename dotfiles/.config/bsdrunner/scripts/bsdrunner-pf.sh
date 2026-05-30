#!/bin/sh

set -eu

command -v qs >/dev/null 2>&1 || exit 0

exec qs -c bsdrunner-pf
