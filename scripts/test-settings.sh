#!/bin/sh

set -eu

repo_root="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
launcher="$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-settings.sh"
shell_qml="$repo_root/dotfiles/.config/quickshell/bsdrunner-settings/shell.qml"
waybar_config="$repo_root/dotfiles/.config/waybar/config"
desktop_entry="$repo_root/dotfiles/.local/share/applications/bsdrunner-settings.desktop"

fail() {
    printf 'not ok - %s\n' "$1" >&2
    exit 1
}

for required in "$launcher" "$shell_qml" "$desktop_entry"; do
    [ -f "$required" ] || fail "missing settings component: $required"
done
printf 'ok - settings hub components are present\n'

for action in appearance network power firewall dns software zfs jails time battery; do
    grep -Fq "case \"$action\"" "$shell_qml" || fail "settings hub is missing the $action route"
done
printf 'ok - settings hub routes every category\n'

jq -e '.[0]["modules-left"] | index("custom/settings") != null' "$waybar_config" >/dev/null || \
    fail "Waybar does not expose the settings launcher"
jq -e '.[0]["custom/settings"]["on-click"] | contains("bsdrunner-settings.sh")' "$waybar_config" >/dev/null || \
    fail "Waybar settings action does not use the managed launcher"
printf 'ok - Waybar exposes BSDRunner Settings\n'

grep -Fq '"label": "System Settings"' "$repo_root/dotfiles/.config/quickshell/bsdrunner-apps/shell.qml" || \
    fail "Apps menu does not expose System Settings"
grep -Fq '"title": "System Settings"' "$repo_root/dotfiles/.config/quickshell/bsdrunner-welcome/shell.qml" || \
    fail "Welcome does not expose System Settings"
grep -Fq 'Name=BSDRunner Settings' "$desktop_entry" || fail "desktop entry has the wrong name"
if command -v desktop-file-validate >/dev/null 2>&1; then
    desktop-file-validate "$desktop_entry" || fail "desktop entry is invalid"
fi
printf 'ok - desktop launch surfaces expose BSDRunner Settings\n'

grep -Fq 'mainMod .. " + I"' "$repo_root/dotfiles/.config/hypr/hyprland.lua" || \
    fail "Lua desktop config is missing Super+I"
grep -Fq 'bind = $mainMod, I' "$repo_root/dotfiles/.config/hypr/conf/keybindings.conf" || \
    fail "legacy desktop config is missing Super+I"
printf 'ok - both Hyprland configs bind Super+I\n'

printf 'All settings hub tests passed.\n'
