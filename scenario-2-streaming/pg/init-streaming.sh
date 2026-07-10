#!/bin/bash
set -e

# Create barman replication user
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    CREATE USER barman WITH SUPERUSER REPLICATION PASSWORD 'barman';
EOSQL

# Append replication allowance to pg_hba.conf
echo "host replication barman all trust" >> "$PGDATA/pg_hba.conf"

# Reload configuration
pg_ctl reload
