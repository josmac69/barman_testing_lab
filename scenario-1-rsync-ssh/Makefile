.PHONY: setup build up down check status backup list-backups insert-data switch-wal recover clean

# Generate SSH keys dynamically
setup:
	@mkdir -p .ssh_keys
	@[ -f .ssh_keys/id_rsa_postgres ] || ssh-keygen -t rsa -b 2048 -N "" -f .ssh_keys/id_rsa_postgres
	@[ -f .ssh_keys/id_rsa_barman ] || ssh-keygen -t rsa -b 2048 -N "" -f .ssh_keys/id_rsa_barman
	@cat .ssh_keys/id_rsa_postgres.pub > .ssh_keys/authorized_keys_barman
	@cat .ssh_keys/id_rsa_barman.pub > .ssh_keys/authorized_keys_postgres
	@chmod 600 .ssh_keys/*

build: setup
	docker compose build

up: setup
	docker compose up -d --build
	@echo "Waiting for PostgreSQL to start..."
	@until docker compose exec -T pg pg_isready -U postgres; do sleep 1; done
	@echo "PostgreSQL is ready."

up-monitoring: setup
	docker compose -f docker-compose.yml -f ../monitoring/docker-compose.yml up -d --build
	@echo "Waiting for PostgreSQL to start..."
	@until docker compose exec -T pg pg_isready -U postgres; do sleep 1; done
	@echo "PostgreSQL is ready."

down:
	docker compose -f docker-compose.yml -f ../monitoring/docker-compose.yml down --remove-orphans

check:
	docker compose exec -u barman barman barman check pg

status:
	docker compose exec -u barman barman barman status pg

backup:
	docker compose exec -u barman barman barman backup pg

list-backups:
	docker compose exec -u barman barman barman list-backup pg

insert-data:
	docker compose exec -T pg psql -U postgres -d postgres -c "CREATE TABLE IF NOT EXISTS test_table (id serial PRIMARY KEY, val text, created_at timestamp default now());"
	docker compose exec -T pg psql -U postgres -d postgres -c "INSERT INTO test_table (val) VALUES ('Data inserted at $$(date +'%Y-%m-%d %H:%M:%S')');"
	docker compose exec -T pg psql -U postgres -d postgres -c "SELECT * FROM test_table;"

switch-wal:
	docker compose exec -T pg psql -U postgres -d postgres -c "SELECT pg_switch_wal();"

recover:
	@echo "Creating clean recovery directory on postgres container..."
	docker compose exec -T -u postgres pg rm -rf /var/lib/postgresql/recovered-data
	docker compose exec -T -u postgres pg mkdir -p /var/lib/postgresql/recovered-data
	@echo "Executing Barman Recovery..."
	docker compose exec -u barman barman barman recover --remote-ssh-command "ssh postgres@pg" pg latest /var/lib/postgresql/recovered-data
	@echo "Verifying recovered data structure on postgres container:"
	docker compose exec -T -u postgres pg ls -la /var/lib/postgresql/recovered-data

clean: down
	rm -rf .ssh_keys
