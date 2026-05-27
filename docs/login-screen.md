# Graphical Login Screen

BSDRunner now ships an optional `LightDM` + `lightdm-gtk-greeter` bundle generator for a simple graphical login screen on FreeBSD.

This is the supported path for FreeBSD right now because both `lightdm` and `lightdm-gtk-greeter` are available as FreeBSD packages, while the earlier `greetd` path is not reliable for this environment.

BSDRunner also includes a separate native Quickshell greeter UI prototype. That prototype is useful for design and future integration work, but it is not yet a complete login manager.

## Required Packages

Install:

```sh
mdo pkg install xorg-server lightdm lightdm-gtk-greeter
```

## Native Quickshell Greeter UI Prototype

To preview the BSDRunner-native greeter surface:

```sh
sh ~/.config/bsdrunner/scripts/bsdrunner-greeter.sh
```

What it currently does:

- loads the active BSDRunner palette
- rerolls a random static wallpaper from the shipped corp themes
- shows a real greeter-style username/password/session layout

What it does not do yet:

- PAM authentication
- privileged session startup
- real shutdown/reboot wiring

So for now, treat it as the native greeter front-end prototype, not the complete login stack.

## What It Does

The render helper:

- copies the shipped static BSDRunner wallpapers into a LightDM asset bundle
- writes a BSDRunner LightDM config snippet
- writes a `lightdm-gtk-greeter.conf`
- writes a custom xgreeter desktop entry and wrapper
- rerolls the login wallpaper on each greeter launch

The result is a standard username/password login screen with a random BSDRunner wallpaper background each time the greeter starts.

## Render The Bundle

From a normal user session:

```sh
sh ~/.config/bsdrunner/scripts/bsdrunner-render-lightdm.sh
```

That renders a bundle at:

```text
~/.config/bsdrunner/lightdm/
```

## Install The Bundle

On FreeBSD, the generated files are intended for:

- `/usr/local/etc/lightdm/`
- `/usr/local/share/bsdrunner/lightdm/`
- `/usr/local/share/xgreeters/`

Example:

```sh
mdo mkdir -p /usr/local/etc/lightdm/lightdm.conf.d
mdo mkdir -p /usr/local/share/bsdrunner/lightdm
mdo mkdir -p /usr/local/share/xgreeters

mdo cp -R ~/.config/bsdrunner/lightdm/etc/lightdm/. /usr/local/etc/lightdm/
mdo cp -R ~/.config/bsdrunner/lightdm/share/bsdrunner/lightdm/. /usr/local/share/bsdrunner/lightdm/
mdo cp -R ~/.config/bsdrunner/lightdm/share/xgreeters/. /usr/local/share/xgreeters/
```

## Enable LightDM

After the bundle is installed:

```sh
mdo sysrc lightdm_enable=YES
mdo service lightdm start
```

## Notes

- The wallpaper reroll happens in the BSDRunner LightDM greeter wrapper before `lightdm-gtk-greeter` starts.
- The background asset path is:

```text
/tmp/bsdrunner-lightdm-current-background
```

- The LightDM config snippet sets the greeter session to `bsdrunner-lightdm-gtk-greeter`.
- The LightDM config snippet also points `xserver-command` at FreeBSD’s Xorg path:

```text
/usr/local/bin/Xorg
```

- If you want to revert, disable `lightdm` and remove the BSDRunner LightDM config snippet from `/usr/local/etc/lightdm/lightdm.conf.d/`.

## Why This Stack

This stack is the practical FreeBSD fit because:

- `lightdm` is packaged on FreeBSD
- `lightdm-gtk-greeter` is packaged on FreeBSD
- the GTK greeter supports a normal wallpaper-backed login flow
- BSDRunner can wrap the greeter to reroll wallpapers without needing a separate unsupported display-manager stack
