#!/bin/sh

set -eu

script_dir="$HOME/.config/bsdrunner/scripts"
target_dir="$HOME/.local/libexec"

build_helper() {
    src="$1"
    target="$2"
    libs="$3"

    cc -O2 -Wall -Wextra -D__BSD_VISIBLE=1 -o "$target" "$src" $libs
    chmod 700 "$target"
    printf '  %s\n' "$target"
}

mkdir -p "$target_dir"

printf '%s\n' "Built BSDRunner greeter backend helpers:"
build_helper \
    "$script_dir/bsdrunner-greeter-auth-helper.c" \
    "$target_dir/bsdrunner-greeter-auth-helper" \
    "-lpam"
build_helper \
    "$script_dir/bsdrunner-greeter-login-helper.c" \
    "$target_dir/bsdrunner-greeter-login-helper" \
    "-lpam -lutil"
