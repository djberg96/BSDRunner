#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
target_quickshell_dir="$HOME/.config/quickshell/bsdrunner-greeter"
target_script_dir="$HOME/.config/bsdrunner/scripts"
target_hypr_dir="$HOME/.config/hypr"

mkdir -p "$target_quickshell_dir"
mkdir -p "$target_script_dir"
mkdir -p "$target_hypr_dir"

rsync -a --backup --suffix='.pre-bsdrunner' \
  "$repo_root/dotfiles/.config/quickshell/bsdrunner-greeter/" \
  "$target_quickshell_dir/"

rsync -a --backup --suffix='.pre-bsdrunner' \
  "$repo_root/dotfiles/.config/hypr/bsdrunner-greeter.conf" \
  "$repo_root/dotfiles/.config/hypr/bsdrunner-terminal.conf" \
  "$target_hypr_dir/"

rsync -a --backup --suffix='.pre-bsdrunner' \
  "$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-build-greeter-backend.sh" \
  "$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-greeter-auth-helper.c" \
  "$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-greeter-auth.sh" \
  "$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-greeter-login-helper.c" \
  "$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-greeter-login.sh" \
  "$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-launch-hyprland.sh" \
  "$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-greeter.sh" \
  "$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-greeter-action.sh" \
  "$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-greeter-session.sh" \
  "$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-greeter-wallpaper.sh" \
  "$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-run-greeter.sh" \
  "$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-run-terminal-session.sh" \
  "$repo_root/dotfiles/.config/bsdrunner/scripts/bsdrunner-start-greeter-session.sh" \
  "$target_script_dir/"

printf '%s\n' ":: Synced BSDRunner greeter prototype into ~/.config"
printf '%s\n' "   Quickshell: $target_quickshell_dir"
printf '%s\n' "   Hyprland:   $target_hypr_dir"
printf '%s\n' "   Scripts:    $target_script_dir"
