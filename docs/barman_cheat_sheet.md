# Barman 3.19.1 Cheat Sheet

This cheat sheet provides a comprehensive reference for **Backup and Recovery Manager (Barman) 3.19.1** CLI commands, configuration directives, backup methods, and exit codes.

---

## 1. CLI Commands Quick Reference

### Core Barman Commands

| Command | Synopsis / Syntax | Description & Key Options |
|:---|:---|:---|
| **`barman check`** | `barman check [options] <server>` | Performs diagnostics on connections, configuration, and WAL archiving.<br>• `--nagios`: Outputs Nagios/Icinga-compatible format.<br>• `all`: Runs checks for all configured servers. |
| **`barman backup`** | `barman backup [options] <server>` | Executes a physical backup of the specified Postgres instance.<br>• `-j, --jobs <N>`: Run backup copy using $N$ parallel workers.<br>• `--incremental <id>`: Native PG 17+ block-level incremental backup (requires `backup_method = postgres`).<br>• `--reuse-backup <mode>`: Rsync file-level incremental backup (`link` or `copy`).<br>• `--immediate-checkpoint`: Force Postgres to execute checkpoints immediately. |
| **`barman restore`** | `barman restore [options] <server> <backup_id> <dest_dir>` | Restores the specified backup to a local or remote target directory.<br>• `--remote-ssh-command <ssh>`: Enables remote restore via SSH.<br>• `--staging-path <path>`: Directory to stage compressed/incremental files during restore.<br>• `--staging-location <local/remote>`: Specifies whether the staging path is local or remote.<br>• `--combine-mode <copy/link/clone/copy-file-range>`: pg_combinebackup copy mode (default: `copy`).<br>• `--standby-mode`: Creates `standby.signal` instead of `recovery.signal` (PG 12+).<br>• `--tablespace <name>:<path>`: Relocates a tablespace.<br>• `--get-wal` / `--no-get-wal`: Enable/disable dynamic WAL fetching during recovery.<br>• `--restore-command <cmd>`: Custom override command for Postgres recovery configuration. |
| **`barman recover`** | *Deprecated* | Deprecated alias for `barman restore`. |
| **`barman list-servers`** | `barman list-servers` | Lists all servers configured in Barman. |
| **`barman show-servers`** | `barman show-servers <server>` | Shows detailed configuration properties for a given server. |
| **`barman list-backups`** | `barman list-backups <server>` | Lists all available backups for a server, including IDs and sizes. |
| **`barman show-backup`** | `barman show-backup <server> <backup_id>` | Displays metadata and details about a specific backup. |
| **`barman list-files`** | `barman list-files <server> <backup_id>` | Lists all files contained in a backup (base backup, tablespaces). |
| **`barman delete`** | `barman delete <server> <backup_id>` | Deletes a backup from the catalog. |
| **`barman keep`** | `barman keep [options] <server> <backup_id>` | Pins a backup to protect it from retention policy pruning.<br>• `--target full`: Keep the backup and all associated WAL files.<br>• `--release`: Release the pin, allowing the backup to be pruned. |
| **`barman cron`** | `barman cron [options]` | Performs background maintenance tasks (retention cleanup, WAL compression).<br>• `--keep-descriptors`: Keeps stdout/stderr connected (ideal for Docker). |
| **`barman replication-status`** | `barman replication-status <server>` | Shows real-time streaming replication status for receiver processes. |
| **`barman diagnose`** | `barman diagnose` | Generates a diagnostic JSON dump containing system info, configs, and logs. |
| **`barman rebuild-xlogdb`** | `barman rebuild-xlogdb <server>` | Rebuilds the WAL metadata database (`xlogdb.db`) from archived files. |
| **`barman config-switch`** | `barman config-switch <server> <model>` | Switches active configuration overrides using a model.<br>• `--reset`: Removes the active model overrides. |

### Barman Client CLI Commands (`barman-cli`)

These commands are run on the **Postgres host** (usually inside the `archive_command` or `restore_command`).

* **`barman-wal-archive`**: Archives a WAL file to Barman via SSH/put-wal.
  * *Syntax*: `barman-wal-archive [options] <barman_host> <server_name> <wal_path>`
  * *Test Command*: `barman-wal-archive --test <barman_host> <server_name> DUMMY`
  * *Key Options*: `--compression <algo>`, `--compression-level <val>`, `--port <ssh_port>`
* **`barman-wal-restore`**: Restores WAL files from Barman during remote recovery.
  * *Syntax*: `barman-wal-restore [options] <barman_host> <server_name> <wal_name> <dest_path>`
  * *Test Command*: `barman-wal-restore --test <barman_host> <server_name> DUMMY DUMMY`

### Barman Cloud Commands (`barman-cli-cloud`)

These commands manage backups and WALs directly in cloud object stores (S3, GCS, Azure Blob).

