# BSDRunner Jails

BSDRunner Jails is a first-pass Quickshell control surface for learning and
operating FreeBSD jails.

The UI is intentionally read-mostly. It helps a new user answer:

- what jails exist
- whether each jail is running or only configured
- whether native FreeBSD jail tools or Bastille are available
- what path, hostname, IP address, JID, and backend a selected jail uses
- which lifecycle actions are safe for the selected state
- what a proposed Bastille thick-jail creation would do before any command runs
- how storage, userland, configuration, and lifecycle fit together while creating
  a basic jail through a guarded wizard

## Launch

After installing the dotfiles:

```sh
sh ~/.config/bsdrunner/scripts/bsdrunner-jails.sh
```

The Apps menu also includes a Jails entry.

To explore the complete UI on a development machine without FreeBSD jail tools,
launch the installed app with the bundled sample snapshot:

```sh
sh ~/.config/bsdrunner/scripts/bsdrunner-jails.sh --demo
```

Demo mode shows running native, configured native, and stopped Bastille-backed
jails. It is read-only: the backend rejects start, stop, restart, and console
requests while the demo fixture is active. The installed fixture lives at
`~/.config/bsdrunner/jails/demo-snapshot.json`.

The **Create Basic Jail** wizard remains available in demo mode so every step and
the generated plan can be explored. Its final creation action is disabled.

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
- the host FreeBSD release, Bastille setup readiness, and bootstrapped releases
- detected ZFS pools plus Bastille's configured pool, dataset prefix, and
  initialization state
- Bastille jail hostname, path, address, release, and boot setting from
  `bastille config ALL get ...`, with `bastille list all` and the deprecated
  `bastille list -a` form as compatibility fallbacks
- the last action result

Some Bastille releases require root even for inventory commands. The backend
first tries the read directly, then retries it through `mdo` when available.
These probes only read Bastille state.

The Storage step distinguishes **configured** storage from **initialized**
storage. Configured means Bastille has ZFS enabled with a selected pool and
dataset prefix. Initialized means its installation root plus the `jails` and
`releases` directories already exist and the release inventory is readable.

When Bastille is installed but storage is unconfigured, the wizard detects
available pools and previews the conventional `POOL/bastille` target. It then
requires the selected pool name before running the narrowly scoped action:

```sh
bsdrunner-jails-backend.sh storage-preview zroot
bsdrunner-jails-backend.sh storage-setup zroot zroot
```

The first command is read-only. The second dispatches only `bastille setup
storage zroot`; it does not run full `bastille setup`, change PF, configure
interfaces, or modify unrelated datasets. Bastille records the pool at this
stage. The first release bootstrap creates the `POOL/bastille` dataset hierarchy
and mounts its installation root. If Bastille already has initialized
filesystem-backed storage, the backend refuses to convert it implicitly.

Lifecycle actions are deliberately narrow:

```sh
bsdrunner-jails-backend.sh start NAME native
bsdrunner-jails-backend.sh stop NAME native
bsdrunner-jails-backend.sh restart NAME native
bsdrunner-jails-backend.sh console NAME native
```

For Bastille-backed rows, the third argument is `bastille` and the backend calls
`bastille start`, `bastille stop`, `bastille restart`, or `bastille console`.

The wizard's read-only review step accepts a jail name, FreeBSD release, IP
address or CIDR, and an autostart preference:

```sh
bsdrunner-jails-backend.sh preview web 15.0-RELEASE 10.0.0.20/24 yes
```

It returns JSON containing the validated inputs, host checks, and exact Bastille
commands. It does not invoke a mutating Bastille command, download a release,
create storage, or write config. The preview checks whether Bastille is set up,
whether the release is already bootstrapped, whether the jail name or address
collides with detected jails, and whether the proposed jail release is newer
than the host. An existing release skips the redundant bootstrap command;
otherwise the plan includes it.

The current preview deliberately plans a thick service jail. Choosing no
autostart adds Bastille's `--no-boot` option. A failed readiness check is shown
as a warning and leaves the generated commands visible for inspection, but the
UI still never executes them.

