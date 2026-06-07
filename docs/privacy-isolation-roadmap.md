# BSDRunner Privacy and Isolation Roadmap

## Goal

Plan future BSDRunner control surfaces for everyday privacy and isolation work:

- managing FreeBSD jails through a friendly Bastille-backed UI
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

V1 should use Bastille as the management layer rather than editing raw
`jail.conf`. If Bastille is not installed, the backend should return a clear
missing-dependency status with install guidance instead of failing silently.

The first version should be read-mostly with lifecycle actions only:

- list jails
- show selected jail details
- show state, release, IP, path, and autostart when available
- start, stop, and restart a jail
- open a console in a terminal
- show best-effort recent logs or command output

V1 should not create, destroy, clone, template, upgrade, or deeply edit jail
networking. Those are later features once the status and lifecycle workflow
feels trustworthy.

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

- jail creation and destruction with strong confirmations
- Bastille template and release management
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
