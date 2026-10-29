# BSDRunner Jails

BSDRunner Jails is a first-pass Quickshell control surface for learning and
operating FreeBSD jails.

The UI is intentionally read-mostly. It helps a new user answer:

- what jails exist
- whether each jail is running or only configured
- whether native FreeBSD jail tools or Bastille are available
- what path, hostname, IP address, JID, and backend a selected jail uses
- which lifecycle actions are safe for the selected state
- what a proposed Bastille thick- or thin-jail creation would do before any command runs
- how storage, userland, networking, configuration, and lifecycle fit together
  while creating a basic jail through a guarded wizard

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
- Bastille loopback, PF, NAT, anchor, uplink, and recommended-address readiness
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

The Network step is separate from storage and exposes the host state it relies
on. Its snapshot checks for Bastille's configured loopback interface, a running
PF ruleset, the `<jails>` NAT rule, Bastille's redirect and filter anchors, the
default-route interface, and a host-aware recommended address. The recommendation
prefers an unused address in `10.0.0.0/24` when that subnet does not overlap a
host route; otherwise it selects another private subnet. A proposed address is
also checked again during preview and immediately before creation.

Network setup has a read-only preview and an exact typed confirmation:

```sh
bsdrunner-jails-backend.sh network-preview 10.0.0.20/24
bsdrunner-jails-backend.sh network-setup 10.0.0.20/24 10.0.0.20/24
```

The mutating action does not run the broad `bastille setup` command. If needed,
it runs only `bastille setup --yes loopback`, using the UI's typed confirmation
instead of opening a second interactive prompt. It verifies the interface, then
asks BSDRunner's PF backend to enable jail networking on the detected uplink. That
backend renders and syntax-checks the complete managed profile before installing
and reloading it. If loopback setup succeeds but PF setup fails, the UI reports
the partial result and leaves creation blocked until all readiness checks pass.

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
address or CIDR, and an autostart preference.

The release field defaults to the detected host release without its patch-level
suffix (`15.1-RELEASE-p6` becomes `15.1-RELEASE`). If the host release cannot be
normalized, the wizard falls back to the latest bootstrapped Bastille release.

For example:

```sh
bsdrunner-jails-backend.sh preview web 15.0-RELEASE 10.0.0.20/24 yes
```

It returns JSON containing the validated inputs, host checks, and exact Bastille
commands. It does not invoke a mutating Bastille command, download a release,
create storage, or write config. The preview checks whether Bastille is set up,
whether the release is already bootstrapped, whether the jail name or address
collides with detected jails, whether networking is ready, whether the proposed
address overlaps a host route, and whether the proposed jail release is newer
than the host. An existing release skips the redundant bootstrap command;
otherwise the plan includes it.

The optional final argument selects `thick` or `thin`; omitting it preserves the
beginner-friendly `thick` default:

```sh
bsdrunner-jails-backend.sh preview web 15.0-RELEASE 10.0.0.20/24 yes thin
```

Thick uses Bastille's `--thick` flag and gives the jail an independent userland
copy. Thin uses Bastille's default shared-base layout and omits that flag.
Choosing no autostart adds Bastille's `--no-boot` option. A failed readiness check is shown
as a warning and leaves the generated commands visible for inspection. Preview
never executes them; the final Lifecycle step requires separate confirmation.

The beginner picker remains FreeBSD-only. Bastille's experimental Linux mode
needs separate Linux compatibility and debootstrap setup, while Clone is a
ZFS-specific workflow; both are intentionally deferred to a future Advanced
path instead of being mixed into the basic release list.

After the user types the proposed jail name on the final Lifecycle step, the UI
may run two separately guarded actions:

```sh
bsdrunner-jails-backend.sh bootstrap 15.0-RELEASE 15.0-RELEASE
bsdrunner-jails-backend.sh create web 15.0-RELEASE 10.0.0.20/24 yes web thick
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

The UI treats jail creation as five visible concepts:

1. Storage: the jail needs a filesystem root, preferably a ZFS dataset.
2. Userland: a FreeBSD release or base tree must be fetched or extracted.
3. Network: the jail needs a non-overlapping address, a loopback interface, and
   PF NAT/anchors to reach the outside network.
4. Config: the jail gets its name, hostname, address, and startup behavior.
5. Lifecycle: once configured, everyday work is start, stop, restart, and console.

The **Create Basic Jail** wizard follows those five concepts directly. Storage
selects and configures a ZFS pool when necessary, Userland selects or
bootstraps a release, presents common release choices, and selects a Thick or
Thin userland. Network validates the address and can configure the narrow
Bastille/PF prerequisites, Config collects the name/startup policy, and Lifecycle
presents the exact plan and typed confirmation. Thick remains the recommended
default; Thin is available for users comfortable managing a shared release base.
A future native workflow will need
separate validation around datasets, release extraction, `devfs`, network
settings, and generated `/etc/jail.conf.d/NAME.conf` files.

## Bastille

Bastille is the assumed managed-jail backend, while native FreeBSD jails remain
the no-dependency baseline. When Bastille is installed, BSDRunner can list its
jails with release and boot metadata, call its lifecycle commands, and guide a
user through thick- or thin-jail creation against the current host. When it is
absent,
native jail status still works and the wizard explains which setup prerequisite
is missing.

This keeps the learning path FreeBSD-native while leaving room for Bastille's
useful features: bootstrapping releases, templates, cloning, snapshots, and
resource limits.

## Automated Tests

The fixture-backed backend suite runs without FreeBSD jail tools or root access.
It supplies representative `jls`, `jail.conf`, `sysrc`, `ifconfig`, `route`,
`pfctl`, `bastille list`, `bastille config`, release inventory, and host-release
results through an isolated test path. The suite checks rich snapshot parsing, ZFS pool discovery,
storage preview and guarded setup, configured-but-uninitialized bootstrap,
network recommendation, route-overlap checks, narrow loopback/PF setup,
bootstrapped and missing-release plans, exact thick/thin commands, invalid type
rejection, name and address collisions, host
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
sh scripts/test-pf-profile.sh
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
`POOL/bastille` target, then verify that the Userland, Network, Config, and
Lifecycle pages match the host. Confirm that Network reports the expected
uplink, non-overlapping recommendation, loopback, PF NAT, and anchors. Stop at any typed
confirmation unless storage/network setup or a test jail is genuinely wanted.
When exercising creation, use an unused
name/address and verify the resulting jail appears automatically in the
inventory.