After the user types the proposed jail name on the final Lifecycle step, the UI
may run two separately guarded actions:

```sh
bsdrunner-jails-backend.sh bootstrap 15.0-RELEASE 15.0-RELEASE
bsdrunner-jails-backend.sh create web 15.0-RELEASE 10.0.0.20/24 yes web
```

The last argument is an exact confirmation value. Bootstrap is skipped when the
release already exists. A configured but empty ZFS installation is allowed to
bootstrap because that command is what initializes Bastille's dataset hierarchy.
Before creation, the backend checks the release, jail
name, address, Bastille availability, and setup state again; it then passes each
validated value to Bastille as a separate command argument. A successful release
download followed by a failed create is reported as a partial result instead of
being hidden.

If `mdo` is available, lifecycle commands use it for privilege escalation. If it
is not available, the backend runs the command directly and expects the caller to
already have the required privileges.

## Beginner Model

The UI treats jail creation as four visible concepts:

1. Storage: the jail needs a filesystem root, preferably a ZFS dataset.
2. Userland: a FreeBSD release or base tree must be fetched or extracted.
3. Config: `jail.conf` gives the jail its name, path, hostname, IP, and startup behavior.
4. Lifecycle: once configured, everyday work is start, stop, restart, and console.

The **Create Basic Jail** wizard follows those four concepts directly. Storage
selects and configures a ZFS pool when necessary, Userland selects or
bootstraps a release, Config collects the name/address/startup policy, and
Lifecycle presents the exact plan and typed confirmation. The initial target is
deliberately a thick Bastille service jail. A future native workflow will need
separate validation around datasets, release extraction, `devfs`, network
settings, and generated `/etc/jail.conf.d/NAME.conf` files.

## Bastille

Bastille is the assumed managed-jail backend, while native FreeBSD jails remain
the no-dependency baseline. When Bastille is installed, BSDRunner can list its
jails with release and boot metadata, call its lifecycle commands, and guide a
user through thick-jail creation against the current host. When it is absent,
native jail status still works and the wizard explains which setup prerequisite
is missing.

This keeps the learning path FreeBSD-native while leaving room for Bastille's
useful features: bootstrapping releases, templates, cloning, snapshots, and
resource limits.

## Automated Tests

The fixture-backed backend suite runs without FreeBSD jail tools or root access.
It supplies representative `jls`, `jail.conf`, `sysrc`, `bastille list`,
`bastille config`, release inventory, and host-release results through an
isolated test path. The suite checks rich snapshot parsing, ZFS pool discovery,
storage preview and guarded setup, configured-but-uninitialized bootstrap,
bootstrapped and missing-release plans, name and address collisions, host
compatibility, demo-mode guards, guarded bootstrap and creation dispatch, typed
confirmations, last-second validation failures, lifecycle dispatch, and
persisted action status.

The suite requires `jq`:

```sh
sh scripts/test-jails-backend.sh
```

The `BSDRUNNER_JAILS_TEST_*` environment variables used by this suite only take
effect when `BSDRUNNER_JAILS_TEST_MODE=1`; normal launches continue to read the
host's `/etc` and standard FreeBSD command paths.

## Acceptance Checks

Run the automated backend suite and QML validation from the repository root:

```sh
sh scripts/test-jails-backend.sh
sh scripts/check-qml.sh
```

On a development machine without FreeBSD jail tools, the live backend should
also return valid JSON:

```sh
sh dotfiles/.config/bsdrunner/scripts/bsdrunner-jails-backend.sh snapshot
```

On FreeBSD with configured jails:

```sh
jls -n
service jail onestatus
bastille list all
bastille list releases
bastille config ALL get host.hostname,path,ip4.addr,osrelease,boot
```

Then open the UI and confirm that the list, details, backend detection, and
guarded lifecycle actions match the command-line state. Open **Create Basic
Jail** and confirm the Storage page shows the expected pool and conventional
`POOL/bastille` target, then verify that the Userland, Config, and Lifecycle
pages match the host. Stop at either typed confirmation unless storage setup or
a test jail is genuinely wanted. When exercising creation, use an unused
name/address and verify the resulting jail appears automatically in the
inventory.
