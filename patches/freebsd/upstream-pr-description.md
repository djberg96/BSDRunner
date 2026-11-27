## Problem

On a ThinkPad X1 Carbon Gen 9 running FreeBSD 15.1, the programmable star
key reports ACPI HKEY event `0x1311`. `acpi_ibm` treats the 12-bit argument
as a legacy event-mask index, which causes an out-of-range shift; the low
byte also aliases the brightness-down event. Pressing the star key therefore
lowers screen brightness instead of producing a separate key event.

## Change

Handle extended HKEY arguments separately from the 32 legacy event-mask
indices. Emit `KEY_BOOKMARKS` for `0x1311`, and pass the full extended
argument to devd. Reject zero before shifting and use unsigned shifts for
valid legacy mask indices. The existing legacy event paths are otherwise
unchanged.

The decision to forward all extended arguments to devd changes how those
events are reported and merits maintainer review, particularly for any
existing consumers that may have relied on the truncated value.

## Testing

- A corresponding patch against FreeBSD 15.1-RELEASE-p7 was built against
  the running kernel's exact source revision and configuration, loaded, and
  tested on the X1 Carbon Gen 9. The star key opened the configured action
  without dimming the screen. This hardware test was on 15.1, not main.
- The main-branch module compiled against main's GENERIC configuration with
  `-Werror`. It has not been loaded on a main-branch kernel.
- A userspace harness compiled the actual handler and checked star, brightness,
  microphone, wireless, notification, extended, and malformed event cases.
- FreeBSD's `checkstyle9.pl` reported no errors or warnings for this diff.

This patch was developed with AI assistance and requires human review.
