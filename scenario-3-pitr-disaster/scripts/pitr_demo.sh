#!/bin/bash
set -e

# Helper colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== Starting PITR Disaster & Recovery Demo ===${NC}"

# 1. Prepare table and baseline data
echo -e "\n1. Creating table and inserting baseline data..."
docker compose exec -T pg psql -U postgres -d postgres -c "
    DROP TABLE IF EXISTS test_pitr;
    CREATE TABLE test_pitr (id int PRIMARY KEY, val text, created_at timestamp default now());
    INSERT INTO test_pitr VALUES (1, 'Baseline data');
"

# 2. Initializing WAL archiving...
echo -e "\n2. Initializing WAL archiving..."
docker compose exec -T pg psql -U postgres -d postgres -c "SELECT pg_switch_wal();"
echo "Waiting for WAL segment to be processed by Barman..."
for i in {1..10}; do
    docker compose exec -u barman barman barman cron >/dev/null 2>&1
    if docker compose exec -u barman barman barman check pg >/dev/null 2>&1; then
        echo "WAL archiving is active and check passed!"
        break
    fi
    sleep 1
done
echo -e "\nTaking initial full physical backup..."
docker compose exec -u barman barman barman backup pg

# 3. Insert important data that we want to keep
echo -e "\n3. Inserting important data (to be kept)..."
docker compose exec -T pg psql -U postgres -d postgres -c "
    INSERT INTO test_pitr VALUES (2, 'Important data (keep)');
"

# 4. Create named restore point
echo -e "\n4. Creating a named restore point 'before_disaster'..."
docker compose exec -T pg psql -U postgres -d postgres -c "
    SELECT pg_create_restore_point('before_disaster');
"

# 5. Advance WALs to ensure restore point is archived
echo -e "\n5. Switching WAL segment to force WAL archiving..."
docker compose exec -T pg psql -U postgres -d postgres -c "SELECT pg_switch_wal();"

# Wait a second for rsync to complete WAL archival and run cron
sleep 2
docker compose exec -u barman barman barman cron

# 6. Simulate the disaster
echo -e "\n6. SIMULATING DISASTER: Dropping the table..."
docker compose exec -T pg psql -U postgres -d postgres -c "
    DROP TABLE test_pitr;
"
echo -e "Checking if table exists in live database (should fail/show relation does not exist):"
docker compose exec -T pg psql -U postgres -d postgres -c "SELECT * FROM test_pitr;" || echo -e "${RED}^^^ Live database has lost the table!${NC}"

# 7. Perform PITR recovery to a secondary directory
echo -e "\n7. Executing PITR recovery to /var/lib/postgresql/recovered-data targeting 'before_disaster'..."
docker compose exec -T -u postgres pg rm -rf /var/lib/postgresql/recovered-data
docker compose exec -T -u postgres pg mkdir -p /var/lib/postgresql/recovered-data

# Run recovery command
docker compose exec -u barman barman barman recover --remote-ssh-command "ssh postgres@pg" --target-name "before_disaster" pg latest /var/lib/postgresql/recovered-data

# 8. Start recovered database on port 5433
echo -e "\n8. Starting recovered PostgreSQL database instance on port 5433..."
docker compose exec -T -u postgres pg pg_ctl -D /var/lib/postgresql/recovered-data -o "-p 5433" -l /var/lib/postgresql/recovered-data/logfile start

# Wait for database recovery and startup
echo "Waiting 5 seconds for PostgreSQL recovery log replay to finish..."
sleep 5

# 9. Query recovered database and verify
echo -e "\n9. Verifying recovered database content on port 5433:"
docker compose exec -T pg psql -U postgres -d postgres -p 5433 -c "SELECT * FROM test_pitr;"

# 10. Clean up the recovered database instance
echo -e "\n10. Stopping the recovered PostgreSQL database instance..."
docker compose exec -T -u postgres pg pg_ctl -D /var/lib/postgresql/recovered-data stop

echo -e "\n${GREEN}=== PITR Disaster & Recovery Demo Completed Successfully! ===${NC}"
