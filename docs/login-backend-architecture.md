# Login Backend Architecture

This document defines the **real login path** BSDRunner should grow into.

The current Quickshell greeter already proves:

- themed UI
- wallpaper selection
- field/input behavior
- PAM credential checking
- power-action wiring

What it does **not** yet do is launch a true logged-in desktop for an arbitrary user.

## Goal

Split the login system into two clearly separated layers:

1. **Unprivileged greeter UI**
2. **Privileged session launcher**

That keeps the visible interface pleasant to iterate on while keeping the security-sensitive logic small and auditable.

## Current State

Today the repo contains:

- the Quickshell greeter UI
- a local PAM policy for the greeter
- a preview action path
- a session-command scaffold:

```sh
sh ~/.config/bsdrunner/scripts/bsdrunner-greeter-session.sh BSDRunner
```

That session script is the first reusable backend hook. It currently knows how to launch:

- `BSDRunner`
  - touches `~/.config/bsdrunner/show-welcome-at-startup`
  - launches `Hyprland`
  - prefers `dbus-run-session Hyprland` when available
- `Terminal`
  - launches the user’s login shell

## Recommended Real Architecture

### Layer 1: Greeter UI

Keep the existing Quickshell surface responsible for:

- username/password entry
- session selection
- wallpaper/theme rendering
- feedback and errors
- calling PAM auth
- asking the backend to start a session only after successful auth

The greeter should **not**:

- own the seat/TTY
- launch another user session directly
- pass passwords through shell arguments or environment variables
- run as an all-powerful root UI process

### Layer 2: Privileged Launcher

Add a small privileged backend whose only jobs are:

- own the seat/session context
- accept a successful authenticated user + selected session
- set up the user environment correctly
- switch to the user
- execute:

```sh
sh ~/.config/bsdrunner/scripts/bsdrunner-greeter-session.sh SESSION
```

This backend should stay intentionally narrow.

## Best First Implementation

The safest first implementation is:

1. keep PAM in the greeter UI
2. let a real display-manager backend own session startup
3. use the session wrapper above as the command that backend launches

That avoids inventing a custom setuid login manager too early.

## Backend Options

### Preferred

A display-manager path that already understands:

- TTY ownership
- seat/session lifecycle
- session cleanup
- user switching

Examples:

- `greetd` if/when it is available in the target package path
- another FreeBSD-available display manager with a Wayland-compatible launch path

### Last Resort

A custom privileged helper.

This is possible, but should be treated as the highest-risk path because it must correctly handle:

- privilege transitions
- environment scrubbing
- session setup
- child lifecycle
- error cleanup

If BSDRunner eventually needs this route, the helper should be a very small root-owned program, not a broad shell script.

## Security Rules

The real backend must obey these rules:

- never pass passwords on the command line
- never store passwords in world-readable temp files
- never treat the current desktop user as proof of successful auth
- never let the UI directly `su`, `sudo`, `doas`, or `mdo` into another user session
- keep auth and session launch as separate concerns

## Proposed Flow

1. User enters username/password in the greeter.
2. Greeter authenticates through PAM.
3. On success, greeter requests `start session X for user Y`.
4. Privileged backend validates request context.
5. Backend switches to the user/session safely.
6. Backend runs:

```sh
sh ~/.config/bsdrunner/scripts/bsdrunner-greeter-session.sh BSDRunner
```

7. Greeter exits.

## Near-Term Milestones

### Done

- Quickshell greeter UI
- PAM auth in preview mode
- session wrapper scaffold

### Next

- replace preview launch with real backend session launch
- decide which display-manager/backend path is actually available on the laptop
- connect successful auth to that backend

### Later

- true multi-user login
- proper failed-login delay / retry behavior
- user listing or last-user memory
- session chooser expansion beyond `BSDRunner` and `Terminal`
