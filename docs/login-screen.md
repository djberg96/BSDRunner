# Graphical Login Screen

BSDRunner now ships an optional `greetd` + `ReGreet` bundle generator for a simple graphical login screen.

The bundle is intentionally separate from the normal user dotfile install, because the actual greeter config lives under `/etc/greetd/` and needs root to enable.

## What It Does

The render helper:

- copies the shipped static BSDRunner wallpapers into a self-contained greeter bundle
- writes a small Hyprland config just for the greeter session
- writes a matching `ReGreet` config and CSS
- rerolls the greeter background from that bundled wallpaper set on each launch

The result is a typical username/password login screen with a BSDRunner wallpaper background and a readable dark control surface on top.

## Render The Bundle

From a normal user session:

```sh
sh ~/.config/bsdrunner/scripts/bsdrunner-render-greetd.sh
```

That renders a bundle at:

```text
~/.config/bsdrunner/greetd/
```

You do not need to rerender the bundle just to get a different background. The greeter chooses one random bundled wallpaper each time it launches.

## Install The Bundle

The generated files are designed to be copied into:

```text
/etc/greetd/bsdrunner
```

Example:

```sh
sudo mkdir -p /etc/greetd/bsdrunner
sudo cp -R ~/.config/bsdrunner/greetd/. /etc/greetd/bsdrunner/
sudo cp /etc/greetd/bsdrunner/config.toml /etc/greetd/config.toml
```

## Enable greetd

After the bundle is in place, enable the daemon:

```sh
sudo sysrc greetd_enable=YES
sudo service greetd start
```

## Notes

- The generated greeter session uses `Hyprland` or `start-hyprland`, whichever exists first.
- The generated bundle assumes `ReGreet` is installed and available as `regreet`.
- The greeter rerolls a random bundled wallpaper on each launch.
- The reboot and poweroff buttons in `ReGreet` use FreeBSD `shutdown` commands and may still need local policy tweaks depending on your system setup.

## Why This Stack

`ReGreet` explicitly supports:

- a background image
- a custom CSS stylesheet
- running under Hyprland as the greetd compositor session

Those three capabilities make it a much better fit for BSDRunner than a generic text greeter.
