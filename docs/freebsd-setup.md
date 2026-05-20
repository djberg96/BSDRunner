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

## Recommended Fonts

For a practical desktop and terminal font stack, install:

```sh
sudo pkg install \
  noto \
  font-awesome
```

If you want a nicer monospace font for terminals and editors, also install:

```sh
sudo pkg install jetbrains-mono
```

The included `kitty.conf` uses:

- `JetBrains Mono`
- `font_size 12.0`

If the X1 panel makes text look too small, try `13.0` or `14.0`.

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

To apply a corp theme during install:

```sh
./scripts/install-dotfiles.sh --theme jinteki
```

To return to the neutral baseline:

```sh
./scripts/install-dotfiles.sh --theme default
```

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
