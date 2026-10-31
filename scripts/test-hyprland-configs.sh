#!/bin/sh

set -eu

repo_root="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
greeter_config="$repo_root/greeter/hyprland.lua"
terminal_config="$repo_root/dotfiles/.config/hypr/bsdrunner-terminal.lua"

fail() {
    printf 'not ok - %s\n' "$1" >&2
    exit 1
}

for config in "$greeter_config" "$terminal_config"; do
    [ -f "$config" ] || fail "missing Lua config: $config"
done
[ ! -e "$repo_root/greeter/hyprland.conf" ] || \
    fail "the deprecated greeter config is still shipped"
[ ! -e "$repo_root/dotfiles/.config/hypr/bsdrunner-terminal.conf" ] || \
    fail "the deprecated terminal config is still shipped"

if grep -R -n --exclude-dir=target 'hyprland\.conf' \
        "$repo_root/greeter" >/dev/null || \
    grep -n 'bsdrunner-terminal\.conf' \
        "$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-greeter-session.sh" >/dev/null || \
    grep -F '"$repo_root/greeter/hyprland.conf"' \
        "$repo_root/scripts/install-greetd-greeter.sh" >/dev/null; then
    fail "a greeter runtime path still selects the deprecated config format"
fi

if grep -F 'dbus-run-session' "$repo_root/greeter/greetd.toml" >/dev/null; then
    fail "greetd still owns the greeter D-Bus wrapper outside the logged launcher"
fi
grep -F 'dbus-run-session "$0"' \
    "$repo_root/greeter/start-greeter-hyprland.sh" >/dev/null || \
    fail "the greeter launcher does not own its D-Bus session"

if command -v Hyprland >/dev/null 2>&1; then
    for config in "$greeter_config" "$terminal_config"; do
        Hyprland --verify-config --config "$config" >/dev/null || \
            fail "Hyprland rejected $config"
    done
fi

printf '%s\n' 'Hyprland Lua config tests passed.'
