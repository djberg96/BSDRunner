# Graphical Login Screen

This branch currently contains a **native BSDRunner greeter UI prototype** built in Quickshell.

It is intentionally only the front-end layer for now.

## What Exists

The prototype includes:

- a dedicated Quickshell surface under `dotfiles/.config/quickshell/bsdrunner-greeter/`
- a small launcher script:

```sh
sh ~/.config/bsdrunner/scripts/bsdrunner-greeter.sh
```

- a wallpaper helper that rerolls a random static BSDRunner wallpaper on launch
- a minimal dedicated Hyprland greeter session config:
  - `~/.config/hypr/bsdrunner-greeter.conf`
- a dedicated greeter-session launcher:
  - `sh ~/.config/bsdrunner/scripts/bsdrunner-start-greeter-session.sh`
- the active BSDRunner palette and theme name
- a real login-style layout:
  - username field
  - password field
  - session picker
  - sign-in button
  - shutdown and restart controls

## What Does Not Exist Yet

This is not yet a real login manager.

Missing pieces:

- privileged session startup
- seat/session ownership
- a display-manager backend

Current interaction status:

- In normal preview mode, `Sign In` performs **real root-backed authentication** through a small BSDRunner helper before any session action is launched.
- After successful authentication in preview mode, the prototype currently only launches a **preview action** for the current desktop user:
  - `BSDRunner` opens the BSDRunner welcome surface
  - `Terminal` launches `kitty`
- If you authenticate as some other user in preview mode, the greeter reports success honestly but refuses to fake a cross-user desktop launch.
- In `BSDRUNNER_GREETER_REAL_BACKEND=1` mode, `Sign In` switches to a root-backed login helper that authenticates and then launches the selected BSDRunner session as the requested user.
- The dedicated greeter-session launcher now uses that real-backend mode automatically and exits its own Hyprland greeter compositor after the Quickshell greeter closes.
- `Shutdown` and `Restart` now call a real backend helper and will use:
  - `mdo` if available
  - otherwise `doas`
  - otherwise direct `shutdown` only when already running as root

Notes:

- The auth helper is built locally from:
  - `~/.config/bsdrunner/scripts/bsdrunner-greeter-auth-helper.c`
- The login-and-launch helper is built locally from:
  - `~/.config/bsdrunner/scripts/bsdrunner-greeter-login-helper.c`
- Build it with:

```sh
sh ~/.config/bsdrunner/scripts/bsdrunner-build-greeter-backend.sh
```

- The helper is then invoked through:
  - `mdo` if available
  - otherwise `doas`
  - otherwise direct root execution only when already root
- This gets us a real privileged authentication path without placing the password in argv.
- The real-backend mode is a serious step forward, but it is still not a full display manager yet:
  - there is still no seat manager or greeter-owned TTY lifecycle
  - `BSDRunner` should now be tested from the dedicated greeter-session launcher, not from inside an already-running desktop
  - `Terminal` is still the safest first real-backend smoke test

So the current greeter is best thought of as:

- a native BSDRunner login-screen UI prototype
- a design surface we can iterate on
- a front-end that can later be attached to a proper backend

For the actual backend split and session-launch plan, see:

- [docs/login-backend-architecture.md](login-backend-architecture.md)

## How To Preview It

After installing the dotfiles on a machine with `qs` available:

```sh
theme="$(cat ~/.config/bsdrunner/current-theme 2>/dev/null || echo default)"
./scripts/install-dotfiles.sh --theme "$theme"
sh ~/.config/bsdrunner/scripts/bsdrunner-apply-theme.sh "$theme"
sh ~/.config/bsdrunner/scripts/bsdrunner-greeter.sh
```

If you are iterating on just the greeter prototype and want to force-refresh only the greeter files into `~/.config`, use:

```sh
./scripts/sync-greeter-prototype.sh
```

Then build the auth helper once on the target FreeBSD machine:

```sh
sh ~/.config/bsdrunner/scripts/bsdrunner-build-greeter-backend.sh
```

To try the more realistic backend path locally after that, launch the greeter with:

```sh
BSDRUNNER_GREETER_REAL_BACKEND=1 sh ~/.config/bsdrunner/scripts/bsdrunner-greeter.sh
```

For that mode, prefer testing the `Terminal` session first.

To run the greeter in its own minimal Hyprland session instead of inside your current desktop:

```sh
sh ~/.config/bsdrunner/scripts/bsdrunner-start-greeter-session.sh
```

That is the current closest thing to a real integrated login path in BSDRunner.

## Current Design Goals

The prototype is meant to prove:

- BSDRunner’s theme system works at the greeter layer
- a random wallpaper background can be rerolled cleanly
- a login screen can feel like part of BSDRunner rather than a bolted-on system component

## Future Direction

The backend architecture is now tracked separately in:

- [docs/login-backend-architecture.md](login-backend-architecture.md)
