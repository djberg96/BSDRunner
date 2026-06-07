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
- create a child filesystem dataset under the selected parent
- recent snapshots
- create snapshot for the selected dataset
- optionally create snapshots recursively from the confirmation prompt
- a top `Snapshots` mode button for the selected dataset
- context-sensitive right rail for dataset management or snapshot actions
- roll back to or destroy snapshots from the snapshot-browse view

Actions are handled by `bsdrunner-zfs-backend.sh`, which wraps `zfs` and `zpool`. Dataset creation, snapshot creation, recursive snapshot creation, rollback, and deletion use `mdo` when it is available.

Dataset creation is intentionally narrow: select an existing filesystem dataset
as the parent, choose a child name, then confirm. BSDRunner runs:

```sh
zfs create PARENT/CHILD
```

The UI includes quick-fill names such as `bastille` and `jails` because those
are useful for later jail setup, but the action is generic and can create any
ordinary child dataset with a conservative name.

Snapshot labels are optional. If left blank, BSDRunner creates a timestamped label such as `bsdrunner-20260601-143000`. Manual labels may contain letters, numbers, dots, underscores, and hyphens.

Recursive snapshots use `zfs snapshot -r` and apply to the selected dataset plus descendants.

The center pane defaults to dataset details. Click `Snapshots` in the top
summary area to browse snapshots for the selected dataset; the right rail then
switches to snapshot creation and snapshot actions. Selecting a dataset returns
the right rail to dataset management. Rollback and destroy remain
confirmation-gated because they can discard work or remove recovery points.

Dataset encryption status is read-only. BSDRunner shows ZFS properties such as `encryption`, `keystatus`, `keyformat`, `keylocation`, `encryptionroot`, and `pbkdf2iters`, but it does not create encrypted datasets, change keys, load keys, unload keys, or migrate existing data.
