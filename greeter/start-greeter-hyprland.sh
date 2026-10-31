#!/bin/sh

set -eu

bundle_dir="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
config_path="$bundle_dir/hyprland.conf"

if command -v start-hyprland >/dev/null 2>&1; then
    exec start-hyprland -- --config "$config_path"
fi

exec Hyprland --config "$config_path"
