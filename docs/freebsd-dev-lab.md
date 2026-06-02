# FreeBSD Dev Lab

BSDRunner has a few features that depend on real FreeBSD kernel interfaces.
The memory popup is one of them: `procstat`, VM map accounting, ACPI, PF, ZFS,
and similar tools cannot be meaningfully tested inside a Docker container on
macOS or Linux because Docker containers share the host kernel.

## Recommended Setup

Use one of these instead:

1. A real FreeBSD laptop over SSH.
2. A FreeBSD VM through QEMU, UTM, VirtualBox, or bhyve.
3. A FreeBSD jail only when the host is already FreeBSD and the feature does
   not require a separate kernel.

For the memory popup, prefer option 1 or 2.

## Minimal Packages

Install the tools needed for backend experiments:

```sh
pkg install git jq
```

If testing Quickshell UI pieces too, also install the normal BSDRunner desktop
dependencies from `docs/freebsd-setup.md`.

## Real Laptop Workflow

On the FreeBSD machine:

```sh
git clone https://github.com/YOUR_USER/BSDRunner.git
cd BSDRunner
./scripts/install-dotfiles.sh --theme "$(cat ~/.config/bsdrunner/current-theme 2>/dev/null || printf default)"
```

Then run backend probes directly:

```sh
sh ~/.config/bsdrunner/scripts/bsdrunner-memory-backend.sh
sh ~/.config/bsdrunner/scripts/bsdrunner-memory-backend.sh debug
```

For procstat JSON shape checks:

```sh
pid="$(pgrep -f firefox | head -n 1)"
procstat --libxo=json,pretty,underscores -v "$pid" > procstat-firefox-v.json
jq '.procstat.vm | to_entries[0].value.vm[0]' procstat-firefox-v.json
```

The memory backend expects VM mappings shaped roughly like:

```json
{
  "procstat": {
    "vm": {
      "1234": {
        "process_id": 1234,
        "vm": [
          {
            "kve_resident": 42,
            "kve_private_resident": 17
          }
        ]
      }
    }
  }
}
```

## VM Workflow

Create a normal FreeBSD VM and enable SSH. Once the VM is reachable:

```sh
ssh freebsd@VM_ADDRESS
pkg install git jq
git clone https://github.com/YOUR_USER/BSDRunner.git
cd BSDRunner
```

For non-GUI backend testing, you do not need Hyprland or Quickshell installed.
You can run scripts directly from the repo:

```sh
sh dotfiles/.config/bsdrunner/scripts/bsdrunner-memory-backend.sh debug
```

## Why Not Docker?

Docker cannot provide a FreeBSD kernel on a non-FreeBSD host. A FreeBSD userland
container on Linux or macOS would still expose Linux/macOS kernel behavior, not
FreeBSD `procstat`, ACPI, PF, ZFS, or VM accounting behavior. For BSDRunner,
that would produce misleading test results.
