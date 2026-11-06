# Power Settings and Session Locking

BSDRunner starts power management with automatic session locking. This is a
lock, not a logout: applications and the Hyprland session remain running, but
`hyprlock` claims the Wayland session-lock protocol and PAM requires the
current user's password before the desktop can be used again.

The first supported policy is intentionally small:

- automatic locking is enabled by default;
- the default idle delay is 15 minutes;
- the delay can be set from 1 through 120 minutes;
- idle inhibitors from video players and other applications are honored;
- no automatic suspend or display power-off is enabled yet.

Open the panel from **Power Settings** in the BSDRunner welcome window, or
right-click the Waybar power icon. The power menu's **Lock** action uses the
same guarded lock helper.

## Components

- `hypridle` measures Wayland session inactivity.
- `hyprlock` provides the authenticated lock surface.
- `~/.config/bsdrunner/power/profile.conf` stores the friendly settings.
- `~/.config/hypr/hypridle.conf` is generated from that profile.
- `~/.config/hypr/hyprlock.conf` defines the lock screen.

Install the two runtime packages on FreeBSD:

```sh
mdo pkg install hypridle hyprlock
```

The FreeBSD `hyprlock` package installs
`/usr/local/etc/pam.d/hyprlock`, which authenticates through the
`unix-selfauth` PAM service.

## Backend

The panel delegates changes to:

```sh
sh ~/.config/bsdrunner/scripts/bsdrunner-power-backend.sh snapshot
sh ~/.config/bsdrunner/scripts/bsdrunner-power-backend.sh set-timeout 15
sh ~/.config/bsdrunner/scripts/bsdrunner-power-backend.sh set-enabled yes
```

Changing a setting regenerates the idle configuration and restarts only the
current user's `hypridle` process. Locking is handled separately by:

```sh
sh ~/.config/bsdrunner/scripts/bsdrunner-lock.sh
```

## Validation

```sh
sh scripts/test-power.sh
sh scripts/check-qml.sh
```
