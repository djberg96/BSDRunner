# FreeBSD Setup

This repo targets a minimal Hyprland `0.54.x` session on FreeBSD 15.

## Packages

Install the smallest useful set first:

```sh
sudo pkg install \
  hyprland \
  foot \
  rofi-wayland \
  dbus \
  seatd \
  polkit \
  mate-polkit
```

Recommended next layer after the base session works:

```sh
sudo pkg install \
  xdg-desktop-portal \
  xdg-desktop-portal-hyprland \
  xdg-desktop-portal-gtk \
  pipewire \
  wireplumber \
  pavucontrol \
  playerctl
```

## Services

```sh
sudo sysrc dbus_enable=YES
sudo sysrc seatd_enable=YES

sudo service dbus start
sudo service seatd start
```

## Install The Dotfiles

From the repo root:

```sh
./scripts/install-dotfiles.sh
```

That copies `dotfiles/` into your home directory with `.pre-bsdrunner` backups.

## First Test

Do the first test with only the shipped `hyprland.conf`.

Do not add:

- Waybar
- hyprpaper
- swaync
- hypridle
- hyprlock
- Quickshell

until the base session is proven stable.

## ThinkPad X1 Gen 9 Notes

The shipped config uses:

- a fallback monitor rule: `monitor=,preferred,auto,1`
- conservative touchpad options that are valid for Hyprland `0.54`
- no custom GPU environment overrides

That keeps the first startup path as hardware-agnostic as possible for either the 1920x1200 or higher-DPI X1 Gen 9 panels.
