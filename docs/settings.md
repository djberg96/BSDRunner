# BSDRunner Settings

BSDRunner Settings is the central entry point for desktop configuration. It
keeps the existing focused control panels independent while making them
discoverable from one searchable window.

Open it from any of these locations:

- click the gear beside **APPS** in Waybar;
- choose **System Settings** in the BSDRunner Welcome window;
- choose **System Settings** in the BSDRunner Apps menu;
- press **Super+I**;
- run `~/.local/bin/bsdrunner-settings`.

The standard desktop entry is installed at
`~/.local/share/applications/bsdrunner-settings.desktop`, so launchers that
implement the freedesktop application menu also list **BSDRunner Settings**.

## Categories

- System Info
- Appearance
- Keyboard Shortcuts
- Network
- Power & Lock
- Firewall
- Encrypted DNS
- Software
- Storage & ZFS
- Jails
- Date & Time
- Battery

Some categories open within the hub; others launch an existing BSDRunner panel
or menu. Closing a separate panel returns to the still-open settings hub.

## System Info

**System Info** shows available operating system, hardware, display, storage,
and uptime details. The panel uses Fastfetch’s JSON output when available,
with FreeBSD system utilities and Hyprland as a fallback for missing
information or when Fastfetch is not installed. Refresh updates the data.
Fields are omitted when neither source can report them. Root storage refers
to the filesystem containing `/`, not all disks or ZFS pools.

## Appearance

Open **Appearance** to choose a desktop theme or adjust the screen brightness.
The slider reads the active backlight and reflects changes made with the
brightness keys. It is unavailable if no supported backlight is accessible.

## Keyboard shortcuts

**Keyboard Shortcuts** shows the bindings reported by the running Hyprland
session, including custom bindings. Select **Refresh** after making changes.
Press **Super+Z** to maximize or restore the active window while keeping the
desktop bars and gaps visible.
BSDRunner's Lua bindings include descriptions so the list can explain what each
shortcut does. For custom Lua bindings, add `description = "..."` to the
`hl.bind` options to show a useful label. Without a description, Hyprland may
report only an action type rather than the command or target.
The edit buttons open the Lua configuration (`~/.config/hypr/hyprland.lua`,
for Hyprland 0.56 and later) or the legacy bindings file
(`~/.config/hypr/conf/keybindings.conf`) in your default application. Save
your changes and reload Hyprland if needed. Custom bindings may also be defined
in other sourced files, which you can edit separately.

Media keys can send the same key symbol from different physical keys on
different keyboards. To label them for your machine, create
`~/.config/bsdrunner/shortcut-key-labels.json` with a mapping from Hyprland key
symbols to the labels printed on your keys, for example:

```json
{
  "XF86AudioMute": "F1",
  "XF86AudioLowerVolume": "F2",
  "XF86AudioRaiseVolume": "F3",
  "XF86AudioMicMute": "F4"
}
```

These labels affect the Settings list only; they do not change the bindings.
Fn Lock and external keyboards may change which physical key sends a symbol.
Keys handled outside Hyprland can be listed in
`~/.config/bsdrunner/shortcut-local-bindings.json` as an array of objects with
`key` and `description` strings. They appear as local hotkeys; the file only
describes them and does not configure or verify their behavior.

On FreeBSD, the brightness media keys adjust the panel backlight in steps of
five percentage points, with a minimum of 5%. The hardware may round the
reported brightness. On other systems, the keys use `brightnessctl` when it
is available.

On some ThinkPads, the microphone key sends an ACPI event instead of a
keyboard shortcut. `bsdrunner-thinkpad-mic-watch.sh` can be started from a
local Hyprland configuration for machines where that key has been verified to
send IBM event `0x1b`. It toggles the default microphone source. Event codes
can differ by model, so the watcher is not enabled automatically.

The opt-in `bsdrunner-thinkpad-wireless-watch.sh` handles IBM event `0x05`
on machines where it has been verified as the wireless key. It brings down
enabled Wi-Fi interfaces and turns off the ThinkPad Bluetooth switch, then
restores their previous states on the next press. It saves recovery state in
`~/.local/state/bsdrunner/wireless-toggle/` (or under `$XDG_STATE_HOME`),
and reports failures in a desktop notification. This controls Wi-Fi interfaces
and the ThinkPad Bluetooth switch; it does not verify every possible radio.

## Notifications

The notification-center key opens or closes BSDRunner Notifications. It
shows active and recent notifications held by Mako and refreshes while open.
Mako's history is session-limited; Hyprland's own built-in popups and
notifications from other daemons are not included. The panel displays
notification text but does not invoke notification actions.

On ThinkPads where the notification key has been verified as IBM ACPI event
`0x17`, the opt-in `bsdrunner-thinkpad-notifications-watch.sh` can handle the
key. It does not open the panel while Hyprlock is running. Other keyboards can
use the `XF86NotificationCenter` binding directly.
