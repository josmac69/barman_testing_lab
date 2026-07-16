.PHONY: setup build up down check status backup list-backups run-pitr-demo clean

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
	@echo "Waiting for PostgreSQL and barman user to be ready..."
	@until docker compose exec -T pg psql -U barman -d postgres -c "SELECT 1" >/dev/null 2>&1; do sleep 1; done
	@echo "PostgreSQL and barman user are ready."

up-monitoring: setup
	docker compose -f docker-compose.yml -f ../monitoring/docker-compose.yml up -d --build
	@echo "Waiting for PostgreSQL and barman user to be ready..."
	@until docker compose exec -T pg psql -U barman -d postgres -c "SELECT 1" >/dev/null 2>&1; do sleep 1; done
	@echo "PostgreSQL and barman user are ready."

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

run-pitr-demo:
	@chmod +x scripts/pitr_demo.sh
	bash scripts/pitr_demo.sh

clean: down
	rm -rf .ssh_keys
