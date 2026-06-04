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
- read-only snapshot summary for the selected dataset

Actions are handled by `bsdrunner-zfs-backend.sh`, which wraps `zfs` and `zpool`. Snapshot creation, recursive snapshot creation, rollback, and deletion use `mdo` when it is available.

Snapshot labels are optional. If left blank, BSDRunner creates a timestamped label such as `bsdrunner-20260601-143000`. Manual labels may contain letters, numbers, dots, underscores, and hyphens.

Recursive snapshots use `zfs snapshot -r` and apply to the selected dataset plus descendants.

Rollback and destroy remain backend-supported actions, but the current dataset-details layout does not expose them in the GUI. They are useful, but they can discard work or remove recovery points.

Dataset encryption status is read-only. BSDRunner shows ZFS properties such as `encryption`, `keystatus`, `keyformat`, `keylocation`, `encryptionroot`, and `pbkdf2iters`, but it does not create encrypted datasets, change keys, load keys, unload keys, or migrate existing data.
