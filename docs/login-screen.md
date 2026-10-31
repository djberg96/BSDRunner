# Wayland Login with Ly

BSDRunner uses Ly as its supported login manager on FreeBSD. Ly runs directly
on a kernel virtual terminal, discovers Hyprland through its Wayland session
entry, and returns to the login screen after Hyprland exits. It does not require
an X server.

The login screen is a terminal UI rather than a graphical Wayland client. This
keeps the boot path within FreeBSD's packaged components while still providing
a real session owner.

## Safety Model

- `ttyv0` always remains a normal text recovery console.
- Ly is assigned to `ttyv1` only for the next boot.
- The installer never reloads `init`, starts Ly, or disrupts the current seat.
- Existing `/etc/gettytab` and `/etc/ttys` files receive one-time
  `.pre-bsdrunner-ly` backups.
- Activation refuses stale `.profile` or `.zprofile` Hyprland autostart hooks.
- LightDM and any stale greetd service are disabled during activation.
- A rollback helper restores the original FreeBSD console configuration.

## 1. Install Ly and the Dotfiles

```sh
sudo pkg install ly
./scripts/install-dotfiles.sh
```

The Hyprland package must provide this Wayland session entry:

```text
/usr/local/share/wayland-sessions/hyprland.desktop
```

## 2. Stage the Getty Capability

```sh
sudo sh ~/.config/bsdrunner/scripts/bsdrunner-install-ly.sh
```

This adds the `BSDRunnerLy` capability to `/etc/gettytab`, but does not assign
it to a terminal. The current and next boot paths are unchanged.

Run the read-only preflight:

```sh
sh ~/.config/bsdrunner/scripts/bsdrunner-preflight-ly.sh
```

It verifies the package, Ly wrapper and configuration, Hyprland Wayland
session, getty capability, `dbus`, and `seatd`. It does not start Ly or reload
`init`.

Stop here if any check fails.

## 3. Prepare the Recovery Console

The older BSDRunner console path launched Hyprland from login profiles. Remove
only the recognized autostart blocks:

```sh
sh ~/.config/bsdrunner/scripts/bsdrunner-disable-console-autostart.sh --check
sh ~/.config/bsdrunner/scripts/bsdrunner-disable-console-autostart.sh
```

The originals are retained as applicable:

```text
~/.profile.pre-bsdrunner-ly
~/.zprofile.pre-bsdrunner-ly
```

Systems migrated during the earlier LightDM experiment may already have the
equivalent `.pre-bsdrunner-lightdm` backups.

Before activation, switch to another text VT, log in, confirm that it gives you
a normal shell, and exit. Hyprland can always be started manually with
`start-hyprland`.

## 4. Enable Ly for the Next Boot

```sh
sudo sh ~/.config/bsdrunner/scripts/bsdrunner-install-ly.sh \
  --profile "$HOME/.profile" \
  --enable
```

This changes only `ttyv1` to use `BSDRunnerLy`. It leaves `ttyv0` as an enabled
standard getty and does not reload `init`.

Run the strict preflight:

```sh
sh ~/.config/bsdrunner/scripts/bsdrunner-preflight-ly.sh \
  --profile "$HOME/.profile" \
  --activation-ready
```

Stop if any check fails. Otherwise, finish your work and reboot normally:

```sh
sudo shutdown -r now
```

At Ly, select the Hyprland session, enter your username and password, and log
in. Ly saves the last selected session by default. Selecting **Logout** in
BSDRunner exits Hyprland, after which Ly should display its login screen again.

## Recovery and Rollback

If Ly or Hyprland fails, switch to `ttyv0` with `Ctrl`+`Alt`+`F1`, log in, and
run:

```sh
sudo sh ~/.config/bsdrunner/scripts/bsdrunner-rollback-ly.sh
sudo shutdown -r now
```

The rollback restores `/etc/gettytab` and `/etc/ttys`, keeps LightDM and greetd
disabled, and deliberately does not reload `init` underneath the failed login
session. After reboot, log in on the console and run `start-hyprland` manually
if needed.

## Validation

The repository smoke test uses a temporary root, verifies staging and
activation, preserves `ttyv0`, rejects stale profile autostart, and checks the
retained rollback files:

```sh
sh scripts/test-ly.sh
```
