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
