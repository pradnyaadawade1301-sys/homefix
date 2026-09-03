.PHONY: run build docker-up docker-down docker-logs tidy test test-unit test-integration test-db-up test-db-down

run:
	go run ./cmd/server

build:
	go build -o bin/homefix-server ./cmd/server

tidy:
	go mod tidy

# Unit tests (utils, pure logic) — no database needed.
test-unit:
	go test ./internal/... -v

# Spins up a disposable Postgres on :5435 and applies every migration, so
# `make test` exercises the real app (see internal/testserver + test/integration)
# instead of a hand-rolled stand-in.
test-db-up:
	docker run -d --name homefix_test_pg -e POSTGRES_USER=homefix -e POSTGRES_PASSWORD=homefix_pass \
		-e POSTGRES_DB=homefix_test -p 5435:5432 postgres:16-alpine
	@sleep 5
	@for f in migrations/*.sql; do \
		docker exec -i homefix_test_pg psql -U homefix -d homefix_test -v ON_ERROR_STOP=1 < $$f; \
	done

test-db-down:
	docker rm -f homefix_test_pg

test-integration:
	TEST_DATABASE_URL="postgres://homefix:homefix_pass@localhost:5435/homefix_test?sslmode=disable" go test ./test/... -v

# Full suite: unit + integration (spins the test DB up, runs everything, tears it down).
test: test-db-up
	$(MAKE) test-unit
	$(MAKE) test-integration
	$(MAKE) test-db-down

docker-up:
	docker compose up --build -d

docker-down:
	docker compose down

docker-logs:
	docker compose logs -f app

# Applies every migrations/*.sql file, in order, against the running dev
# Postgres container (homefix_postgres from docker-compose.yml). Safe to
# re-run any time — every migration in this repo is written with
# IF NOT EXISTS / IF EXISTS guards, so already-applied ones are a no-op.
# Use this instead of a manual `docker exec ... psql` one-liner whenever a
# new migration file is added.
migrate:
	@for f in migrations/*.sql; do \
		echo "applying $$f"; \
		docker exec -i homefix_postgres psql -U homefix -d homefix -v ON_ERROR_STOP=1 < $$f; \
	done