* **`barman-cloud-backup`**: Creates a backup and transfers it directly to cloud storage.
* **`barman-cloud-backup-delete`**: Deletes cloud backups and corresponding WALs.
* **`barman-cloud-backup-show`**: Displays metadata of a cloud-stored backup.
* **`barman-cloud-backup-list`**: Lists backups stored in the cloud.
* **`barman-cloud-backup-keep`**: Pin/archive backups directly in cloud storage.
* **`barman-cloud-wal-archive`**: Sends WAL files to cloud storage directly from Postgres.
* **`barman-cloud-wal-restore`**: Restores WAL files from the cloud (used as Postgres `restore_command`).
* **`barman-cloud-check-wal-archive`**: Checks WAL archiving integrity in cloud storage.

---

## 2. Configuration Options Reference

Barman configs follow the INI format. Comments must start with `#` or `;` at the beginning of a line (no inline comments!).

| Parameter Name | Allowed Scopes | Value Type | Description & Default |
|:---|:---|:---|:---|
| **`active`** | Server, Model | Boolean | If `false`, server is read-only diagnostic mode. (Default: `true`) |
| **`backup_method`** | Global, Server, Model | Enum | Method used for backups: `rsync`, `postgres`, `local-to-cloud`, `snapshot`. |
| **`conninfo`** | Server, Model | String | PostgreSQL connection string (libpq format). Points to a single, specific host. |
| **`streaming_conninfo`** | Server, Model | String | Connection string for pg_receivewal streaming replication connection. |
| **`ssh_command`** | Global, Server, Model | String | Secure shell command to connect to Postgres host (e.g. `ssh postgres@pg`). |
| **`archiver`** | Global, Server, Model | Boolean | Enables WAL shipping via Postgres `archive_command`. (Default: `false`) |
| **`streaming_archiver`** | Global, Server, Model | Boolean | Enables WAL streaming via pg_receivewal. (Default: `false`) |
| **`streaming_archiver_name`** | Global, Server, Model | String | Application name of the receive-wal process. (Default: `barman_receive_wal`) |
| **`slot_name`** | Global, Server, Model | String | Replication slot name to use for WAL streaming. |
| **`create_slot`** | Global, Server, Model | Enum | Creates streaming slot automatically: `auto`, `manual`. (Default: `manual`) |
| **`retention_policy`** | Global, Server, Model | String | Backups retention. E.g. `REDUNDANCY 3` or `RECOVERY WINDOW OF 14 DAYS`. |
| **`retention_policy_mode`**| Global, Server, Model | Enum | Enforcing method. (Only `auto` is supported) |
| **`wal_retention_policy`** | Global, Server, Model | Enum | WAL retention method. (Only `main` is supported) |
| **`compression`** | Global, Server, Model | Enum | WAL/backup compression: `gzip`, `bzip2`, `xz`, `zstd`, `lz4`, `pigz`. (Default: `none`) |
| **`compression_level`** | Global, Server, Model | Integer/Enum | Predefined labels `low`, `medium`, `high` or numeric levels. |
| **`encryption`** | Global, Server, Model | Enum | Encryption method: `none` or `gpg`. (Default: `none`) |
| **`encryption_key_id`** | Global, Server, Model | String | Key ID/fingerprint of the GPG key used for encryption. |
| **`encryption_passphrase_command`** | Global, Server, Model | String | Command executing to retrieve decryption passphrase (e.g., `cat /path/to/key`). |
| **`staging_path`** | Global, Server, Model | String | Path where intermediate files are staged during restore. |
| **`staging_location`** | Global, Server, Model | Enum | Specifies if staging path is `local` (on Barman) or `remote` (on recovery host). |
| **`cloud_staging_directory`**| Global, Server, Model | String | Staging space for streaming Postgres backups directly to the cloud. |
| **`cloud_staging_max_size`** | Global, Server, Model | String | Maximum size of cloud staging directory (e.g., `30Gi`). |
| **`basebackups_directory`** | Global, Server, Model | String | Main base backup storage location. Can be local path or cloud URL (e.g., `s3://...`). |
| **`wals_directory`** | Global, Server, Model | String | Main WAL storage location. Can be local path or cloud URL (e.g., `s3://...`). |

---

## 3. Backup Methods Comparison

