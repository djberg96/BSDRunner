# BSDRunner pf Baseline

BSDRunner ships a desktop-focused FreeBSD `pf` template at:

```text
system/etc/pf.conf
```

It is meant for a single laptop or workstation, not a router, jail host, NAT gateway, or public server. The baseline blocks unsolicited inbound traffic, allows stateful outbound traffic, preserves loopback, keeps basic ICMP diagnostics, and allows DHCP and mDNS for normal desktop networking.

The template is tracked in the repo, but it is not installed by `scripts/install-dotfiles.sh` yet. Install it manually after validating it.

## Validate

Check the repo template before copying it into `/etc`:

```sh
mdo -- pfctl -vnf system/etc/pf.conf
```

If you have already copied it into place, validate the installed file:

```sh
mdo -- pfctl -vnf /etc/pf.conf
```

`pfctl -vnf` checks syntax without loading the ruleset.

## Install

Copy the template into place with root ownership and restrictive permissions:

```sh
mdo -- install -m 0600 system/etc/pf.conf /etc/pf.conf
```

Enable PF at boot:

```sh
mdo -- sysrc pf_enable=yes
```

Start PF for the first time:

```sh
mdo -- service pf start
```

If PF is already running, reload the rules instead:

```sh
mdo -- service pf reload
```

## Inspect

Show the active filter rules:

```sh
mdo -- pfctl -s rules
```

Show the active state table:

```sh
mdo -- pfctl -s states
```

For live traffic inspection, FreeBSD's Handbook recommends `pftop` from `sysutils/pftop`.

## Smoke Test

After enabling or reloading the ruleset, check:

- web browsing
- DNS resolution
- `pkg` access
- IPv4 ping
- IPv6 connectivity if enabled
- reconnecting to Wi-Fi or Ethernet
- mDNS discovery for printers, casting, or other local devices

## Roll Back

If networking breaks, disable PF immediately:

```sh
mdo -- pfctl -d
```

Then edit or replace `/etc/pf.conf`, validate with `pfctl -vnf`, and start or reload PF again when ready.

To stop enabling PF at boot:

```sh
mdo -- sysrc pf_enable=NO
```

## Notes

This baseline intentionally does not allow inbound SSH. Add that later as an explicit profile or GUI-controlled rule once the source network and privilege flow are clear.

The rules avoid OpenBSD-specific assumptions where FreeBSD behavior may differ. In particular, they use FreeBSD's modern `set reassemble yes` normalization style and numeric ports for desktop discovery services.

## References

- FreeBSD Handbook: [Firewalls](https://docs.freebsd.org/en/books/handbook/firewalls/)
- FreeBSD manual page: [pf.conf(5)](https://man.freebsd.org/cgi/man.cgi?query=pf.conf)
