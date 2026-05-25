# BSDRunner Software Center

## Goal

Design a graphical software manager for FreeBSD that:

- fits BSDRunner visually and behaviorally
- uses `mdo` for privileged package actions instead of `sudo`
- feels safer and friendlier than a terminal-first `pkg` workflow
- can inherit the existing BSDRunner corp themes
- can grow from a read-only browser into a full package management surface

This document is the architecture draft for that work. It is intentionally biased toward a clean path into a real prototype.

## Product Shape

Working name:

- `BSDRunner Software`

User-facing intent:

- browse available packages
- search quickly
- inspect package details before acting
- review installed packages
- review pending updates
- perform installs, removals, and upgrades through explicit confirmation flows

The first shipped version should feel like a desktop control surface, not a generic package frontend.

## Why This Fits BSDRunner

BSDRunner already has the pieces we need:

- Quickshell is already used for the welcome window
- the current theme is stored in `~/.config/bsdrunner/current-theme`
- corp themes already define shared palette values in `themes/*/palette.conf`
- the theme docs explicitly leave room for optional control surfaces

That means the software center should be built as a sibling Quickshell app with shared theme loading, not as a disconnected one-off tool.

## Core Decisions

### Frontend

Use Quickshell/QML for the UI.

Reasons:

- it matches the existing welcome surface
- it can look much better than a stock package manager
- it is easy to make theme-aware
- it keeps the UI logic separate from privileged package actions

### Backend

Use small shell wrapper scripts around `pkg` and `mdo`.

Reasons:

- the desktop already leans on shell helpers
- `pkg` is the real source of truth
- wrappers give us a stable contract for the UI
- wrappers let us normalize output into JSON and hide command noise

### Privilege Model

Keep the UI unprivileged.

Only privileged actions should cross into `mdo`:

- install package
- remove package
- upgrade selected package or all packages
- refresh repo metadata if needed

Read-only queries should remain unprivileged whenever possible.

This keeps the architecture safer and easier to reason about than mixing UI state with root-like execution.

## UX Principles

- Default to read-only browsing until the user chooses an action.
- Always show what will happen before a package-changing operation runs.
- Never hide risky operations behind a single click.
- Surface repo refreshes, dependency changes, and failures in plain language.
- Make theme identity feel intentional, not like recolored defaults.

## Initial Scope

Version 0 should focus on these views:

- `Browse`: searchable package list from configured repos
- `Installed`: installed packages with version and short description
- `Updates`: packages with available upgrades
- `Details`: description, version, repo, size, website, dependencies when available

Version 0 actions:

- refresh package metadata
- install one package
- remove one package
- upgrade all packages

Nice-to-have after that:

- package history or recent actions
- filters by category or repo
- queued multi-action workflow
- screenshots or richer metadata if a reliable source exists

## Shared Theme Model

The current welcome window hardcodes theme palettes in QML. That works for one surface, but it will become duplication once we add another app.

Before or during the prototype, BSDRunner should introduce a shared theme loader that reads:

- `~/.config/bsdrunner/current-theme`
- `~/.config/bsdrunner/themes/<theme>/palette.conf`

The software center should consume semantic tokens, not raw theme names:

- frame background
- panel background
- card background
- hover background
- border colors
- primary text
- secondary text
- muted text
- accent
- accent strong
- warning
- danger
- success

Recommended follow-up:

- refactor the welcome window to use the same shared palette loader

That reduces theme drift and gives both control surfaces the same visual grammar.

## High-Level Architecture

The app should be split into four layers:

1. Theme layer
2. UI layer
3. data/service layer
4. action layer

### Theme Layer

Responsibilities:

- resolve active theme
- load `palette.conf`
- expose normalized colors and semantic state colors
- expose optional theme labels or motifs later

### UI Layer

Responsibilities:

- navigation
- search and filtering
- package list rendering
- details panel
- confirmation dialogs
- progress and error surfaces

The UI should know nothing about raw `pkg` command output.

### Data/Service Layer

Responsibilities:

- call read-only wrapper scripts
- parse returned JSON
- manage loading and refresh states
- merge data for list and detail views

This layer is the right place for lightweight caching to keep the UI responsive.

### Action Layer

Responsibilities:

- call the privileged wrapper for install, delete, and upgrade
- stream progress text back to the UI
- surface success and failure states
- trigger post-action refreshes

## Backend Contract

The frontend should talk to a single stable script entry point, with subcommands, instead of sprinkling command knowledge across QML.

Recommended command surface:

```text
bsdrunner-software-backend list-remote
bsdrunner-software-backend list-installed
bsdrunner-software-backend list-upgrades
bsdrunner-software-backend show PACKAGE
bsdrunner-software-backend refresh
bsdrunner-software-backend install PACKAGE
bsdrunner-software-backend remove PACKAGE
bsdrunner-software-backend upgrade-all
```

Recommended behavior:

- read-only subcommands return JSON on stdout and exit non-zero on failure
- action subcommands return line-oriented progress plus a final JSON status line
- stderr is reserved for real failures and diagnostics

## JSON Shapes

