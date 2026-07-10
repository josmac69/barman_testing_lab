# PostgreSQL Barman Backup & Recovery Workshop Lab

Welcome to the **Barman (Backup and Recovery Manager) Workshop Lab**. This repository is designed to teach you the core capabilities, operations, and advanced disaster recovery features of Barman for PostgreSQL.

All scenarios in this workshop run entirely inside **Docker** containers. This lab is organized into independent directories, allowing you to study, run, and break each scenario in isolation.

---

## Workshop Architecture & Scenarios

The lab is divided into four standalone scenarios:

| Scenario | Directory | Backup Method | WAL Delivery | Key Concepts Covered |
| :--- | :--- | :--- | :--- | :--- |
| **1. Classic SSH/Rsync** | [`scenario-1-rsync-ssh`](./scenario-1-rsync-ssh/) | `rsync` (SSH) | File-based `archive_command` | SSH key management, remote execution, file-level copy, incremental backups. |
| **2. Streaming Replication** | [`scenario-2-streaming`](./scenario-2-streaming/) | `postgres` (PG Protocol) | Streaming WAL via `pg_receivewal` | Streaming slot setup, backup without SSH, concurrent archiving. |
| **3. PITR & Disaster Recovery** | [`scenario-3-pitr-disaster`](./scenario-3-pitr-disaster/) | `postgres` (PG Protocol) | Streaming WAL | Named restore points, timestamp recovery, transaction ID recovery, disk corruption recovery. |
| **4. Retention & Maintenance** | [`scenario-4-retention-maintenance`](./scenario-4-retention-maintenance/) | `postgres` (PG Protocol) | Streaming WAL | Redundancy policies, recovery window policies, backup pinning (`keep`), automated pruning via `barman cron`. |

---

## Prerequisites

To run these scenarios, make sure your host machine has the following tools installed:
- **Docker** (v20.10 or higher)
- **Docker Compose v2**
- **GNU Make** (to run the simulation commands easily)

---

## Getting Started

1. Choose a scenario directory to run. For example, to start with the classic SSH/Rsync backup:
   ```bash
   cd scenario-1-rsync-ssh
   ```
2. Each directory contains a `README.md` file with detailed instructions for that specific topic.
3. Use the provided `Makefile` to set up, build, boot, execute tasks, trigger backups, simulate crashes, and clean up.

For example, a common workflow for any scenario is:
```bash
# Build and bring up the container environment
make up

# Check Barman connectivity and status
make check

# Take a full physical backup
make backup

# Simulate a disaster or run the scenario demo
make run-demo  # (or make recover / make pitr-demo depending on the scenario)

# Tear down the environment when done
make down
```

---

## Learning Objectives

By completing this workshop, you will learn how to:
1. Configure Barman for both traditional SSH/rsync and modern streaming replication deployments.
2. Verify backup health and diagnose configuration issues using `barman check` and `barman status`.
3. Set up continuous WAL archiving and verify WAL delivery.
4. Execute full database recoveries (`barman recover`) to different directories or instances.
5. Implement Point-in-Time Recovery (PITR) to restore database state precisely before a disaster.
6. Manage backup catalogs and define automated retention policies to control storage growth.