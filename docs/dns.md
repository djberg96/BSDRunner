# BSDRunner DNS Cache

BSDRunner uses FreeBSD's base `local_unbound` service for the first DNS cache GUI. This is intentionally a local laptop profile, not a general DNS server or LAN resolver.

The GUI does not manage raw Unbound configuration in v1. It reads service status, boot settings, `/etc/resolv.conf`, and lookup diagnostics, then exposes a small set of actions. When enabling the cache, the backend uses FreeBSD's `local-unbound-setup` helper when it is available.

## Backend Commands

Run these without enabling anything:

```sh
~/.config/bsdrunner/scripts/bsdrunner-dns-backend.sh snapshot
~/.config/bsdrunner/scripts/bsdrunner-dns-backend.sh test freebsd.org
```

Enable and start the local cache from the GUI, or manually:

```sh
mdo sysrc local_unbound_enable=YES
mdo local-unbound-setup
mdo service local_unbound start
```

After enabling, check that the resolver points at localhost:

```sh
cat /etc/resolv.conf
drill freebsd.org
drill freebsd.org @127.0.0.1
```

Useful maintenance commands:

```sh
mdo service local_unbound restart
mdo local-unbound-control reload
mdo service local_unbound stop
```

`local-unbound-control reload` reloads the resolver and flushes cached answers. If that command is unavailable, the GUI falls back to restarting `local_unbound`.

## GUI Scope

The DNS Cache GUI is a practical control surface:

- service status
- boot enabled/disabled
- whether `/etc/resolv.conf` points at localhost
- current nameservers
- enable, disable, restart, and flush actions
- a simple lookup test

V1 avoids DNS-over-TLS, custom upstream selection, ad blocking, DHCP, and LAN host management. Those belong in later profiles if BSDRunner needs them.