The exact fields can evolve, but the UI should be built around predictable records like these.

Package list item:

```json
{
  "name": "firefox",
  "version": "138.0.4,1",
  "installed": true,
  "update_available": false,
  "repo": "FreeBSD",
  "comment": "Web browser based on the browser portion of Mozilla"
}
```

Package detail:

```json
{
  "name": "firefox",
  "version": "138.0.4,1",
  "installed": true,
  "update_available": false,
  "repo": "FreeBSD",
  "comment": "Web browser based on the browser portion of Mozilla",
  "description": "Longer package description here",
  "website": "https://www.mozilla.org/firefox/",
  "license": "MPL-2.0",
  "size": "123 MB",
  "dependencies": ["gtk3", "dbus", "alsa-lib"]
}
```

Action result:

```json
{
  "ok": true,
  "action": "install",
  "package": "firefox",
  "message": "Package installation completed"
}
```

## Proposed Repo Layout

This layout is designed to let option 2 start immediately without reshuffling files later.

```text
dotfiles/
└── .config/
    ├── bsdrunner/
    │   └── scripts/
    │       ├── bsdrunner-software.sh
    │       ├── bsdrunner-software-backend.sh
    │       ├── bsdrunner-software-query.sh
    │       ├── bsdrunner-software-action.sh
    │       └── bsdrunner-theme-read.sh
    └── quickshell/
        ├── bsdrunner-common/
        │   ├── ThemeLoader.qml
        │   ├── ThemePalette.qml
        │   └── ProcessJsonAdapter.qml
        └── bsdrunner-software/
            ├── shell.qml
            ├── components/
            │   ├── AppFrame.qml
            │   ├── Sidebar.qml
            │   ├── SearchBar.qml
            │   ├── PackageList.qml
            │   ├── PackageRow.qml
            │   ├── PackageDetailPane.qml
            │   ├── ActionDialog.qml
            │   ├── StatusBanner.qml
            │   └── EmptyState.qml
            └── views/
                ├── BrowseView.qml
                ├── InstalledView.qml
                └── UpdatesView.qml
```

### File Responsibilities

`bsdrunner-software.sh`

- simple launcher
- mirrors the existing welcome script pattern
- exits cleanly if `qs` is unavailable

`bsdrunner-software-backend.sh`

- single public backend entry point
- dispatches subcommands
- keeps QML integration simple

`bsdrunner-software-query.sh`

- unprivileged `pkg` reads
- emits JSON

`bsdrunner-software-action.sh`

- privileged `mdo` actions
- validates action names and package arguments
- emits progress and final status

`bsdrunner-theme-read.sh`

- reads the active theme and palette keys from `palette.conf`
- gives QML a shared way to consume theme tokens

`bsdrunner-common/`

- reusable theme and process helpers shared by the welcome window and software center

`bsdrunner-software/`

- app-specific UI only

## Launch Model

Initial launch command:

```sh
qs -c bsdrunner-software
```

Matching launcher script:

```sh
sh ~/.config/bsdrunner/scripts/bsdrunner-software.sh
```

Possible integration points later:

- a Waybar button
- a welcome-window action card
- a desktop entry
- a keybinding

Those should come after the read-only prototype is stable.

## Action Flow

Install flow:

1. User selects a package.
2. UI loads details through the read-only backend.
3. User clicks `Install`.
4. UI shows dependency and confirmation copy.
5. UI starts the action backend.
6. Backend runs the validated install command through `mdo`.
7. Progress text appears in a dedicated dialog or log pane.
8. On success, the UI refreshes installed and update state.

Remove and upgrade flows should follow the same shape.

## Error Handling

Expected failure classes:

- package metadata not available yet
- package not found
- repo refresh failure
- permission or policy failure from `mdo`
- dependency resolution failure
- network failure during fetch

The UI should translate these into friendly summaries plus an expandable details area.

## Security Notes

- Do not pass raw user input directly into shell command strings.
- Validate package names before invoking action scripts.
- Keep privileged subcommands narrow and explicit.
- Avoid a general-purpose "run arbitrary pkg command" backend.
- Prefer one controlled backend entry point over many ad hoc helpers.

## Phase Plan

### Phase 1

Shared foundation:

- create shared theme loader
- create software center launcher
- create read-only backend contract
- create Quickshell shell with placeholder navigation and sample data

### Phase 2

Read-only prototype:

- browse list
- installed list
- updates list
- detail pane
- search and selection state
- real JSON data from `pkg`

### Phase 3

Privileged actions:

- install
- remove
- upgrade all
- confirmation dialogs
- progress UI

### Phase 4

Desktop integration and polish:

- welcome-window launcher card
- optional Waybar entry point
- iconography and motion polish
- better empty states and error copy

## Recommendation For Option 2

When we start the prototype, the best first slice is:

1. Extract a shared theme loader from the welcome window.
2. Scaffold `bsdrunner-software/` with a real shell and static mock data.
3. Add `bsdrunner-software.sh` launcher.
4. Replace mock data with read-only backend output.

That path gives us something visible early without getting blocked on `mdo` policy or action UX.
