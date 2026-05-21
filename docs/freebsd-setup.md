# FreeBSD Setup

This repo targets a minimal Hyprland `0.54.x` session on FreeBSD 15.

## Packages

Install the smallest useful set first:

```sh
sudo pkg install \
  hyprland \
  swww \
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
  quickshell \
  waybar \
  wlogout \
  xdg-desktop-portal \
  xdg-desktop-portal-hyprland \
  xdg-desktop-portal-gtk \
  pipewire \
  wireplumber \
  pavucontrol \
  playerctl
```

If you want the file manager currently validated in BSDRunner testing, also install:

```sh
sudo pkg install dolphin
```

If you prefer a lighter Qt file manager to experiment with later:

```sh
sudo pkg install pcmanfm-qt
```

For the bundled power menu, `wlogout` is expected. If you want the shutdown and reboot buttons to work without a password prompt, a `doas` rule for `shutdown` may be useful on FreeBSD.

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
- `font_size 14.0`

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

Implemented corp themes:

- `jinteki`
- `haas-bioroid`
- `nbn`
- `weyland`

All four implemented corp themes currently ship bundled wallpaper sets and Kitty watermark assets. Theme install writes `~/.config/bsdrunner/current-wallpaper` automatically, then the `swww` helper rotates the available wallpaper set by workspace number.

To return to the neutral baseline:

```sh
./scripts/install-dotfiles.sh --theme default
```

## First Test

Do the first test with only the shipped BSDRunner stack:

- `hyprland.conf`
- autostarted `bsdrunner-start-waybar.sh`
- autostarted `swww` wallpaper helper when a theme is active

Do not add:

- swaync
- hypridle
- hyprlock
- Quickshell

until the base session is proven stable.

The currently validated application stack for the early BSDRunner setup is:

- terminal: `kitty`
- browser: `firefox`
- launcher: `rofi`
- file manager: `dolphin`

On some FreeBSD Hyprland sessions, Waybar may need a DBus session wrapper even when manual launch works. BSDRunner currently autostarts it with:

```sh
sh ~/.config/bsdrunner/scripts/bsdrunner-start-waybar.sh
```

If you install `quickshell`, BSDRunner also ships an optional welcome window. Launch it manually with:

```sh
sh ~/.config/bsdrunner/scripts/bsdrunner-welcome.sh
```

To show it automatically on login later:

```sh
touch ~/.config/bsdrunner/show-welcome-at-startup
```

If you need to launch Waybar manually in the current session, use the same wrapper:

```sh
sh ~/.config/bsdrunner/scripts/bsdrunner-start-waybar.sh
```

For quick theme switching after install, BSDRunner supports:

- the Waybar theme button
- the welcome window theme picker

Both paths call:

```sh
sh ~/.config/bsdrunner/scripts/bsdrunner-apply-theme.sh THEME
```

where `THEME` is one of:

- `default`
- `jinteki`
- `haas-bioroid`
- `nbn`
- `weyland`

## Manual Qt Theme Test For Dolphin

If your session already uses `qt6ct`, you can test the Jinteki Qt palette without touching Hyprland itself:

```sh
mkdir -p ~/.config/qt6ct/colors
cp ~/.config/bsdrunner/themes/jinteki/qt6ct.conf ~/.config/qt6ct/colors/jinteki.conf
```

Then change `color_scheme_path` in `~/.config/qt6ct/qt6ct.conf` from the system scheme to your user copy, for example:

```ini
color_scheme_path=/home/YOUR_USER/.config/qt6ct/colors/jinteki.conf
```

Fully quit Dolphin and reopen it. To revert, restore the previous `color_scheme_path`.

## ThinkPad X1 Gen 9 Notes

The shipped config uses:

- a fallback monitor rule: `monitor=,preferred,auto,1`
- conservative touchpad options that are valid for Hyprland `0.54`
- no custom GPU environment overrides
- `brightnessctl` keybinds are still present in the current base config and may need a FreeBSD-specific replacement later

That keeps the first startup path as hardware-agnostic as possible for either the 1920x1200 or higher-DPI X1 Gen 9 panels.
