#!/bin/sh
# Run against a FreeBSD source tree with patches/freebsd/acpi-ibm-star-key.patch applied.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
source_tree=${1:?Pass the path to a patched FreeBSD source tree}
src="$source_tree/sys/dev/acpi_support/acpi_ibm.c"
work=$(mktemp -d "${TMPDIR:-/tmp}/acpi-ibm-test.XXXXXXXX")
trap 'rm -rf "$work"' EXIT HUP INT TERM
cat "$root/tests/acpi-ibm-hotkey-harness.c" > "$work/test.c"
printf '\nstatic void\n' >> "$work/test.c"
sed -n '/^acpi_ibm_notify(ACPI_HANDLE/,/^}/p' "$src" >> "$work/test.c"
if grep -q 'case IBM_EVENT_MICMUTE:' "$src"; then
    printf '\n#define TEST_MIC_KEY KEY_MICMUTE\n' >> "$work/test.c"
else
    printf '\n#define TEST_MIC_KEY 0\n' >> "$work/test.c"
fi
cat >> "$work/test.c" <<'EOF'
static void test(int event, unsigned mask, int key, int notification)
{
    struct acpi_ibm_softc sc = { mask, 0, NULL };
    input_event = event; pending = 1; key_count = notifications = notified = handled = 0;
    acpi_ibm_notify(NULL, 0x80, &sc);
    if ((key && (key_count != 2 || keys[0] != key || keys[1] != key ||
        values[0] != 1 || values[1] != 0)) || (!key && key_count != 0) ||
        notifications != (notification >= 0) ||
        (notification >= 0 && notified != notification) || handled) {
        fprintf(stderr, "Unexpected behavior for event %#x\n", event);
        exit(1);
    }
}
int main(void)
{
    test(0x1311, 0, KEY_BOOKMARKS, 0x311);
    test(0x1011, ~0u, KEY_BRIGHTNESSDOWN, 0x11);
    test(0x1010, ~0u, KEY_BRIGHTNESSUP, 0x10);
    test(0x101b, ~0u, TEST_MIC_KEY, 0x1b);
    test(0x1005, ~0u, 0, 0x05);
    test(0x1017, ~0u, 0, 0x17);
    test(0x1312, ~0u, 0, 0x312);
    test(0x1020, ~0u, 0, 0x20);
    test(0x1000, ~0u, 0, -1);
    test(0x6032, ~0u, 0, -1);
    puts("ACPI ThinkPad hotkey tests passed");
    return 0;
}
EOF
${CC:-cc} -Wall -Wextra -Werror -fsanitize=undefined -fno-sanitize-recover=undefined "$work/test.c" -o "$work/test"
"$work/test"
