#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target_quickshell_dir="$HOME/.config/quickshell/bsdrunner-greeter"
target_script_dir="$HOME/.config/bsdrunner/scripts"

mkdir -p "$target_quickshell_dir"
mkdir -p "$target_script_dir"

rsync -a --backup --suffix='.pre-bsdrunner' \
  "$repo_root/dotfiles/.config/quickshell/bsdrunner-greeter/" \
  "$target_quickshell_dir/"

rsync -a --backup --suffix='.pre-bsdrunner' \
  "$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-greeter.sh" \
  "$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-greeter-action.sh" \
  "$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-greeter-session.sh" \
  "$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-greeter-wallpaper.sh" \
  "$target_script_dir/"

printf '%s\n' ":: Synced BSDRunner greeter prototype into ~/.config"
printf '%s\n' "   Quickshell: $target_quickshell_dir"
printf '%s\n' "   Scripts:    $target_script_dir"
