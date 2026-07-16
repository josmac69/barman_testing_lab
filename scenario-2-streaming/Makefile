.PHONY: up down check status backup list-backups insert-data recover clean

up:
	docker compose up -d
	@echo "Waiting for PostgreSQL and barman user to be ready..."
	@until docker compose exec -T pg psql -U barman -d postgres -c "SELECT 1" >/dev/null 2>&1; do sleep 1; done
	@echo "PostgreSQL and barman user are ready."
	@echo "Creating replication slot 'barman'..."
	-docker compose exec -u barman barman barman receive-wal --create-slot pg
	@echo "Starting streaming WAL receiver in the background..."
	-docker compose exec -d -u barman barman barman receive-wal pg
	@echo "Waiting for WAL receiver to connect..."
	@sleep 3

up-monitoring:
	docker compose -f docker-compose.yml -f ../monitoring/docker-compose.yml up -d
	@echo "Waiting for PostgreSQL and barman user to be ready..."
	@until docker compose exec -T pg psql -U barman -d postgres -c "SELECT 1" >/dev/null 2>&1; do sleep 1; done
	@echo "PostgreSQL and barman user are ready."
	@echo "Creating replication slot 'barman'..."
	-docker compose exec -u barman barman barman receive-wal --create-slot pg
	@echo "Starting streaming WAL receiver in the background..."
	-docker compose exec -d -u barman barman barman receive-wal pg
	@echo "Waiting for WAL receiver to connect..."
	@sleep 3

down:
	docker compose -f docker-compose.yml -f ../monitoring/docker-compose.yml down --remove-orphans

check:
	@echo "Switching WAL and running cron to process the first streamed segment..."
	-docker compose exec -u barman barman barman switch-wal --force pg
	sleep 2
	docker compose exec -u barman barman barman cron
	docker compose exec -u barman barman barman check pg

status:
	docker compose exec -u barman barman barman status pg

backup:
	docker compose exec -u barman barman barman backup pg

list-backups:
	docker compose exec -u barman barman barman list-backup pg

insert-data:
	docker compose exec -T pg psql -U postgres -d postgres -c "CREATE TABLE IF NOT EXISTS test_table (id serial PRIMARY KEY, val text, created_at timestamp default now());"
	docker compose exec -T pg psql -U postgres -d postgres -c "INSERT INTO test_table (val) VALUES ('Data inserted via streaming scenario at $$(date +'%Y-%m-%d %H:%M:%S')');"
	docker compose exec -T pg psql -U postgres -d postgres -c "SELECT * FROM test_table;"

recover:
	@echo "Cleaning local recovery directory inside Barman container..."
	docker compose exec -u barman barman rm -rf /var/lib/barman/recovered-data
	docker compose exec -u barman barman mkdir -p /var/lib/barman/recovered-data
	@echo "Recovering latest backup locally..."
	docker compose exec -u barman barman barman recover pg latest /var/lib/barman/recovered-data
	@echo "Verifying recovered data structure on Barman container:"
	docker compose exec -u barman barman ls -la /var/lib/barman/recovered-data

clean: down
	@echo "Clean completed."
