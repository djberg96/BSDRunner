# Graphical Login Screen

BSDRunner ships a native graphical greetd client for FreeBSD. It reuses the
earlier BSDRunner Quickshell login design and replaces the abandoned custom PAM
helpers with a small Rust bridge to greetd.

The split is deliberate:

- Quickshell renders the themed username, password, session, and status UI.
- `bsdrunner-greetd-greeter` translates newline-delimited JSON from the UI into
  greetd IPC messages.
- greetd owns PAM, the VT, user/group changes, and session lifetime.
- a minimal Hyprland instance hosts only the greeter.

Both the greeter and the `Terminal` fallback use native Hyprland Lua configs;
they do not depend on the legacy `.conf` format removed in Hyprland 0.57.

Passwords travel from Quickshell to the bridge over stdin and from the bridge
to greetd over its Unix socket. They are never placed in argv, the environment,
or a temporary file.

## Prerequisites

The FreeBSD-enabled greetd build must already be installed and its `greeter`
account and PAM services must exist. You also need:

```sh
mdo pkg install quickshell rust dbus seatd hyprland
```

Enable DBus and seatd before activating greetd:

```sh
mdo sysrc dbus_enable=YES
mdo sysrc seatd_enable=YES
mdo service dbus start
mdo service seatd start
```

## Build and Stage

From the BSDRunner repository:

```sh
./scripts/install-greetd-greeter.sh --theme jinteki
```

Omit `--theme` to use the current BSDRunner theme. This command builds the Rust
bridge and installs a self-contained bundle under `/etc/greetd/bsdrunner`, but
does not replace the active greetd configuration.

The installer creates a timestamped backup of an existing BSDRunner bundle.

The greeter launcher uses the PAM-provided `XDG_RUNTIME_DIR` when available.
FreeBSD's minimal `greetd-greeter` PAM service does not create one, so the
launcher securely creates a private temporary runtime directory before
Hyprland starts and removes it when the compositor exits.

## Activate

Once the staged files are present:

```sh
./scripts/install-greetd-greeter.sh --theme jinteki --activate
mdo sysrc greetd_enable=YES
```

`--activate` backs up the current
`/usr/local/etc/greetd/config.toml` before installing the BSDRunner config. The
config uses VT 9 (`ttyv8`); keep `ttyv0` enabled as the recovery console and do
not assign another display manager to `ttyv8`.

Do the first live test without rebooting:

```sh
mdo service greetd onestart
```

If the keyboard initially produces escape-prefixed characters such as `^[d`,
tap the left Alt key once. FreeBSD's VT switch can retain a stale Alt modifier.

Select `Terminal` for the first successful login. It starts a deliberately
small Hyprland session containing only a terminal. Then test the full
`BSDRunner` session.

## Returning From a Test Session

With current Hyprland Lua dispatchers, exit the session with:

```sh
hyprctl dispatch 'hl.dsp.exit()'
```

greetd should regain VT 9 and show the greeter again.

## Logging Out

The wlogout `Logout` action runs
`~/.config/bsdrunner/scripts/bsdrunner-logout.sh`. The helper only asks the
current user-owned Hyprland compositor to exit. greetd observes the session
ending, cleans up the login's remaining process tree, reclaims VT 9, and
starts a new graphical greeter.

BSDRunner's FreeBSD greetd build makes each session worker a process reaper.
This keeps applications that daemonize or create a new process group, such as
Code and D-Bus, scoped to the login that launched them. When Hyprland exits,
greetd first gives those remaining descendants two seconds to terminate and
then kills only that session's stragglers. Processes from SSH connections,
recovery consoles, and other logins are outside that reaper tree.

The helper deliberately does not call `vidcontrol`, switch to a recovery VT,
restart greetd, or use elevated privileges. Those operations race the login
manager and previously left the FreeBSD VT in an unusable state.

## Recovery

From a graphical failure, press `Ctrl+Alt+F1`. From a text VT, use `Alt+F1`.
Log in on `ttyv0`. Each greeter launch keeps private diagnostic logs in a
randomly named directory under `/var/tmp`, which survives a reboot. Find the
newest directory before or after recovery:

```sh
mdo find /var/tmp -maxdepth 1 -type d \
  -name 'bsdrunner-greeter-log.*' -print
```

Use the exact newest path to inspect `launcher.log`, `hyprland.log`, and, if
the UI started, `quickshell.log`:

```sh
mdo cat /var/tmp/bsdrunner-greeter-log.XXXXXX/launcher.log
mdo cat /var/tmp/bsdrunner-greeter-log.XXXXXX/hyprland.log
mdo cat /var/tmp/bsdrunner-greeter-log.XXXXXX/quickshell.log
```

Then stop and disable greetd:

```sh
mdo service greetd stop
mdo sysrc greetd_enable=NO
```

Find the config backup made during activation:

```sh
ls -1t /usr/local/etc/greetd/config.toml.pre-bsdrunner-*
```

Restore the newest known-good file, substituting its exact name:

```sh
mdo install -m 0644 \
  /usr/local/etc/greetd/config.toml.pre-bsdrunner-YYYYMMDD-HHMMSS \
  /usr/local/etc/greetd/config.toml
```

If the TTY assignments were changed separately, restore the existing
`/etc/ttys.greetd-backup-*` backup as well. Reboot only after the service is
disabled and the recovery console is confirmed available.

## Development Checks

The bridge includes a fake-greetd integration test that exercises a secret PAM
prompt and session start without touching the live daemon:

```sh
cargo test --manifest-path greeter/Cargo.toml --locked
cargo clippy --manifest-path greeter/Cargo.toml --locked --all-targets -- -D warnings
sh greeter/tests/launcher.sh
```

QML files are included in `scripts/check-qml.sh`.

```sh
sh scripts/check-qml.sh
```
