# BSDRunner Privacy and Isolation Roadmap

## Goal

Plan future BSDRunner control surfaces for everyday privacy and isolation work:

- managing FreeBSD jails through a friendly plain-jails-first UI
- managing WireGuard client VPN profiles for laptop privacy
- adding per-file GPG encryption actions to BSDRunner Files

This is a roadmap only. It does not implement any of these features yet.

## Product Shape

These features should feel like the existing BSDRunner system tools: small,
theme-aware Quickshell surfaces backed by shell helpers that normalize system
state into JSON. They should prioritize understandable status, safe defaults,
and explicit confirmation before changing system state.

The preferred implementation order is:

1. Jails
2. WireGuard
3. GPG file actions

## Shared Decisions

### Frontend

Use Quickshell/QML for new graphical tools.

Reasons:

- it matches the existing Files, PF, DNS, ZFS, and Software surfaces
- it can inherit BSDRunner theme palettes
- it keeps UI state separate from privileged system actions

### Backend

Use small shell backends that expose stable JSON contracts.

Each backend should provide a read-only `snapshot` action and narrowly scoped
mutation actions. The UI should treat backend JSON as the source of truth and
surface backend errors directly in status strips or detail panels.

### Privilege Model

Keep the UI unprivileged.

System-changing actions should be confirmation-gated and use the repo's
existing privileged-command pattern when root access is required. V1 tools
should prefer read-mostly status and safe lifecycle actions over broad config
editing.

### Integration

Each new app should follow the existing BSDRunner app shape:

- `~/.config/quickshell/bsdrunner-NAME/shell.qml`
- `~/.config/bsdrunner/scripts/bsdrunner-NAME.sh`
- `~/.config/bsdrunner/scripts/bsdrunner-NAME-backend.sh`
- BSDRunner Apps launcher entry
- documentation page or section
- `scripts/check-qml.sh` coverage when QML files are added

## Jails V1

Jails should be the first concrete feature from this roadmap.

V1 should use plain FreeBSD jails as the baseline rather than requiring
Bastille. The backend should read native jail state with tools such as `jls`,
`jail`, `service jail`, `/etc/jail.conf`, and `/etc/jail.conf.d`. This keeps
BSDRunner useful on a standalone laptop or workstation without adopting a
larger jail framework before the product shape is clear.

Bastille should remain an optional backend for service-jail workflows, not the
required V1 foundation. If Bastille is installed, a later backend mode can use
it for release bootstrapping, templates, cloning, snapshots, quotas, and other
container-management features. If Bastille is not installed, the plain backend
should still work.

The first version should be read-mostly with lifecycle actions only:

- list jails
- show selected jail details
- show state, release, IP, path, and autostart when available
- start, stop, and restart a jail
- open a console in a terminal
- show best-effort recent logs or command output

V1 should not deeply edit jail networking, template systems, or desktop app
permissions. Those are later features once the status and lifecycle workflow
feels trustworthy.

### Provisioning Model

Plain jails share the host kernel but still need a provisioned userland root.
BSDRunner should make this explicit in the UI. A future `Create Jail` workflow
should visibly perform the provisioning steps rather than implying that
`jail(8)` creates a filesystem automatically.

For the first creation workflow, prefer a thick jail because it is easiest to
understand:

- create or select a ZFS dataset/path
- fetch or reuse a FreeBSD `base.txz`
- extract the base userland into the jail root
- create the jail's `/dev` mountpoint
- write a simple `/etc/jail.conf.d/NAME.conf`
- optionally add a host `/etc/hosts` entry
- start the jail only after explicit confirmation

Thin or shared-base jails should come later. They are attractive for many app
jails because they reduce duplication, but they add nullfs mounts and update
coordination that should not be hidden in V1.

### Jail Types

BSDRunner should treat service jails and desktop app jails as related but
different products.

Service jails are for things like Postgres, Redis, nginx, mail, or development
services:

- usually long-running
- often started at boot
- have stable IP and hostname settings
- store application data in a dedicated dataset
- are managed like system services

Desktop app jails are closer to a FreeBSD-native Flatpak-like idea:

- launched on demand from the Apps surface
- need carefully scoped access to display sockets, audio, GPU/device nodes,
  fonts, downloads, clipboard, and selected host folders
- should avoid broad home-directory access by default
- need profile-style permissions rather than only service lifecycle controls

V1 should start with service-style lifecycle management. A desktop app jail
prototype, such as Firefox in a jail, should be a later dedicated experiment
because the display/audio/filesystem integration is the hard part.

### Jail Storage

Jails should use a dedicated ZFS dataset when ZFS is available. The suggested
default for a normal BSDRunner install is:

```text
zroot/jails
```

Use `POOL/jails` as the general pattern when the primary pool is not named
`zroot`. This should be a dataset created inside an existing pool, not a new
pool created from an existing pool.

The Jails app should eventually detect whether a dedicated ZFS-backed storage
location exists. Creating that dataset belongs in the ZFS GUI `Create Dataset`
workflow, not in Jails V1. The ZFS GUI should support ordinary nested dataset
paths such as `jails/postgres` or `jails/firefox` without making jails-specific
assumptions.

### Bastille Role

Bastille should be evaluated as an optional service-jail automation backend.
It may save work for:

- release bootstrapping
- thick/thin jail creation
- templates
- cloning
- snapshots and backups
- quotas and resource limits
- command execution and console helpers

BSDRunner should not assume Bastille provides the whole desktop app sandbox
experience. If BSDRunner pursues Flatpak-like app jails, the UI will still need
BSDRunner-specific permission profiles, launcher integration, and display/audio
mount handling.

## WireGuard V1

WireGuard should focus on laptop client VPN workflows, not router or server
administration.

V1 should manage known client profiles and show active tunnel state:

- detect required tools such as `wg` and the platform's service helpers
- list known client profiles
- show active interface status
- show endpoint, latest handshake, and transfer statistics when available
- import a selected `.conf` profile after validation
- connect, disconnect, and restart a selected profile

The first version should not manage server peers, NAT, routing policy, or a PF
kill switch. A kill-switch profile can be designed later as a separate
networking feature because it crosses into firewall policy.

## GPG In Files

Per-file encryption should start inside BSDRunner Files rather than as a
standalone privacy app.

V1 should add right-click file actions:

- encrypt
- decrypt
- sign
- verify

The UI should prompt for recipient or output filename only when needed, then
show success and error messages in the existing Files status strip. It should
not manage GPG keys in V1. If no usable GPG keys are available, the action
should explain the missing setup and fail safely.

This keeps the feature close to the user's actual workflow: selecting a file,
choosing a privacy action, and continuing navigation.

## Later Work

Possible follow-up features:

- plain jail creation and destruction with strong confirmations
- optional Bastille template and release management
- desktop app jail profiles and launcher integration
- WireGuard profile health checks and DNS leak checks
- optional PF-backed WireGuard kill switch
- GPG recipient favorites
- GPG key status or lightweight key discovery
- native ZFS encryption workflows

ZFS native encryption should remain read-only in the existing ZFS app until it
gets a separate plan. Creating encrypted datasets, loading keys, changing keys,
or migrating data has a different risk profile than per-file GPG actions.

## Test and Acceptance Notes

Roadmap-only changes do not need runtime tests.

When these features are implemented later:

- run `sh scripts/check-qml.sh` for QML changes
- test each backend's missing-dependency path
- test read-only `snapshot` output before mutation actions
- confirm every system-changing action has an explicit confirmation flow
- verify apps launcher entries open the intended Quickshell app
- document manual smoke tests for each feature
