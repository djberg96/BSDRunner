# ThinkPad programmable star key

`acpi-ibm-star-key.patch` fixes the FreeBSD `acpi_ibm` handling of the
ThinkPad extended HKEY event `0x1311`. The original driver treats its low
byte as brightness down and shifts by an invalid amount when checking the
legacy event mask. The patch reports the star key as `KEY_BOOKMARKS` and
passes extended event arguments to devd without truncation. Legacy brightness
and hotkey events retain their existing behavior.

`acpi-ibm-star-key-main.patch` is the corresponding upstream candidate,
adapted to FreeBSD main at `4ba6fd2ef5a739b6fdc955890d27e07ae8794fb3`.
It preserves the microphone-key handling added since the 15.1 branch. The
proposed submission text is in `upstream-pr-description.md`. FreeBSD requires
human review of AI-generated changes and does not allow chatbots to submit
pull requests. A human contributor must review the patch, assess the Developer
Certificate of Origin, and submit it. No pull request has been created.

The patch was prepared and the module built against FreeBSD `releng/15.1`
commit `bb03631fe3b7a8bfa8071e8063f554528d4e4618`, matching the running
15.1-RELEASE-p7 kernel on the test machine. A kernel module must be built
against source and kernel options matching the kernel on which it will run.
Recheck the patch and rebuild after a FreeBSD kernel update.

To check the patched event handler without loading a kernel module:

```sh
git -C /path/to/freebsd-src apply /path/to/BSDRunner/patches/freebsd/acpi-ibm-star-key.patch
sh scripts/test-acpi-ibm-hotkeys.sh /path/to/freebsd-src
```

The tests compile the actual patched event handler into a small userspace
harness and exercise the star, brightness, existing laptop hotkeys, extended,
and malformed events. They do not replace testing on hardware.

On the test machine the patched module was installed as
`/boot/kernel/acpi_ibm.ko` after a successful live test. The original
15.1-RELEASE-p7 module is preserved as
`/boot/kernel/acpi_ibm.ko.bsdrunner-original`. To undo the installation on
that same kernel, restore the original and reboot:

```sh
mdo cp -p /boot/kernel/acpi_ibm.ko.bsdrunner-original /boot/kernel/acpi_ibm.ko
```

Do not restore that backup over a different kernel version. A kernel update
may replace the patched module; rebuild against the updated kernel's matching
source and configuration before reinstalling it.
