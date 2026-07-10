# Scenario 1: Classic SSH & Rsync Backup

This scenario demonstrates the traditional deployment of Barman. Here, Barman operates as a remote system administrator that connects to the PostgreSQL server via **SSH** and utilizes **rsync** to copy files for full backups and WAL archiving.

---

## Architecture Diagram

```
                 +-------------------+
                 |  barman container |
                 |                   |
                 |   barman user     |
                 +---------+---------+
                           |
            (rsync over SSH| backup & restore)
                           v
                 +---------+---------+
                 |    pg container   |
                 |                   |
                 |   postgres user   |
                 +-------------------+
```

- **Backup Method:** `rsync` over SSH. Barman logs into the PG server as `postgres`, locks the database, copies the database files, and unlocks it.
- **WAL Archiving:** Push-based. The PostgreSQL server's `archive_command` runs a script/command that SSHes to the Barman container and uses `rsync` to drop the WAL files in Barman's incoming directory.

---

## Configuration Highlight

### 1. Barman Server Config (`/etc/barman.d/pg.conf`)
```ini
[pg]
description = "PostgreSQL 15 Server (rsync/ssh)"
conninfo = host=pg user=barman dbname=postgres password=barman
ssh_command = ssh postgres@pg
backup_method = rsync
archiver = on
```
- `conninfo`: The SQL connection Barman uses to issue replication commands, check cluster states, and issue `pg_backup_start()` / `pg_backup_stop()` SQL calls.
- `ssh_command`: The command Barman uses to establish an SSH shell on the database server to perform file copies.
- `backup_method = rsync`: Tells Barman to use standard rsync to copy the data files.

### 2. PostgreSQL Configuration (`postgresql.conf` parameters)
```ini
wal_level = replica
archive_mode = on
archive_command = 'rsync -a %p barman@barman:/var/lib/barman/pg/incoming/%f'
```
- `archive_command`: Runs whenever PostgreSQL finishes filling a 16MB WAL segment. It copies (`rsync`) the WAL file directly to Barman's designated incoming directory for that server.

---

## Detailed Lab Guide

### Step 1: Boot the Environment
Use the Makefile to generate SSH keys, build the custom docker images, and start the containers:
```bash
make up
```
This target:
1. Generates ephemeral SSH keys locally in `./.ssh_keys`.
2. Automatically shares them between the containers.
3. Builds the `pg-ssh` and `barman-ssh` containers.
4. Starts the services and blocks until PostgreSQL is accepting connections.

### Step 2: Perform Barman Checks
Validate that Barman can connect to PostgreSQL both via SSH and the SQL port:
```bash
make check
```
> [!TIP]
> If a check fails, verify that you can SSH from `barman` container to `pg` container passwordlessly, and that the `barman` database user exists and has the correct password.

### Step 3: Insert Test Data
Create a database table and insert a record to simulate active usage:
```bash
make insert-data
```

### Step 4: Perform a Full Backup
Trigger Barman to perform a full physical backup using `rsync`:
```bash
make backup
```
You will see Barman querying the system ID, calling start backup, rsyncing the data directory, stopping the backup, and copying the backup metadata.

### Step 5: Archive WALs
Inserts another row, then forces PostgreSQL to rotate its current WAL segment:
```bash
make switch-wal
```
This forces PostgreSQL to invoke the `archive_command`, pushing the WAL file to the Barman container's `/var/lib/barman/pg/incoming/` directory.

### Step 6: Verify Catalog & Backups
List all backups tracked by Barman:
```bash
make list-backups
```
You should see your backup listed with its date, size, and ID.

### Step 7: Simulate Recovery
Perform a remote recovery. The following command restores the latest backup to a clean folder `/var/lib/postgresql/recovered-data` on the PG container:
```bash
make recover
```
Observe that Barman SSHes into the PG container and rsyncs the data files back, creating a functional PostgreSQL data directory ready to be booted.

### Step 8: Clean Up
Tear down the containers and delete the ephemeral keys:
```bash
make clean
```

---

## Key Educational Takeaways
1. **No Shared Disk Required:** The SSH/Rsync method works over standard SSH, allowing you to back up remote servers over the network without mounting shared NFS folders.
2. **Push vs Pull WALs:** In this setup, WALs are *pushed* by PostgreSQL to Barman. If PostgreSQL is offline, no WALs can be archived.
3. **SSH Permissions:** Both containers require correct permissions on `.ssh` folders (`700`) and private keys (`600`) to avoid SSH daemon rejections.
