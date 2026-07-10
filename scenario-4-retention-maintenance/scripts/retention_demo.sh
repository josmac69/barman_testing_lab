#!/bin/bash
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Starting Retention & Pinning Demo ===${NC}"

# Function to get list of backups
list_backups() {
    docker compose exec -u barman barman barman list-backup pg
}

echo -e "\n1. Current backup catalog (should be empty):"
list_backups

# 2. Take Backup 1
echo -e "\n2. Initializing WAL archiving..."
docker compose exec -u barman barman barman switch-wal --force pg
echo "Waiting for WAL segment to be processed by Barman..."
for i in {1..10}; do
    docker compose exec -u barman barman barman cron >/dev/null 2>&1
    if docker compose exec -u barman barman barman check pg >/dev/null 2>&1; then
        echo "WAL archiving is active and check passed!"
        break
    fi
    sleep 1
done
echo -e "Taking Backup 1..."
docker compose exec -u barman barman barman backup pg
BACKUP_1_ID=$(list_backups | head -n 1 | awk '{print $2}')
echo -e "${GREEN}Backup 1 completed with ID: $BACKUP_1_ID${NC}"

# 3. Pin Backup 1
echo -e "\n3. Pinning Backup 1 so retention policy doesn't prune it..."
docker compose exec -u barman barman barman keep --target full pg "$BACKUP_1_ID"

# 4. Take Backup 2 and Backup 3
echo -e "\n4. Taking Backup 2..."
docker compose exec -u barman barman barman backup pg
echo -e "Taking Backup 3..."
docker compose exec -u barman barman barman backup pg

echo -e "\nCatalog status (3 backups taken; Backup 1 is pinned):"
list_backups

# 5. Run barman cron
echo -e "\n5. Running 'barman cron' (retention is REDUNDANCY 2)..."
docker compose exec -u barman barman barman cron

echo -e "\nCatalog status after cron (all 3 should remain because Backup 1 is pinned):"
list_backups

# 6. Take Backup 4
echo -e "\n6. Taking Backup 4..."
docker compose exec -u barman barman barman backup pg

echo -e "\nCatalog status before cron (4 backups present):"
list_backups

# 7. Run cron again
echo -e "\n7. Running 'barman cron' again..."
docker compose exec -u barman barman barman cron

echo -e "\nCatalog status after cron (Backup 2 should be pruned, Backup 1 pinned, Backup 3 & 4 kept as redundancy = 2):"
list_backups

# 8. Release pin on Backup 1
echo -e "\n8. Releasing the pin on Backup 1..."
docker compose exec -u barman barman barman keep --release pg "$BACKUP_1_ID"

# 9. Run cron one last time
echo -e "\n9. Running 'barman cron' after releasing the pin..."
docker compose exec -u barman barman barman cron

echo -e "\nCatalog status (Backup 1 should now be pruned; only Backup 3 & 4 remain):"
list_backups

echo -e "\n${GREEN}=== Retention & Pinning Demo Completed Successfully! ===${NC}"
