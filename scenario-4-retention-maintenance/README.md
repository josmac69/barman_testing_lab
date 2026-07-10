# Scenario 4: Retention Policies & Maintenance (Pinning)

This scenario demonstrates backup lifecycle management, **retention policies**, backup pinning (**`keep`**), and the role of the maintenance cron job (**`barman cron`**).

---

## What is a Retention Policy?

To prevent backup storage from growing indefinitely, Barman supports defining **Retention Policies** to automatically delete old backups:
1. **Redundancy-based:** Keeps a minimum number of full backups. (e.g. `retention_policy = REDUNDANCY 2`).
2. **Recovery Window-based:** Keeps all backups necessary to restore the database to *any point in time* within a specified window. (e.g. `retention_policy = RECOVERY WINDOW OF 7 DAYS`).

These policies are enforced when you run **`barman cron`** (the Barman maintenance command).

---

## What is Backup Pinning (`keep`)?

Sometimes, you need to retain a specific backup regardless of the retention policy (e.g. before a major application upgrade, or a financial year-end snapshot). 

Barman allows you to **pin** a backup, which exempts it from the retention policy pruning rules:
- **Pin a backup:** `barman keep <server> <backup_id>`
- **Unpin a backup:** `barman keep <server> <backup_id> release`

---

## Configuration Highlight

### Barman Server Config (`/etc/barman.d/pg.conf`)
```ini
[pg]
...
retention_policy = REDUNDANCY 2
```
- This configuration enforces a redundancy limit of 2. Barman will only keep the 2 latest unpinned backups. Any older unpinned backups will be marked for deletion and pruned during the next maintenance cycle.

---

## Detailed Lab Guide

### Step 1: Boot the Environment
Build and start the services:
```bash
make up
```
This starts the `pg-retention` and `barman-retention` containers, initializes the replication slot, and starts the WAL streaming daemon.

### Step 2: Run the Automated Retention Demo
We have provided an automated script that walks you through the entire lifecycle:
```bash
make run-retention-demo
```

### Script Execution Breakdown (Pedagogical Flow)
Here is what happens step-by-step when you run the demo:

1. **Backup 1 & Pinning:** We take the first backup (`Backup 1`) and immediately pin it:
   ```bash
   barman keep pg <backup_1_id>
   ```
2. **Backups 2 & 3:** We take two more backups (`Backup 2` and `Backup 3`). We now have 3 backups in total.
3. **First Cron Check:** We run `barman cron`. Normally, with `REDUNDANCY 2`, the oldest backup (`Backup 1`) would be deleted. However, because `Backup 1` is pinned, all 3 backups are preserved.
4. **Backup 4:** We take a fourth backup (`Backup 4`).
5. **Second Cron Check:** We run `barman cron` again. We now have 4 backups. 
   - The latest two unpinned backups are `Backup 3` and `Backup 4` (redundancy = 2).
   - `Backup 1` is pinned, so it is preserved.
   - `Backup 2` is unpinned and older than the latest two unpinned backups, so `Backup 2` is automatically deleted.
   - The catalog now contains: `Backup 1` (pinned), `Backup 3`, and `Backup 4`.
6. **Release & Clean:** We release the pin on `Backup 1`:
   ```bash
   barman keep pg <backup_1_id> release
   ```
   We run `barman cron` one last time. Since `Backup 1` is no longer pinned and exceeds our redundancy limit, it is deleted. Only `Backup 3` and `Backup 4` remain in the catalog.

---

## Key Educational Takeaways
1. **Cron is the Enforcer:** Retention policies do *not* delete backups during the backup process. Deletion is lazy and only occurs when `barman cron` is executed (usually configured as a system cron job every minute or hour).
2. **Pinned Backups Exemption:** Pinned backups are completely excluded from the pruning phase, allowing safe long-term retention of critical milestones without modifying global retention configuration.
3. **Redundancy Limits are Relative:** The redundancy calculation counts unpinned backups. Pinned backups do not use up your redundancy "slots".
