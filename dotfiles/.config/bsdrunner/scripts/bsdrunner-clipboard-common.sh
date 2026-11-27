#!/bin/sh
# Shared runtime-only clipboard database setup.
clipboard_init() {
    [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -d "$XDG_RUNTIME_DIR" ] || {
        printf 'A private session runtime directory is required.\n' >&2; return 1;
    }
    [ "$(stat -f '%u' "$XDG_RUNTIME_DIR" 2>/dev/null)" = "$(id -u)" ] || {
        printf 'The session runtime directory has the wrong owner.\n' >&2; return 1;
    }
    clipboard_dir="$XDG_RUNTIME_DIR/bsdrunner-clipboard"
    [ ! -L "$clipboard_dir" ] || { printf 'Clipboard directory must not be a symlink.\n' >&2; return 1; }
    umask 077
    mkdir -p "$clipboard_dir" || return 1
    [ "$(stat -f '%u' "$clipboard_dir" 2>/dev/null)" = "$(id -u)" ] || return 1
    chmod 700 "$clipboard_dir" || return 1
    clipboard_db="$clipboard_dir/history.db"
    [ ! -L "$clipboard_db" ] || { printf 'Clipboard database must not be a symlink.\n' >&2; return 1; }
}
clipboard_hist() {
    cliphist -config-path /dev/null -db-path "$clipboard_db" -max-items 100 "$@"
}
