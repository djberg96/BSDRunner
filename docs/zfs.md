# BSDRunner ZFS

BSDRunner includes a small ZFS control surface for a single FreeBSD laptop. It is intentionally focused on everyday snapshot work, not disk replacement, pool creation, replication, or storage-array administration.

Launch it with:

```sh
sh ~/.config/bsdrunner/scripts/bsdrunner-zfs.sh
```

The first version shows:

- pool health and free space
- filesystem and volume datasets
- selected dataset details, including native ZFS encryption status and key metadata
- recent snapshots
- create snapshot for the selected dataset
- optionally create snapshots recursively from the confirmation prompt
- clickable snapshot summary for the selected dataset
- roll back to or destroy snapshots from the snapshot-browse view

Actions are handled by `bsdrunner-zfs-backend.sh`, which wraps `zfs` and `zpool`. Snapshot creation, recursive snapshot creation, rollback, and deletion use `mdo` when it is available.

Snapshot labels are optional. If left blank, BSDRunner creates a timestamped label such as `bsdrunner-20260601-143000`. Manual labels may contain letters, numbers, dots, underscores, and hyphens.

Recursive snapshots use `zfs snapshot -r` and apply to the selected dataset plus descendants.

The center pane defaults to dataset details. Click the lower-right snapshot summary to browse snapshots for the selected dataset; rollback and destroy are available there and remain confirmation-gated because they can discard work or remove recovery points.

Dataset encryption status is read-only. BSDRunner shows ZFS properties such as `encryption`, `keystatus`, `keyformat`, `keylocation`, `encryptionroot`, and `pbkdf2iters`, but it does not create encrypted datasets, change keys, load keys, unload keys, or migrate existing data.
