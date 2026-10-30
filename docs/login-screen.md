# Graphical Login Screen

BSDRunner uses LightDM with `lightdm-gtk-greeter` as its supported graphical
login path on FreeBSD. A display manager owns the login seat, starts Hyprland
after authentication, and displays the greeter again after Hyprland exits.

The older console path did not provide that lifecycle. It logged in through
`getty` on `ttyv0` and immediately replaced the login shell with
`start-hyprland` from `~/.profile`. Logging out could therefore restart the
desktop unexpectedly or leave the active VT black.

## Safety Model

The setup is intentionally split into checked steps:

- rendering does not need root access
- the profile migration only removes the recognized ttyv0 autostart block and
  retains the original profile
- system files are staged while LightDM remains disabled and the existing
  console startup still works
- a read-only preflight verifies both packages, the Hyprland session entry, the
  combined LightDM configuration, `dbus`, and `seatd`
- activation enables LightDM for the next boot but never starts it underneath
  the current graphical session
- a rollback helper is available from a text console

Do not run `service lightdm start` from inside the current Hyprland session.

## 1. Install Packages and Dotfiles

```sh
sudo pkg install lightdm lightdm-gtk-greeter
./scripts/install-dotfiles.sh
```

The Hyprland package must also provide:

```text
/usr/local/share/wayland-sessions/hyprland.desktop
```

## 2. Render and Inspect the Bundle

```sh
sh ~/.config/bsdrunner/scripts/bsdrunner-render-lightdm.sh
```

The bundle is written to `~/.config/bsdrunner/lightdm/`. It contains:

- the LightDM seat configuration, including `user-session=hyprland`
- the GTK greeter configuration
- a BSDRunner greeter wrapper and desktop entry
- static BSDRunner wallpapers and a random wallpaper picker

## 3. Stage the System Files While Keeping the Current Boot Path

Install the bundle without `--enable`:

```sh
sudo sh ~/.config/bsdrunner/scripts/bsdrunner-install-lightdm.sh \
  --bundle "$HOME/.config/bsdrunner/lightdm"
```

LightDM remains disabled. The old ttyv0 startup remains in `.profile`, so a
reboot at this point still uses the existing console-to-Hyprland path.

## 4. Run the Read-Only Preflight

```sh
sh ~/.config/bsdrunner/scripts/bsdrunner-preflight-lightdm.sh \
  --profile "$HOME/.profile"
```

The preflight does not start or enable LightDM. It checks the installed package
and executable paths, the xgreeter entry, the Hyprland session, the combined
LightDM configuration, and the required services. It should report that staging
is safe but activation is not yet ready because the old console autostart still
exists.

Stop here if any check fails.

## 5. Prepare a Console Recovery Shell

First verify that the expected block can be migrated:

```sh
sh ~/.config/bsdrunner/scripts/bsdrunner-disable-console-autostart.sh --check
```

Then apply the migration:

```sh
sh ~/.config/bsdrunner/scripts/bsdrunner-disable-console-autostart.sh
```

The original is retained as:

```text
~/.profile.pre-bsdrunner-lightdm
```

After this change, logging in on a text console gives you a normal shell.
Hyprland can always be started manually with `start-hyprland`.

Run the stricter preflight before changing `rc.conf`:

```sh
sh ~/.config/bsdrunner/scripts/bsdrunner-preflight-lightdm.sh \
  --profile "$HOME/.profile" \
  --activation-ready
```

Before continuing, switch to a different text VT, log in, confirm that you get a
shell prompt, and exit. This proves the recovery route before LightDM is enabled.

## 6. Enable for the Next Boot

```sh
sudo sh ~/.config/bsdrunner/scripts/bsdrunner-install-lightdm.sh \
  --bundle "$HOME/.config/bsdrunner/lightdm" \
  --profile "$HOME/.profile" \
  --enable
```

This revalidates the staged bundle and recovery profile, then sets
`lightdm_enable=YES` and the stale `greetd_enable` value to `NO`. Existing
LightDM configuration files receive `.pre-bsdrunner` backups.

The script does not start LightDM. Finish your work and reboot normally:

```sh
sudo shutdown -r now
```

After login, selecting **Logout** only asks Hyprland to exit. LightDM owns the
seat and should display the greeter again; BSDRunner no longer forces a VT
switch.

## Recovery and Rollback

If the greeter does not appear, switch to a text console with
`Ctrl`+`Alt`+`F1`, log in, and run:

```sh
sudo sh ~/.config/bsdrunner/scripts/bsdrunner-rollback-lightdm.sh
start-hyprland
```

The rollback helper disables and stops LightDM and restores any LightDM config
files that existed before BSDRunner installed its bundle. It deliberately does
not restore automatic Hyprland startup in `.profile`; a normal console login is
the safer recovery path.

## Validation

The repository smoke test renders into a temporary prefix, installs the bundle
there, tests profile migration, and confirms logout no longer invokes
`vidcontrol`:

```sh
sh scripts/test-lightdm.sh
```
