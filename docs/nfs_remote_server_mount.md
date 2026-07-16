# NFS Mounting Guide for Barman

In the scope of [Barman (Backup and Recovery Manager)](https://pgbarman.org/about/) for PostgreSQL, NFS (Network File System) mounting allows you to store database backups and Write-Ahead Log (WAL) files on a remote storage server rather than local disks. This separates your compute resources from your backup storage, providing protection against local hardware failures. [1, 2]
However, because Barman and PostgreSQL require strict file integrity and write confirmations, using an NFS mount demands rigid configuration to prevent data corruption. [3, 4, 5]

## Core Requirements for Safe NFS Mounting
Like PostgreSQL, Barman does not feature native, internal handling specific to network shares. You must enforce proper behavior at the Linux operating system level by strictly following the [Official Barman Backup Guidelines](https://docs.pgbarman.org/release/3.19.1/user_guide/backup.html): [2]

* Isolate Lock Directories: The barman_lock_directory parameter must point to a local, non-network filesystem. If lock files are placed on an NFS share, network latency or locking bugs can stall or break backup execution. [2]
* Enforce NFSv4: You must use at least NFS protocol version 4. Older versions (NFSv3) handle file locking and state tracking poorly over unreliable networks. [2, 6, 7]
* Use Hard Mounts (hard): The share must be mounted using the hard option. If the storage server becomes temporarily unavailable, a hard mount forces Barman processes to pause and retry indefinitely rather than returning an immediate write error (soft mount), which would abort and invalidate your backup. [2, 8]
* Enforce Synchronous Writes (sync): The share must be mounted using the sync option. This guarantees that data is physically committed to the remote disk before the write operation returns success to Barman, preventing data loss during unexpected network cuts or power failures. [2]

------------------------------
## Implementation Example
To correctly mount your remote backup directory, add an explicit entry to your Barman server's /etc/fstab file using the required safety parameters: [2, 9]

# Example /etc/fstab entry for Barman storage
nfs-server.internal:/mnt/backups/pg  /var/lib/barman  nfs4  rw,hard,sync,proto=tcp,noatime,nodev,nosuid  0  0

Once mounted, ensure that ownership of the target directory is completely delegated to the system's barman user:

sudo chown -R barman:barman /var/lib/barman

------------------------------
## Pros and Cons of NFS with Barman

| Benefit | Risk / Drawback |
|---|---|
| Centralized Storage: Simplifies capacity planning across multiple database clusters. | Network Bottleneck: Large concurrent rsync or streaming backups can saturate network interfaces. |
| Hardware Isolation: Protects backup history if the Barman compute instance suffers a total failure. | Latency Issues: Incremental backups checking file attributes can be slowed down by network roundtrips. |
| Elastic Scaling: Allows you to resize underlying storage network volumes dynamically. | Dependency Risks: If the NFS server goes offline, Barman's processes will hang due to the mandatory hard mount constraint. |

[1] [https://groups.google.com](https://groups.google.com/g/pgbarman/c/0RnRCd0iY7w)
[2] [https://docs.pgbarman.org](https://docs.pgbarman.org/release/3.19.1/user_guide/backup.html)
[3] [https://docs.pgbarman.org](https://docs.pgbarman.org/release/3.9.0/)
[4] [https://gist.github.com](https://gist.github.com/fardjad/ea358f9bf844889ecad109b352dd0d5b)
[5] [https://docs.pgbarman.org](https://docs.pgbarman.org/release/3.12.1/user_guide/concepts.html)
[6] [https://docs.pgbarman.org](https://docs.pgbarman.org/release/3.17.0/user_guide/backup.html)
[7] [https://www.alibabacloud.com](https://www.alibabacloud.com/help/en/nas/user-guide/mount-an-nfs-file-system-on-a-linux-ecs-instance)
[8] [https://help.sap.com](https://help.sap.com/docs/SUPPORT_CONTENT/basis/3354611703.html)
[9] [https://www.webasha.com](https://www.webasha.com/blog/nfs-server-setup-on-linux-step-by-step-guide-to-share-files-over-network)
