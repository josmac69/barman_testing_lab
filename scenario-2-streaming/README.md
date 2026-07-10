# Scenario 2: Streaming Replication Backup (SSH-Less)

This scenario demonstrates the modern streaming backup method. In this configuration, Barman connects to PostgreSQL exclusively using the **PostgreSQL Replication Protocol** (port `5432`). It requires no SSH access to the PostgreSQL server.

---

## Architecture Diagram

```
                 +-------------------+
                 |  barman container |
                 |                   |
                 |   barman user     |
                 +---------+---------+
                           |
          (PG Protocol     | pg_basebackup &
           on port 5432)   | pg_receivewal
                           v
                 +---------+---------+
                 |    pg container   |
                 |                   |
                 |   postgres user   |
                 +-------------------+
```

- **Backup Method:** `postgres` (uses `pg_basebackup` API internally).
- **WAL Archiving:** Streaming-based. Barman runs `pg_receivewal` as a background daemon which attaches to a physical replication slot and receives WAL records in real-time as they are written by the PG server.

---

## Configuration Highlight

### 1. Barman Server Config (`/etc/barman.d/pg.conf`)
```ini
[pg]
description = "PostgreSQL 15 Server (Streaming)"
conninfo = host=pg user=barman dbname=postgres password=barman
streaming_conninfo = host=pg user=barman dbname=postgres password=barman
backup_method = postgres
streaming_archiver = on
slot_name = barman
```
- `conninfo`: Standard connection for SQL commands.
- `streaming_conninfo`: Connection string for streaming WALs and physical files. Must support replication connections.
- `backup_method = postgres`: Instructs Barman to use PG streaming protocol to pull base backups.
- `streaming_archiver = on`: Activates real-time WAL streaming via `pg_receivewal`.
- `slot_name = barman`: Connects the WAL streamer to a replication slot on the primary server, preventing PostgreSQL from deleting WAL files before Barman consumes them.

### 2. PostgreSQL Configuration (`postgresql.conf` parameters)
```ini
wal_level = replica
max_wal_senders = 10
max_replication_slots = 10
```
- Standard replication options allowing replication clients to stream WALs.

---

## Detailed Lab Guide

### Step 1: Boot the Environment
Build and start the services:
```bash
make up
```
This target:
1. Starts the `pg-streaming` (standard PG) and `barman-streaming` containers.
2. Waits for PostgreSQL to be ready.
3. Automatically creates a physical replication slot named `barman` on PostgreSQL.
4. Spawns `barman receive-wal pg` in the background inside the Barman container.

### Step 2: Check Barman Setup
Run the diagnostics check:
```bash
make check
```
Observe that all checks pass. Notice the `pg_receivewal` and `replication slot` status check results are `OK`.

### Step 3: View Replication Status
Check the status of replication and WAL archiving:
```bash
make status
```
Look for:
- `Active: true` under WAL information.
- The list of replication slots showing `barman` is active.

### Step 4: Insert Test Data
Generate database activity:
```bash
make insert-data
```

### Step 5: Perform Streaming Backup
Take a physical backup over the PostgreSQL protocol:
```bash
make backup
```
Barman streams the database files using the replication API.

### Step 6: Verify Local Recovery
Since there is no SSH command configured in this scenario, Barman performs a **local recovery** directly on the Barman container's filesystem.
```bash
make recover
```
Check the output to verify that the files are recovered locally in `/var/lib/barman/recovered-data/` on the Barman container.

### Step 7: Clean Up
Tear down the docker environment:
```bash
make down
```

---

## Key Educational Takeaways
1. **No SSH Required:** Streaming backup relies entirely on the SQL port, which is highly advantageous in highly locked-down environments (e.g., PaaS databases, Kubernetes).
2. **Zero Data Loss (Almost):** Because WALs are streamed in real-time, the database does not wait for a full 16MB file switch before archiving. You lose significantly less data in a crash (RPO approaches zero).
3. **Local Recovery:** Recovery occurs on the Barman server itself. To boot this recovered database, you would transfer the files to the target host manually or mount them.
