# BSDRunner

Minimal Hyprland config for FreeBSD 15 on a ThinkPad X1 Gen 9.

This repo is intentionally small:

- one Hyprland config file
- no Waybar in the default startup path
- no lockscreen, wallpaper, notifications, or idle daemon by default
- no generated monitor config

The goal is a boring, bootable base session for Hyprland `0.54.x` on FreeBSD.

## Files

- `dotfiles/.config/hypr/hyprland.conf`
- `dotfiles/.config/kitty/kitty.conf`
- `scripts/install-dotfiles.sh`
- `docs/freebsd-setup.md`
- `docs/themes.md`

## Install

```sh
./scripts/install-dotfiles.sh
```

## Default Binds

- `Super+Return`: open `foot`
- `Super+D`: open `rofi -show drun`
- `Super+Q`: close focused window
- `Super+Shift+E`: exit Hyprland
- `Super+F`: toggle fullscreen
- `Super+V`: toggle floating

## Scope

This starter is targeted at:

- FreeBSD 15
- Hyprland `0.54.x`
- ThinkPad X1 Gen 9

If you want bars, notifications, wallpaper, or lockscreen support later, add them only after this base session is stable.
