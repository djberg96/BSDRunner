# BSDRunner Jails

BSDRunner Jails is a first-pass Quickshell control surface for learning and
operating FreeBSD jails.

The UI is intentionally read-mostly. It helps a new user answer:

- what jails exist
- whether each jail is running or only configured
- whether native FreeBSD jail tools or Bastille are available
- what path, hostname, IP address, JID, and backend a selected jail uses
- which lifecycle actions are safe for the selected state

## Launch

After installing the dotfiles:

```sh
sh ~/.config/bsdrunner/scripts/bsdrunner-jails.sh
```

The Apps menu also includes a Jails entry.

## Backend

The launcher runs:

```sh
~/.config/bsdrunner/scripts/bsdrunner-jails-backend.sh snapshot
```

The snapshot action returns JSON with:

- tool detection for `jls`, `jail`, `service`, `bastille`, and `mdo`
- `jail_enable` and `bastille_enable` service settings when `sysrc` exists
- running native jails from `jls -n`
- configured native jails from `/etc/jail.conf` and `/etc/jail.conf.d/*.conf`
- Bastille jails from `bastille list -a` when Bastille is installed
- the last action result

Lifecycle actions are deliberately narrow:

```sh
bsdrunner-jails-backend.sh start NAME native
bsdrunner-jails-backend.sh stop NAME native
bsdrunner-jails-backend.sh restart NAME native
bsdrunner-jails-backend.sh console NAME native
```

For Bastille-backed rows, the third argument is `bastille` and the backend calls
`bastille start`, `bastille stop`, `bastille restart`, or `bastille console`.

If `mdo` is available, lifecycle commands use it for privilege escalation. If it
is not available, the backend runs the command directly and expects the caller to
already have the required privileges.

## Beginner Model

The UI treats jail creation as four visible concepts:

1. Storage: the jail needs a filesystem root, preferably a ZFS dataset.
2. Userland: a FreeBSD release or base tree must be fetched or extracted.
3. Config: `jail.conf` gives the jail its name, path, hostname, IP, and startup behavior.
4. Lifecycle: once configured, everyday work is start, stop, restart, and console.

This is why V1 does not include a live create wizard. A safe creation workflow
will need strong validation around datasets, release downloads, `devfs`, network
settings, and generated `/etc/jail.conf.d/NAME.conf` files.

## Bastille

Bastille is treated as an optional automation backend, not a requirement. When it
is installed, BSDRunner can list Bastille jails and call Bastille lifecycle
commands. When it is absent, the native jail view still works.

This keeps the learning path FreeBSD-native while leaving room for Bastille's
useful features: bootstrapping releases, templates, cloning, snapshots, and
resource limits.

## Acceptance Checks

On a development machine without FreeBSD jail tools, the backend should still
return valid JSON:

```sh
sh dotfiles/.config/bsdrunner/scripts/bsdrunner-jails-backend.sh snapshot
```

On FreeBSD with configured jails:

```sh
jls -n
service jail onestatus
bastille list -a
```

Then open the UI and confirm that the list, details, backend detection, and
guarded lifecycle actions match the command-line state.