| Feature / Attribute | Rsync Backup (`rsync`) | Streaming Backup (`postgres`) | Cloud Snapshot (`snapshot`) | Local-to-Cloud (`local-to-cloud`) |
|:---|:---|:---|:---|:---|
| **Network Protocol** | SSH / Rsync | PG Streaming Protocol | Cloud API (AWS/GCP/Azure) | SSH/PG Stream + Cloud Upload |
| **SSH Required** | **Yes** (Both directions) | **No** (Optional) | **No** (Cloud API credentials) | **Yes** (if using Rsync) |
| **Postgres API Used** | Low-Level concurrent | `pg_basebackup` (Streaming) | Cloud API + Low-Level concurrent | `pg_basebackup` + Cloud Upload |
| **Incremental Type** | File-level (`reuse_backup`) | Block-level (PG 17+ `summarize_wal`) | Cloud Disk Snapshots (Delta) | Block-level (S3 staging) |
| **Postgres versions** | All | All (PG 17+ for Block Incremental) | Supported cloud VMs | All |
| **Restoration Command**| `barman restore` | `barman restore` | `barman restore` + Disk Attach | `barman restore` / `barman-cloud-restore` |

---

## 4. Exit Codes & Common Errors

### Standard Exit Statuses
* **`0`**: Success. Command executed successfully.
* **`1`**: General failure/error.
* **`2`**: Command syntax/parameter validation error.
* **`3`**: Connection failure.
* **`4`**: Permission denied.
* **`5`**: Interrupted by signal or user termination.

### Common `barman check` Statuses

* **`PostgreSQL: FAILED (connection error)`**: Check that Barman can connect to Postgres using `conninfo`. Test with `psql -d "conninfo_string"`.
* **`replication slot: FAILED`**: Verify the slot name matches `slot_name` in config and the slot actually exists in the database (`SELECT slot_name, active FROM pg_replication_slots;`). Run `barman receive-wal --create-slot <server>` to fix.
* **`archiving: FAILED`**: `archiver = off` in config, but WAL files exist in the `incoming/` directory. Check if `archive_command` is still sending WALs, or clean up/archive outstanding WAL files.
* **`received WAL files: FAILED`**: The timeline or WAL sequence has diverged, or the streaming directory is missing active files. Verify `pg_receivewal` process status with `barman replication-status <server>`.

---

## 5. Security Hardening Quick Reference

### Password & Credential Protection
* **Store Passwords securely**: Avoid `password=...` in `conninfo` configuration strings. Use `.pgpass` files.
  * **Location**: `~barman/.pgpass` (Barman host) and `~postgres/.pgpass` (Postgres host for restores).
  * **Format**: `pghost:5432:database:username:password` (e.g. `pg_host:5432:*:barman:secure_password`).
  * **Permissions**: Must be `0600` (`chmod 600 ~/.pgpass`).
* **Vault Passphrase Command**: Retrieve GPG/decryption passphrases dynamically:
  * `encryption_passphrase_command = "vault kv get -field=passphrase secret/barman/pg"`

### Network Transport Encryption (TLS/SSL)
* **Require Server Certificate Validation**: Use `sslmode=verify-ca` or `sslmode=verify-full`.
  * `conninfo = host=pghost user=barman dbname=postgres sslmode=verify-full sslrootcert=/etc/barman/root.crt`
* **Client Certificate Authentication**: Authenticate using SSL certificates instead of passwords:
  * `conninfo = ... sslmode=verify-full sslrootcert=/etc/barman/root.crt sslcert=/etc/barman/barman.crt sslkey=/etc/barman/barman.key`
  * PostgreSQL `pg_hba.conf` rule:
    `hostssl replication barman barman_host/32 cert clientcert=verify-full`

### Database Minimal Backup Privileges (PostgreSQL 15+)
Instead of using `superuser`, grant dedicated privileges:
```sql
CREATE USER barman WITH PASSWORD 'secure_password';
GRANT EXECUTE ON FUNCTION pg_backup_start(text, boolean) TO barman;
GRANT EXECUTE ON FUNCTION pg_backup_stop(boolean) TO barman;
GRANT EXECUTE ON FUNCTION pg_switch_wal() TO barman;
GRANT EXECUTE ON FUNCTION pg_create_restore_point(text) TO barman;
GRANT pg_read_all_settings TO barman;
GRANT pg_read_all_stats TO barman;
GRANT pg_checkpoint TO barman; -- Needed for switch-wal --force
```

### SSH Key Restrictions
Restrict options in `~/.ssh/authorized_keys` for backup/WAL exchange keys:
* **Option Options**:
  ```text
  no-port-forwarding,no-x11-forwarding,no-agent-forwarding,no-pty ssh-rsa AAAAB3...
  ```
* **Forced Command restriction**:
  Restrict the SSH key to only run WAL archiving commands:
  ```text
  command="/usr/local/bin/barman-ssh-filter.sh",no-port-forwarding,no-x11-forwarding,no-agent-forwarding,no-pty ssh-rsa AAAAB3...
  ```
  *Filter Script (`/usr/local/bin/barman-ssh-filter.sh`)*:
  ```bash
  #!/bin/bash
  case "$SSH_ORIGINAL_COMMAND" in
      "barman put-wal "* ) exec $SSH_ORIGINAL_COMMAND ;;
      * ) echo "Access Denied" >&2; exit 1 ;;
  esac
  ```

