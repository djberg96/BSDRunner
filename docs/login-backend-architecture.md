# Login Backend Architecture

BSDRunner's login path has three deliberately narrow layers:

```text
BSDRunner Quickshell UI
        | newline-delimited JSON on stdin/stdout
bsdrunner-greetd-greeter
        | greetd IPC on GREETD_SOCK
greetd + PAM
        | authenticated user session
BSDRunner session wrapper
```

## Quickshell UI

The unprivileged UI owns presentation only: theme and wallpaper rendering,
username entry, interactive PAM responses, session selection, and error
feedback. It has no root helper and cannot switch users itself.

## Native Bridge

The Rust bridge is executed as the `greeter` user. It accepts a fixed set of
JSON messages from the UI, preserves greetd's interactive visible/secret PAM
prompts, and maps the two UI session choices to fixed commands. It does not
accept arbitrary commands from QML.

The bridge never performs PAM or privilege changes. It never receives root
credentials. Its only privileged relationship is the greetd-owned Unix socket
provided in `GREETD_SOCK`.

## greetd

greetd remains the security boundary. It owns:

- PAM authentication and account checks
- the controlling VT
- supplementary groups, UID, and GID transition
- the authenticated user's environment and home directory
- session lifetime and PAM cleanup

On success, greetd runs the installed user's wrapper:

```sh
/bin/sh $HOME/.config/bsdrunner/scripts/bsdrunner-greeter-session.sh SESSION
```

`SESSION` is either `BSDRunner` or `Terminal`; that value is selected from a
Rust enum rather than passed through from arbitrary UI input.

## Security Invariants

- Passwords are never passed in argv or environment variables.
- The UI and bridge run as the unprivileged `greeter` account.
- No BSDRunner code duplicates PAM, `setuid`, group, or TTY lifecycle logic.
- The bridge's session commands are allowlisted.
- Closing the UI cancels an unfinished greetd session.
- `ttyv0` remains independent of greetd for recovery.
