# Persistent Volumes

This directory documents the host-mounted volumes used by the k3d cluster.

## Volume Locations

All volumes are stored under `~/k3d-vol/`:

| Service | Host Path | Container Path | Purpose |
|---------|-----------|----------------|---------|
| PostgreSQL | `~/k3d-vol/postgres-data` | `/mnt/data/postgres` | Database files |
| MongoDB | `~/k3d-vol/mongodb-data` | `/mnt/data/mongodb` | Database files |
| Redis | `~/k3d-vol/redis-data` | `/mnt/data/redis` | (optional) AOF/RDB |

## Why Host Volumes?

The k3d cluster can be deleted and recreated at any time (`make cluster-reset`). By mounting host directories into the cluster, data persists across cluster resets.

## Setup

Volumes are created automatically by:
- `make setup-volumes`
- `make cluster-up`
- `./scripts/bootstrap.sh`

Or manually:
```bash
mkdir -p ~/k3d-vol/postgres-data
mkdir -p ~/k3d-vol/mongodb-data
mkdir -p ~/k3d-vol/redis-data
chmod 777 ~/k3d-vol/*-data
```

## Clearing Data

To reset a service's data:
```bash
# Stop the service first
make postgres-down

# Clear the data
rm -rf ~/k3d-vol/postgres-data/*

# Restart
make postgres-up
```

## Permissions

Volumes need `777` permissions because containers run as non-root users with varying UIDs.

## Backup

These directories should be excluded from backups in most cases, as they contain development data only. If needed, back up with:
```bash
tar czf ~/k3d-backup.tar.gz ~/k3d-vol/
```
