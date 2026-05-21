# BSDRunner

Minimal Hyprland config for FreeBSD 15 on a ThinkPad X1 Gen 9.

This repo is intentionally small:

- one Hyprland config file
- Waybar in the default startup path
- `swww` in the themed startup path
- no lockscreen, notification daemon, or idle daemon by default
- no generated monitor config
- a neutral base with optional corp theme layers

The goal is a boring, bootable base session for Hyprland `0.54.x` on FreeBSD.

## Files

- `dotfiles/.config/hypr/hyprland.conf`
- `dotfiles/.config/kitty/kitty.conf`
- `dotfiles/.config/quickshell/`
- `dotfiles/.config/waybar/`
- `dotfiles/.config/bsdrunner/themes/`
- `scripts/install-dotfiles.sh`
- `docs/freebsd-setup.md`
- `docs/themes.md`

## Quick Start

```sh
./scripts/install-dotfiles.sh
```

Install and apply a corp theme:

```sh
./scripts/install-dotfiles.sh --theme jinteki
```

The Jinteki theme installs a `swww` wallpaper target using the bundled Jinteki wallpaper assets. It uses `jinteki_wallpaper4.jpg` as the anchor wallpaper, then rotates across the other bundled wallpapers by workspace number.

Return to the neutral baseline:

```sh
./scripts/install-dotfiles.sh --theme default
```

## Default Binds

- `Super+Q`: open `kitty`
- `Super+C`: close focused window
- `Super+E`: open `dolphin`
- `Super+D`: open `rofi -show drun`
- `Super+F`: open `firefox`
- `Super+V`: toggle floating
- `Super+W`: open the optional welcome window
- `Super+X`: exit Hyprland

## Validated Apps

The following have been tested in the current FreeBSD/Hyprland bring-up:

- terminal: `kitty`
- browser: `firefox`
- launcher: `rofi`
- file manager: `dolphin`

Possible lighter Qt alternative:

- `pcmanfm-qt`

## Scope

This starter is targeted at:

- FreeBSD 15
- Hyprland `0.54.x`
- ThinkPad X1 Gen 9

The current repo already includes a working Waybar autostart and `swww` wallpaper path. The next risky layers are things like lockscreen, idle, extra desktop daemons, or deeper Qt/KDE theming.
