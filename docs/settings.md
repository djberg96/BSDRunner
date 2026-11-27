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

Each category delegates to the existing BSDRunner panel or menu. Closing a
category returns to the still-open settings hub, and changes continue to use
the same tested backends as their standalone entry points.

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

On some ThinkPads, the microphone key sends an ACPI event instead of a
keyboard shortcut. `bsdrunner-thinkpad-mic-watch.sh` can be started from a
local Hyprland configuration for machines where that key has been verified to
send IBM event `0x1b`. It toggles the default microphone source. Event codes
can differ by model, so the watcher is not enabled automatically.
