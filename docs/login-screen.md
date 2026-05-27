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
- the active BSDRunner palette and theme name
- a real login-style layout:
  - username field
  - password field
  - session picker
  - sign-in button
  - shutdown and restart placeholders

## What Does Not Exist Yet

This is not yet a real login manager.

Missing pieces:

- PAM authentication
- privileged session startup
- real power actions
- seat/session ownership
- a display-manager backend

So the current greeter is best thought of as:

- a native BSDRunner login-screen UI prototype
- a design surface we can iterate on
- a front-end that can later be attached to a proper backend

## How To Preview It

After installing the dotfiles on a machine with `qs` available:

```sh
theme="$(cat ~/.config/bsdrunner/current-theme 2>/dev/null || echo default)"
./scripts/install-dotfiles.sh --theme "$theme"
sh ~/.config/bsdrunner/scripts/bsdrunner-apply-theme.sh "$theme"
sh ~/.config/bsdrunner/scripts/bsdrunner-greeter.sh
```

## Current Design Goals

The prototype is meant to prove:

- BSDRunner’s theme system works at the greeter layer
- a random wallpaper background can be rerolled cleanly
- a login screen can feel like part of BSDRunner rather than a bolted-on system component

## Future Direction

The likely long-term path is:

1. keep this Quickshell surface as the visible greeter UI
2. add a small privileged authentication/session backend
3. attach the two through a minimal, well-defined interface

That keeps the design work and the security-sensitive work separate.
