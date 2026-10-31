# BSDRunner

Hyprland config for FreeBSD 15. Primarly designed for my IBM ThinkPad X1 Gen 9
but maybe it will work for you, too.

## Screenshots

### Welcome Screen

![BSDRunner welcome screen](docs/screenshots/bsdrunner_welcome.png)

### Sample Desktop

![BSDRunner sample background](docs/screenshots/bsdrunner_sample_background1.png)

# Netrunner
The themes are based on the four corporations from the card game Android: Netrunner.
Note that while based on that game, the artwork here is all AI generated.

# Overview
This repo is intentionally small:

- a modular Hyprland config with a thin top-level loader
- Waybar in the default startup path
- `swww` in the themed startup path
- no lockscreen, notification daemon, or idle daemon by default
- no generated monitor config
- a neutral base with optional corp theme layers

The goal is a nice, bootable base session for Hyprland `0.56.x` on FreeBSD.

## Files

- `dotfiles/.config/hypr/hyprland.lua`
- `dotfiles/.config/hypr/conf/`
- `dotfiles/.config/kitty/kitty.conf`
- `dotfiles/.config/quickshell/`
- `dotfiles/.config/waybar/`
- `dotfiles/.config/bsdrunner/themes/`
- `dotfiles/.config/bsdrunner/pf/`
- `system/etc/pf.conf`
- `scripts/install-dotfiles.sh`
- `docs/freebsd-setup.md`
- `docs/freebsd-dev-lab.md`
- `docs/themes.md`
- `docs/software-center.md`
- `docs/login-screen.md`
- `docs/pf.md`
- `docs/dns.md`

## Quick Start

```sh
./scripts/install-dotfiles.sh
```

Install and apply a corp theme:

```sh
./scripts/install-dotfiles.sh --theme jinteki
```

Implemented corp themes:

- `jinteki`
- `haas-bioroid`
- `nbn`
- `weyland`

Each implemented corp theme currently ships:

- a Kitty theme fragment
- a Rofi theme
- a generated Firefox profile theme
- Waybar styling
- bundled wallpapers for `swww`
- a Kitty watermark asset

Wallpaper selection is automatic during install. Themes that ship multiple wallpapers rotate them by workspace number through the `swww` helper.

Return to the neutral baseline:

```sh
./scripts/install-dotfiles.sh --theme default
```

## Default Binds

- `Super+Q`: open `kitty`
- `Super+C`: close focused window
- `Super+E`: open BSDRunner Files
- `Super+D`: open `rofi -show drun`
- `Super+F`: open `firefox`
- `Super+V`: toggle floating
- `Super+W`: open the optional welcome window
- `Super+X`: exit Hyprland

The welcome window includes a **Key Bindings** button that opens the full
desktop binding reference.

## Validated Apps

The following have been tested in the current FreeBSD/Hyprland bring-up:

- terminal: `kitty`
- browser: `firefox`
- launcher: `rofi`
- file manager: BSDRunner Files (`quickshell` + `xdg-open`)

Validated fallback:

- `dolphin`

Possible lighter Qt alternative:

- `pcmanfm-qt`

## Files

BSDRunner includes a lightweight Quickshell file manager for normal directory
navigation and opening files with the system default application.

```sh
sh ~/.config/bsdrunner/scripts/bsdrunner-files.sh
```

V1 is browse/open only. Dolphin remains a useful fallback for heavier file
operations such as copy, move, rename, trash, archive handling, and remote
locations.

## Theme Switching

BSDRunner currently supports two in-session theme switching paths:

- the optional welcome window on `Super+W`
- the Waybar theme button on the left side of the bar

Both paths call the same theme apply script and update:

- Kitty config for new windows
- Rofi theme
- Firefox profile chrome/content CSS
- Waybar config and style
- wallpaper selection and `swww` rotation
- Hyprland border colors

Waybar also includes a few lightweight control-surface actions:

- theme switcher
- apps launcher
- power menu

Existing Kitty windows will not fully restyle in place. Open a fresh Kitty window after switching themes. Firefox reads profile chrome CSS on startup, so restart Firefox after switching BSDRunner themes.

## Firewall

BSDRunner includes a desktop-focused PF baseline and a first-pass Quickshell firewall control surface.

Launch the graphical firewall after installing the dotfiles:

```sh
sh ~/.config/bsdrunner/scripts/bsdrunner-pf.sh
```

The GUI manages a BSDRunner desktop profile, not arbitrary PF syntax. See `docs/pf.md` for the baseline, validation commands, smoke tests, and rollback path.

## DNS Cache

BSDRunner includes a first-pass Quickshell control surface for FreeBSD's base `local_unbound` service.

Launch it after installing the dotfiles:

```sh
sh ~/.config/bsdrunner/scripts/bsdrunner-dns.sh
```

The GUI starts in read-only status mode until you choose an action. See `docs/dns.md` for backend commands and manual acceptance checks.

## Wayland Login

BSDRunner supports Ly as its X-server-free login path on FreeBSD. Ly owns the
session lifecycle and returns to its terminal login UI after Hyprland exits,
while `ttyv0` remains available for recovery. See
[docs/login-screen.md](docs/login-screen.md) for the guarded installation and
rollback procedure.

## ZFS

BSDRunner includes a laptop-focused ZFS snapshot surface for pool health, datasets, and basic snapshot actions.

```sh
sh ~/.config/bsdrunner/scripts/bsdrunner-zfs.sh
```

See `docs/zfs.md` for the backend commands and scope.

## Jails

BSDRunner includes a beginner-focused FreeBSD jails surface. It lists native
jails, detects Bastille when installed, explains the storage/userland/network/
config model, and exposes guarded lifecycle actions for existing jails.

```sh
sh ~/.config/bsdrunner/scripts/bsdrunner-jails.sh
```

Use `--demo` to explore representative native and Bastille jail states without a
configured FreeBSD jail host. The UI also includes a host-aware, read-only
Bastille plan plus a guarded **Create Basic Jail** wizard that follows Storage,
Userland, Network, Config, and Lifecycle. The Storage step can select an
existing ZFS pool and configure Bastille's conventional `POOL/bastille`
hierarchy. Userland offers the host-matched and bootstrapped FreeBSD releases,
plus guarded Thick and Thin jail choices. The separate Network step recommends
a route-safe jail address and,
after typed confirmation, can create Bastille's loopback interface and add its
NAT and anchors to BSDRunner's managed PF profile. See `docs/jails.md` for
backend commands, fixture-backed tests, current scope, and the creation model.

## Scope

This starter is targeted at:

- FreeBSD 15
- Hyprland `0.56.x`
- ThinkPad X1 Gen 9

The current repo already includes a working Waybar autostart and `swww` wallpaper path. The next risky layers are things like lockscreen, idle, extra desktop daemons, or deeper Qt/KDE theming.

## Animated Wallpaper

For the curious, Haas-Bioroid also supports an animated wallpaper setup with a per-workspace play/pause toggle on the bar:

![Haas-Bioroid animated wallpaper](docs/screenshots/haas_bioroid_wallpaper2_take2.gif)

# About Pull Requests
I'll be blunt. This is really, mainly, a personal project that I keep online for
convenience. I've made this desktop for me, not for you. While I won't outright
reject a PR without looking at it first, please keep in mind that I am largely
uninterested in external input.

That said, if you think you've found a bug, by all means report it. If you have a
UI enhancement that you think would be nice, please include your reasoning and
some screenshots.

# Creator
Daniel J. Berger

# License
MIT
