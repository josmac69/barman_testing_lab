.PHONY: up down check status backup list-backups run-retention-demo clean

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

run-retention-demo:
	@chmod +x scripts/retention_demo.sh
	bash scripts/retention_demo.sh

clean: down
	@echo "Clean completed."
