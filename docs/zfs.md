# BSDRunner ZFS

BSDRunner includes a small ZFS control surface for a single FreeBSD laptop. It is intentionally focused on everyday snapshot work, not disk replacement, pool creation, replication, or storage-array administration.

Launch it with:

```sh
sh ~/.config/bsdrunner/scripts/bsdrunner-zfs.sh
```

The first version shows:

- pool health and free space
- filesystem and volume datasets
- recent snapshots
- create snapshot for the selected dataset
- roll back to a selected snapshot
- destroy a selected snapshot

Actions are handled by `bsdrunner-zfs-backend.sh`, which wraps `zfs` and `zpool`. Snapshot creation, rollback, and deletion use `mdo` when it is available.

Snapshot labels are optional. If left blank, BSDRunner creates a timestamped label such as `bsdrunner-20260601-143000`. Manual labels may contain letters, numbers, dots, underscores, and hyphens.

Rollback and destroy are intentionally confirmation-gated. They are useful, but they can discard work or remove recovery points.
