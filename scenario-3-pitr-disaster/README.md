# Scenario 3: Point-in-Time Recovery & Disaster Recovery

This scenario focuses on **Point-in-Time Recovery (PITR)** and disaster recovery. You will simulate a database crash (a dropped table) and restore the database to the exact state it was in right before the disaster.

---

## What is Point-in-Time Recovery (PITR)?

A full backup is a snapshot of the database at a specific moment in time. PITR combines this full backup with a stream of subsequent write-ahead logs (WALs). By replaying WAL files sequentially, PostgreSQL can reconstruct the database state at *any arbitrary microsecond* or *named restore point* between the backup time and the present.

---

## How does recovery fetch WALs?

During recovery, the PostgreSQL engine reads the database files and replays WAL files. If the WAL file is not locally present in the data directory, PostgreSQL runs the `restore_command`. 

In this lab, Barman automatically configures the recovered instance's `postgresql.auto.conf` to use **`barman-wal-restore`**:
```ini
restore_command = 'barman-wal-restore -U barman barman pg %f %p'
```
- This tool is part of the `barman-cli` package.
- It runs inside the PG container and SSHes into the Barman container as the `barman` user to pull the required WAL segments.
- This is why the PG container in this scenario builds from a custom Dockerfile with `barman-cli` and SSH keys pre-provisioned!

---

## Detailed Lab Guide

### Step 1: Boot the Environment
Use the Makefile to set up the keys, build the images, and start the containers:
```bash
make up
```

### Step 2: Run the Automated PITR Demo
We have provided an automated script that performs the database preparation, runs the backup, performs subsequent inserts, sets up a named restore point, drops the database table, recovers to a secondary directory, and boots it.
```bash
make run-pitr-demo
```

### Script Execution Breakdown (Pedagogical Flow)
Here is what happens step-by-step when you run the demo:

1. **Prepare Data:** The script connects to the database on port 5432 and inserts:
   - Row 1: `'Baseline data'`
2. **Initial Backup:** Barman takes a full backup of this baseline state.
3. **Insert Important Data:** We insert a second row:
   - Row 2: `'Important data (keep)'`
4. **Create Restore Point:** We tell PostgreSQL to mark this exact point in the WAL timeline:
   ```sql
   SELECT pg_create_restore_point('before_disaster');
   ```
5. **Force Archiving:** We rotate the WAL segment (`SELECT pg_switch_wal();`) to make sure the WAL containing our restore point is immediately archived on the Barman server.
6. **The Disaster:** We drop the table (`DROP TABLE test_pitr;`). If we query the database now, it will show a `relation "test_pitr" does not exist` error.
7. **Execution of Recovery:** Barman recovers the base backup to a new folder `/var/lib/postgresql/recovered-data` targeting our restore point:
   ```bash
   barman recover --target-name "before_disaster" pg latest /var/lib/postgresql/recovered-data
   ```
8. **Booting Recovered PG:** To verify the recovery, we spin up a second instance of PostgreSQL on port **`5433`** pointing to the recovered directory:
   ```bash
   pg_ctl -D /var/lib/postgresql/recovered-data -o "-p 5433" start
   ```
9. **Log Replay & Verification:** During boot, PostgreSQL reads `recovery.signal`, invokes `barman-wal-restore` to pull WAL files from Barman, replays them up to the `'before_disaster'` point, and opens for traffic.
10. **Query Check:** We query the database on port `5433`. The table is restored, containing `'Baseline data'` and `'Important data (keep)'`. The dropped table transaction (disaster) is successfully bypassed!
11. **Tear Down:** We stop the secondary PostgreSQL instance.

---

## Key Educational Takeaways
1. **Named Restore Points:** Timestamps can be tricky due to clock skew or timezone offsets. Named restore points (`pg_create_restore_point`) provide an alias to a specific WAL transaction ID, making recovery safe and deterministic.
2. **Zero Downtime Verification:** By recovering to a secondary directory and booting on a separate port (`5433`), you can verify the restored database's integrity *before* replacing the production database.
3. **Under the Hood of WAL restore:** Understanding how PostgreSQL pulls WALs using `barman-wal-restore` over SSH is critical for configuring multi-node recovery.
