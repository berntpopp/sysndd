# SysNDD Development Automation
# Usage: make <target>
# Run `make` or `make help` to see available commands

# =============================================================================
# Davis-Hansson Preamble (https://tech.davis-hansson.com/p/make/)
# =============================================================================
SHELL := bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules

# =============================================================================
# Project Root (auto-detected)
# =============================================================================
ROOT_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
HOST_R_HOME := $(shell R RHOME 2>/dev/null)
HOST_R_MARIADB_LIB_DIR ?= $(patsubst %/,%,$(dir $(HOST_R_HOME)))/mariadb
HOST_R_ENV_LD_LIBRARY_PATH := $(shell printf '%s' "$${LD_LIBRARY_PATH-}")
HOST_R_LD_LIBRARY_PATH ?= $(if $(wildcard $(HOST_R_MARIADB_LIB_DIR)/libmariadb.so*),$(HOST_R_MARIADB_LIB_DIR)$(if $(HOST_R_ENV_LD_LIBRARY_PATH),:$(HOST_R_ENV_LD_LIBRARY_PATH)),$(HOST_R_ENV_LD_LIBRARY_PATH))
HOST_RSCRIPT := env LD_LIBRARY_PATH="$(HOST_R_LD_LIBRARY_PATH)" Rscript --no-init-file

# =============================================================================
# ANSI Color Codes
# =============================================================================
GREEN := \033[0;32m
RED := \033[0;31m
CYAN := \033[0;36m
YELLOW := \033[0;33m
RESET := \033[0m

# =============================================================================
# Default Goal
# =============================================================================
.DEFAULT_GOAL := help

# =============================================================================
# PHONY Declarations
# =============================================================================
.PHONY: help check-r check-npm check-docker install-api install-app dev serve-app build-app watch-app test-api test-api-fast test-api-full coverage lint-api lint-app format-api format-app pre-commit ci-local _ci-cleanup preflight docker-build docker-up docker-down docker-dev docker-dev-db docker-logs docker-status install-dev doctor worktree-setup worktree-prune refresh-fixtures verify-gate playwright-stack playwright-stack-down playwright-stack-logs _playwright-seed-templates _playwright-seed-users

# =============================================================================
# Help Target (Self-documenting)
# =============================================================================
help: ## Show this help message
	@printf "SysNDD Development Commands\n\n"
	@printf "$(CYAN)Environment:$(RESET)\n"
	@grep -E '^[a-zA-Z_-]+:.*?## \[env\]' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## \\[env\\] "}; {printf "  \033[0;36m%-20s\033[0m %s\n", $$1, $$2}' || true
	@printf "\n$(CYAN)Development:$(RESET)\n"
	@grep -E '^[a-zA-Z_-]+:.*?## \[dev\]' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## \\[dev\\] "}; {printf "  \033[0;36m%-20s\033[0m %s\n", $$1, $$2}' || true
	@printf "\n$(CYAN)Testing:$(RESET)\n"
	@grep -E '^[a-zA-Z_-]+:.*?## \[test\]' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## \\[test\\] "}; {printf "  \033[0;36m%-20s\033[0m %s\n", $$1, $$2}' || true
	@printf "\n$(CYAN)Linting:$(RESET)\n"
	@grep -E '^[a-zA-Z_-]+:.*?## \[lint\]' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## \\[lint\\] "}; {printf "  \033[0;36m%-20s\033[0m %s\n", $$1, $$2}' || true
	@printf "\n$(CYAN)Docker:$(RESET)\n"
	@grep -E '^[a-zA-Z_-]+:.*?## \[docker\]' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## \\[docker\\] "}; {printf "  \033[0;36m%-20s\033[0m %s\n", $$1, $$2}' || true
	@printf "\n$(CYAN)Quality:$(RESET)\n"
	@grep -E '^[a-zA-Z_-]+:.*?## \[quality\]' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## \\[quality\\] "}; {printf "  \033[0;36m%-20s\033[0m %s\n", $$1, $$2}' || true

# =============================================================================
# Prerequisite Checks (not in help)
# =============================================================================
check-r:
	@command -v R > /dev/null 2>&1 || \
		(printf "$(RED)ERROR: R is not installed$(RESET)\n" && \
		 printf "Install R from: https://www.r-project.org/\n" && \
		 exit 1)

check-npm:
	@command -v npm > /dev/null 2>&1 || \
		(printf "$(RED)ERROR: npm is not installed$(RESET)\n" && \
		 printf "Install Node.js/npm from: https://nodejs.org/\n" && \
		 exit 1)

check-docker:
	@docker info > /dev/null 2>&1 || \
		(printf "$(RED)ERROR: Docker is not running$(RESET)\n" && \
		 printf "Start Docker Desktop and try again.\n" && \
		 exit 1)

# =============================================================================
# Development Targets
# =============================================================================
install-api: check-r ## [dev] Install R dependencies with renv::restore()
	@printf "$(CYAN)==> Installing R dependencies...$(RESET)\n"
	@cd $(ROOT_DIR)/api && R -e "renv::restore(prompt = FALSE)" && \
		printf "$(GREEN)✓ install-api complete$(RESET)\n" || \
		(printf "$(RED)✗ install-api failed$(RESET)\n" && exit 1)

install-app: check-npm ## [dev] Install frontend dependencies with npm install
	@printf "$(CYAN)==> Installing frontend dependencies...$(RESET)\n"
	@cd $(ROOT_DIR)/app && npm install && \
		printf "$(GREEN)✓ install-app complete$(RESET)\n" || \
		(printf "$(RED)✗ install-app failed$(RESET)\n" && exit 1)

dev: docker-dev ## [dev] Start full Docker dev stack (alias for docker-dev)

serve-app: check-npm ## [dev] Start Vue development server with hot reload
	@printf "$(CYAN)==> Starting Vue development server...$(RESET)\n"
	@cd $(ROOT_DIR)/app && npm run serve

build-app: check-npm ## [dev] Build frontend for production
	@printf "$(CYAN)==> Building frontend for production...$(RESET)\n"
	@cd $(ROOT_DIR)/app && npm run build && \
		printf "$(GREEN)✓ build-app complete$(RESET)\n" || \
		(printf "$(RED)✗ build-app failed$(RESET)\n" && exit 1)

watch-app: check-docker ## [dev] Start Docker Compose watch for frontend hot-reload
	@printf "$(CYAN)==> Starting Docker Compose watch mode...$(RESET)\n"
	@cd $(ROOT_DIR) && docker compose watch

# =============================================================================
# Testing Targets
# =============================================================================
test-api: check-r ## [test] Run R API tests with testthat
	@printf "$(CYAN)==> Running R API tests...$(RESET)\n"
	@cd $(ROOT_DIR)/api && $(HOST_RSCRIPT) scripts/run-ci-tests.R full && \
		printf "$(GREEN)✓ test-api complete$(RESET)\n" || \
		(printf "$(RED)✗ test-api failed$(RESET)\n" && exit 1)

test-api-fast: check-r ## [test] Run the fast R API test gate used on pull requests
	@printf "$(CYAN)==> Running fast R API tests...$(RESET)\n"
	@cd $(ROOT_DIR)/api && $(HOST_RSCRIPT) scripts/run-ci-tests.R fast && \
		printf "$(GREEN)✓ test-api-fast complete$(RESET)\n" || \
		(printf "$(RED)✗ test-api-fast failed$(RESET)\n" && exit 1)

test-api-full: check-r ## [test] Run full R API test suite including slow tests
	@printf "$(CYAN)==> Running full R API test suite (including slow tests)...$(RESET)\n"
	@cd $(ROOT_DIR)/api && RUN_SLOW_TESTS=true $(HOST_RSCRIPT) scripts/run-ci-tests.R full && \
		printf "$(GREEN)✓ test-api-full complete$(RESET)\n" || \
		(printf "$(RED)✗ test-api-full failed$(RESET)\n" && exit 1)

coverage: check-r ## [test] Generate test coverage report with covr
	@printf "$(CYAN)==> Calculating test coverage...$(RESET)\n"
	@mkdir -p $(ROOT_DIR)/coverage
	@cd $(ROOT_DIR)/api && $(HOST_RSCRIPT) scripts/coverage.R && \
		printf "$(GREEN)✓ coverage complete$(RESET)\n" || \
		(printf "$(RED)✗ coverage failed$(RESET)\n" && exit 1)

# =============================================================================
# Linting Targets
# =============================================================================
lint-api: check-r ## [lint] Check R code with lintr + migration prefix check
	@printf "$(CYAN)==> Checking R code with lintr...$(RESET)\n"
	@cd $(ROOT_DIR)/api && $(HOST_RSCRIPT) scripts/lint-check.R && \
		printf "$(GREEN)✓ lintr complete$(RESET)\n" || \
		(printf "$(RED)✗ lintr failed$(RESET)\n" && exit 1)
	@printf "$(CYAN)==> Checking migration prefixes...$(RESET)\n"
	@cd $(ROOT_DIR) && ./scripts/check-migration-prefixes.sh && \
		printf "$(GREEN)✓ lint-api complete$(RESET)\n" || \
		(printf "$(RED)✗ lint-api failed$(RESET)\n" && exit 1)

lint-app: check-npm ## [lint] Check frontend code with ESLint and MSW↔OpenAPI drift
	@printf "$(CYAN)==> Checking frontend code with ESLint...$(RESET)\n"
	@cd $(ROOT_DIR)/app && npm run lint && \
		printf "$(GREEN)✓ eslint complete$(RESET)\n" || \
		(printf "$(RED)✗ eslint failed$(RESET)\n" && exit 1)
	@printf "$(CYAN)==> Verifying MSW handlers against OpenAPI annotations...$(RESET)\n"
	@$(ROOT_DIR)/scripts/verify-msw-against-openapi.sh && \
		printf "$(GREEN)✓ lint-app complete$(RESET)\n" || \
		(printf "$(RED)✗ verify-msw-against-openapi failed$(RESET)\n" && exit 1)

format-api: check-r ## [lint] Format R code with styler
	@printf "$(CYAN)==> Formatting R code with styler...$(RESET)\n"
	@cd $(ROOT_DIR)/api && Rscript scripts/style-code.R && \
		printf "$(GREEN)✓ format-api complete$(RESET)\n" || \
		(printf "$(RED)✗ format-api failed$(RESET)\n" && exit 1)

format-app: check-npm ## [lint] Format frontend code with ESLint --fix
	@printf "$(CYAN)==> Formatting frontend code with ESLint --fix...$(RESET)\n"
	@cd $(ROOT_DIR)/app && npm run lint -- --fix && \
		printf "$(GREEN)✓ format-app complete$(RESET)\n" || \
		(printf "$(RED)✗ format-app failed$(RESET)\n" && exit 1)

# =============================================================================
# Quality Targets
# =============================================================================
pre-commit: ## [quality] Run all quality checks before committing
	@printf "$(CYAN)==> Running pre-commit quality checks...$(RESET)\n"
	@printf "\n$(CYAN)[1/3] Linting R code...$(RESET)\n"
	@$(MAKE) lint-api
	@printf "\n$(CYAN)[2/3] Linting frontend code...$(RESET)\n"
	@$(MAKE) lint-app
	@printf "\n$(CYAN)[3/3] Running fast R API tests...$(RESET)\n"
	@$(MAKE) test-api-fast
	@printf "\n$(GREEN)✓ All pre-commit checks passed!$(RESET)\n"

ci-local: ## [quality] Run CI checks locally (lint + test with DB - mirrors GitHub Actions)
	@printf "$(CYAN)==> Running CI checks locally (mirrors GitHub Actions)...$(RESET)\n"
	@printf "\n$(CYAN)[1/6] Starting test database...$(RESET)\n"
	@cd $(ROOT_DIR) && $(COMPOSE_DB_DEV) up -d mysql-test && \
		printf "$(GREEN)✓ Test database started$(RESET)\n" || \
		(printf "$(RED)✗ Failed to start test database$(RESET)\n" && exit 1)
	@printf "$(CYAN)Waiting for MySQL to be ready...$(RESET)\n"
	@SECONDS=0; \
	while [ $$SECONDS -lt 30 ]; do \
		if $(COMPOSE_DB_DEV) exec -T mysql-test mysqladmin ping -h localhost -u bernt -pNur7DoofeFliegen. --silent 2>/dev/null; then \
			printf "$(GREEN)MySQL ready$(RESET)\n"; \
			break; \
		fi; \
		printf "."; \
		sleep 1; \
		SECONDS=$$((SECONDS+1)); \
	done
	@printf "\n$(CYAN)[2/6] Linting R code...$(RESET)\n"
	@$(MAKE) lint-api || ($(MAKE) -C $(ROOT_DIR) _ci-cleanup && exit 1)
	@printf "\n$(CYAN)[3/6] Linting frontend code...$(RESET)\n"
	@$(MAKE) lint-app || ($(MAKE) -C $(ROOT_DIR) _ci-cleanup && exit 1)
	@printf "\n$(CYAN)[4/6] Type-checking frontend...$(RESET)\n"
	@cd $(ROOT_DIR)/app && npm run type-check || ($(MAKE) -C $(ROOT_DIR) _ci-cleanup && exit 1)
	@printf "$(GREEN)✓ Type check passed$(RESET)\n"
	@printf "\n$(CYAN)[5/6] Type-checking frontend (strict scopes)...$(RESET)\n"
	@cd $(ROOT_DIR)/app && npm run type-check:strict || ($(MAKE) -C $(ROOT_DIR) _ci-cleanup && exit 1)
	@printf "$(GREEN)✓ Strict type check passed$(RESET)\n"
	@printf "\n$(CYAN)[6/6] Running R API tests (with database)...$(RESET)\n"
	@cd $(ROOT_DIR)/api && \
		MYSQL_HOST=127.0.0.1 MYSQL_PORT=7655 MYSQL_DATABASE=sysndd_db_test \
		MYSQL_USER=bernt MYSQL_PASSWORD=Nur7DoofeFliegen. \
		$(HOST_RSCRIPT) scripts/run-ci-tests.R full || \
		($(MAKE) -C $(ROOT_DIR) _ci-cleanup && exit 1)
	@printf "$(GREEN)✓ Tests passed$(RESET)\n"
	@$(MAKE) -C $(ROOT_DIR) _ci-cleanup
	@printf "\n$(GREEN)========================================$(RESET)\n"
	@printf "$(GREEN)       CI-LOCAL PASSED                  $(RESET)\n"
	@printf "$(GREEN)========================================$(RESET)\n"
	@printf "\nAll checks that run in GitHub Actions passed locally.\n"
	@printf "Safe to push to trigger CI.\n"

_ci-cleanup:
	@printf "\n$(CYAN)Cleaning up test database...$(RESET)\n"
	@cd $(ROOT_DIR) && $(COMPOSE_DB_DEV) stop mysql-test 2>/dev/null || true

verify-gate: ## [quality] Run verify-test-gate.sh + its bash harness (Phase B B4)
	@printf "$(CYAN)==> Running verify-test-gate.sh harness...$(RESET)\n"
	@bash $(ROOT_DIR)/scripts/tests/test-verify-test-gate.sh && \
		printf "$(GREEN)✓ verify-test-gate harness green$(RESET)\n" || \
		(printf "$(RED)✗ verify-test-gate harness failed$(RESET)\n" && exit 1)
	@printf "$(CYAN)==> Running verify-test-gate.sh on current branch...$(RESET)\n"
	@bash $(ROOT_DIR)/scripts/verify-test-gate.sh && \
		printf "$(GREEN)✓ verify-test-gate clean on current branch$(RESET)\n" || \
		(printf "$(RED)✗ verify-test-gate rejected current branch$(RESET)\n" && exit 1)

# Configuration for preflight validation
#
# The prod docker-compose.yml routes traefik by `Host(`sysndd.dbmr.unibe.ch`)`
# ONLY — the dev override file relaxes it to also accept `localhost` /
# `127.0.0.1`, but preflight uses the prod compose file without the override,
# so we MUST curl with the real prod Host header (via -H) or traefik returns
# 404. PREFLIGHT_HOST_HEADER is the Host header curl will send; override it
# with `make preflight PREFLIGHT_HOST_HEADER=example.com` if needed.
PREFLIGHT_TIMEOUT := 120
PREFLIGHT_HEALTH_ENDPOINT := http://localhost/api/health/ready
PREFLIGHT_HOST_HEADER := sysndd.dbmr.unibe.ch

preflight: check-docker ## [quality] Run production preflight validation
	@printf "$(CYAN)==> Running production preflight validation...$(RESET)\n"
	@printf "\n$(CYAN)[1/4] Building production API image...$(RESET)\n"
	@docker build -t sysndd-api:preflight -f $(ROOT_DIR)/api/Dockerfile $(ROOT_DIR)/api/ || \
		(printf "$(RED)Build failed$(RESET)\n" && exit 1)
	@printf "$(GREEN)Build complete$(RESET)\n"
	@printf "\n$(CYAN)[2/4] Starting production containers...$(RESET)\n"
	@cd $(ROOT_DIR) && docker compose -f docker-compose.yml up -d --build || \
		(printf "$(RED)Container startup failed$(RESET)\n" && exit 1)
	@printf "$(GREEN)Containers started$(RESET)\n"
	@printf "\n$(CYAN)[3/4] Waiting for health check (timeout: $(PREFLIGHT_TIMEOUT)s)...$(RESET)\n"
	@SECONDS_ELAPSED=0; HEALTH_OK=0; \
	while [ $$SECONDS_ELAPSED -lt $(PREFLIGHT_TIMEOUT) ]; do \
		if RESPONSE=$$(curl -sf -H "Host: $(PREFLIGHT_HOST_HEADER)" $(PREFLIGHT_HEALTH_ENDPOINT) 2>/dev/null); then \
			printf "$(GREEN)Health check passed!$(RESET)\n"; \
			printf "Response: $$RESPONSE\n"; \
			HEALTH_OK=1; \
			break; \
		fi; \
		printf "."; \
		sleep 2; \
		SECONDS_ELAPSED=$$((SECONDS_ELAPSED+2)); \
	done; \
	if [ "$$HEALTH_OK" -eq 0 ]; then \
		printf "\n$(RED)Health check timed out after $(PREFLIGHT_TIMEOUT)s$(RESET)\n"; \
		printf "\n$(YELLOW)Last 50 lines of API logs:$(RESET)\n"; \
		docker compose -f docker-compose.yml logs api --tail=50; \
		printf "\n$(CYAN)[4/4] Cleanup (after failure)...$(RESET)\n"; \
		docker compose -f docker-compose.yml down; \
		printf "\n$(RED)PREFLIGHT FAILED$(RESET)\n"; \
		exit 1; \
	fi
	@printf "\n$(CYAN)[4/4] Cleanup...$(RESET)\n"
	@cd $(ROOT_DIR) && docker compose -f docker-compose.yml down
	@printf "\n$(GREEN)========================================$(RESET)\n"
	@printf "$(GREEN)       PREFLIGHT PASSED                 $(RESET)\n"
	@printf "$(GREEN)========================================$(RESET)\n"
	@printf "\n$(CYAN)Production Docker build validated:$(RESET)\n"
	@printf "  - API image builds successfully\n"
	@printf "  - Containers start without errors\n"
	@printf "  - /api/health/ready returns 200\n"
	@printf "  - Database connectivity verified\n"

# =============================================================================
# Docker Targets
# =============================================================================
# Compose file sets:
#   Production:  docker-compose.yml
#   Development: docker-compose.yml + docker-compose.override.yml (auto-loaded)
#   Full dev:    docker-compose.yml + docker-compose.override.yml + docker-compose.dev.yml
COMPOSE_DEV := docker compose -f docker-compose.yml -f docker-compose.override.yml -f docker-compose.dev.yml
COMPOSE_DB_DEV := docker compose -p sysndd -f docker-compose.dev.yml

docker-build: check-docker ## [docker] Build API Docker image
	@printf "$(CYAN)==> Building API Docker image...$(RESET)\n"
	@cd $(ROOT_DIR) && docker build -t sysndd-api api && \
		printf "$(GREEN)✓ docker-build complete$(RESET)\n" || \
		(printf "$(RED)✗ docker-build failed$(RESET)\n" && exit 1)

docker-up: check-docker ## [docker] Start production containers (no dev overrides)
	@printf "$(CYAN)==> Starting production containers...$(RESET)\n"
	@cd $(ROOT_DIR) && docker compose -f docker-compose.yml up -d --build && \
		printf "$(GREEN)✓ docker-up complete$(RESET)\n" || \
		(printf "$(RED)✗ docker-up failed$(RESET)\n" && exit 1)

docker-down: check-docker ## [docker] Stop all containers (dev + production)
	@printf "$(CYAN)==> Stopping all containers...$(RESET)\n"
	@cd $(ROOT_DIR) && $(COMPOSE_DEV) down 2>/dev/null; \
		docker compose -f docker-compose.yml down 2>/dev/null; \
		printf "$(GREEN)✓ docker-down complete$(RESET)\n"

docker-dev: check-docker ## [docker] Start full dev stack (app + api + db + dev databases)
	@printf "$(CYAN)==> Starting full Docker dev stack...$(RESET)\n"
	@cd $(ROOT_DIR) && $(COMPOSE_DEV) up -d && \
		printf "$(GREEN)✓ Containers started$(RESET)\n" || \
		(printf "$(RED)✗ docker-dev failed$(RESET)\n" && exit 1)
	@printf "\n$(CYAN)Services:$(RESET)\n"
	@printf "  App:       http://localhost       (Vite dev server via Traefik)\n"
	@printf "  App direct: http://localhost:5173  (bypass Traefik)\n"
	@printf "  API:       http://localhost/api    (R/Plumber via Traefik)\n"
	@printf "  API direct: http://localhost:7778  (bypass Traefik)\n"
	@printf "  Traefik:   http://localhost:8090   (dashboard)\n"
	@printf "  MySQL dev: localhost:7654\n"
	@printf "  MySQL test: localhost:7655\n"
	@printf "\n$(CYAN)Useful commands:$(RESET)\n"
	@printf "  make docker-logs       View container logs\n"
	@printf "  make docker-status     Show container status\n"
	@printf "  make watch-app         Enable Compose Watch for hot-reload\n"
	@printf "  make dev-rebuild       Rebuild images (after Dockerfile changes)\n"
	@printf "  make db-restore-latest Restore latest DB backup + recreate views\n"
	@printf "  make db-views-rebuild  Replay R-script views (post-restore fix)\n"
	@printf "  make cache-clear       Wipe API memoise cache\n"
	@printf "  make docker-down       Stop everything\n"

dev-rebuild: check-docker ## [docker] Rebuild app+api images and restart dev stack (use after Dockerfile changes)
	@printf "$(CYAN)==> Rebuilding images and starting dev stack...$(RESET)\n"
	@cd $(ROOT_DIR) && $(COMPOSE_DEV) up -d --build && \
		printf "$(GREEN)✓ Containers rebuilt and started$(RESET)\n" || \
		(printf "$(RED)✗ dev-rebuild failed$(RESET)\n" && exit 1)
	@printf "$(YELLOW)Note: stale images caused real bugs in the past. Use this target whenever Dockerfile.dev or Dockerfile changes.$(RESET)\n"

db-restore-latest: check-docker ## [docker] Restore newest DB dump from sysndd_mysql_backup volume + recreate views
	@printf "$(CYAN)==> Restoring latest DB backup...$(RESET)\n"
	@docker ps --format '{{.Names}}' | grep -q '^sysndd_mysql$$' || \
		(printf "$(RED)✗ sysndd_mysql container not running. Run 'make dev' first.$(RESET)\n" && exit 1)
	@LATEST=$$(docker run --rm -v sysndd_mysql_backup:/data alpine sh -c \
		'ls -t /data/*.sysndd_db.sql.gz 2>/dev/null | head -1'); \
		[ -n "$$LATEST" ] || \
		(printf "$(RED)✗ No backups found in sysndd_mysql_backup volume$(RESET)\n" && exit 1); \
		printf "  Using: $$LATEST\n"; \
		docker run --rm -v sysndd_mysql_backup:/data alpine sh -c "gzip -dc $$LATEST" | \
			docker exec -i sysndd_mysql sh -c 'mysql -u "$$MYSQL_USER" -p"$$MYSQL_PASSWORD" "$$MYSQL_DATABASE"' 2>&1 | \
			grep -vE "Using a password|SUPER or SET_ANY_DEFINER" >&2 || true
	@printf "$(GREEN)✓ Backup restored$(RESET)\n"
	@$(MAKE) db-views-rebuild

db-views-rebuild: check-docker ## [docker] Re-extract view DDL from db/C_Rcommands_set-table-connections.R and replay (fixes broken DEFINER views post-restore)
	@printf "$(CYAN)==> Rebuilding views from R script (DEFINER-stripped)...$(RESET)\n"
	@docker ps --format '{{.Names}}' | grep -q '^sysndd_mysql$$' || \
		(printf "$(RED)✗ sysndd_mysql container not running.$(RESET)\n" && exit 1)
	@python3 -c '\
import re, sys; \
content = open("db/C_Rcommands_set-table-connections.R").read(); \
matches = re.findall(r"dbSendQuery\(sysndd_db,\s*\"(CREATE OR REPLACE VIEW[^\"]*?)\"\)", content, re.DOTALL); \
[print(m.strip() + ";") for m in matches]; \
sys.stderr.write(f"-- Extracted {len(matches)} view definitions\n")' > /tmp/sysndd-views.sql 2>&1
	@cat /tmp/sysndd-views.sql | docker exec -i sysndd_mysql sh -c \
		'mysql -u "$$MYSQL_USER" -p"$$MYSQL_PASSWORD" "$$MYSQL_DATABASE"' 2>&1 | \
		grep -vE "Using a password" >&2 || true
	@rm -f /tmp/sysndd-views.sql
	@printf "$(GREEN)✓ Views rebuilt$(RESET)\n"
	@$(MAKE) cache-clear

cache-clear: ## [docker] Wipe API memoise cache (forces cached endpoints to recompute)
	@printf "$(CYAN)==> Wiping API memoise cache...$(RESET)\n"
	@docker ps --format '{{.Names}}' | grep -q '^sysndd-api-1$$' || \
		(printf "$(YELLOW)Warning: sysndd-api-1 not running; cache wipe is a no-op$(RESET)\n" && exit 0)
	@docker exec sysndd-api-1 sh -c 'find /app/cache -type f -name "*.rds" -delete' && \
		printf "$(GREEN)✓ Cache wiped (next stats request will recompute)$(RESET)\n" || \
		(printf "$(RED)✗ cache-clear failed$(RESET)\n" && exit 1)

docker-dev-db: check-docker ## [docker] Start only dev databases (for local API/app development)
	@printf "$(CYAN)==> Starting development databases only...$(RESET)\n"
	@cd $(ROOT_DIR) && $(COMPOSE_DB_DEV) up -d && \
		printf "$(GREEN)✓ Databases started$(RESET)\n" || \
		(printf "$(RED)✗ docker-dev-db failed$(RESET)\n" && exit 1)
	@printf "\n$(CYAN)Database ports:$(RESET)\n"
	@printf "  MySQL dev:  localhost:7654\n"
	@printf "  MySQL test: localhost:7655\n"
	@printf "\n$(CYAN)Next steps:$(RESET)\n"
	@printf "  Start API:      cd api && Rscript start_sysndd_api.R\n"
	@printf "  Start frontend: make serve-app\n"

docker-logs: check-docker ## [docker] View container logs (follow mode)
	@cd $(ROOT_DIR) && $(COMPOSE_DEV) logs -f --tail=50 2>/dev/null || \
		docker compose logs -f --tail=50

docker-status: check-docker ## [docker] Show container status and ports
	@cd $(ROOT_DIR) && $(COMPOSE_DEV) ps 2>/dev/null || \
		docker compose ps

# =============================================================================
# Playwright E2E Stack (v11.1 Wave 0)
# =============================================================================
# Brings up the Playwright-only stack via the docker-compose.playwright.yml
# overlay. Isolated from `make dev` (different compose project name + volume
# names). Seeds Playwright test users into the DB AFTER migrations have run.
#
# Notes:
#   - Uses compose project name `playwright` so it does not collide with
#     `make dev` (project `sysndd`).
#   - Skips `mysql-cron-backup` and `worker` services (not needed for the
#     deep-flow specs; saves ~30s of startup).
#   - Seeds .env and api/config.yml from their committed templates if missing,
#     mirroring scripts/ci-smoke.sh behavior.
#   - Test-user seeding runs AFTER migrations because the API startup is what
#     applies migrations (the `user` table is created mid-startup, not at
#     MySQL init). We wait for /api/health/ready before sourcing the fixture.

COMPOSE_PLAYWRIGHT := docker compose -p playwright -f docker-compose.yml -f docker-compose.playwright.yml
PLAYWRIGHT_DB_USER ?= playwright
PLAYWRIGHT_DB_PASSWORD ?= playwright_pw
PLAYWRIGHT_DB_ROOT_PASSWORD ?= playwright_root_pw
PLAYWRIGHT_DB_NAME ?= sysndd_db
PLAYWRIGHT_API_PASSWORD ?= playwright_api_password
PLAYWRIGHT_HEALTH_TIMEOUT ?= 240
PLAYWRIGHT_HEALTH_ENDPOINT ?= http://localhost/api/health/ready

# Env vars exported to the compose invocations. The base compose file
# interpolates these at parse time, so they MUST be set before any
# `docker compose -f docker-compose.yml ...` invocation.
PLAYWRIGHT_ENV := \
	MYSQL_DATABASE=$(PLAYWRIGHT_DB_NAME) \
	MYSQL_USER=$(PLAYWRIGHT_DB_USER) \
	MYSQL_PASSWORD=$(PLAYWRIGHT_DB_PASSWORD) \
	MYSQL_ROOT_PASSWORD=$(PLAYWRIGHT_DB_ROOT_PASSWORD) \
	PASSWORD=$(PLAYWRIGHT_API_PASSWORD) \
	SMTP_PASSWORD=playwright_smtp \
	OMIM_DOWNLOAD_KEY=playwright_omim \
	CORS_ALLOWED_ORIGINS=http://localhost \
	CACHE_VERSION=2

_playwright-seed-templates:
	@# Seed .env from template if missing — needed because docker-compose.yml
	@# interpolates ${MYSQL_*}, ${PASSWORD}, ${OMIM_DOWNLOAD_KEY} at parse time.
	@# The PLAYWRIGHT_ENV exports below also set these inline, so the .env file
	@# only matters as a fallback for compose's own variable substitution.
	@if [ ! -f $(ROOT_DIR)/.env ]; then \
		printf "$(YELLOW)⚠ Seeding .env from .env.example$(RESET)\n"; \
		cp $(ROOT_DIR)/.env.example $(ROOT_DIR)/.env; \
	fi
	@# Swap in api/config.yml.playwright as api/config.yml so the API container
	@# connects to the playwright DB with the credentials in PLAYWRIGHT_ENV.
	@# Preserve any existing dev config to api/config.yml.devbackup. Restore
	@# happens via `make playwright-stack-down`.
	@if [ -f $(ROOT_DIR)/api/config.yml ] && \
	   ! cmp -s $(ROOT_DIR)/api/config.yml $(ROOT_DIR)/api/config.yml.playwright && \
	   [ ! -f $(ROOT_DIR)/api/config.yml.devbackup ]; then \
		printf "$(YELLOW)⚠ Backing up api/config.yml to api/config.yml.devbackup (will be restored on playwright-stack-down)$(RESET)\n"; \
		cp $(ROOT_DIR)/api/config.yml $(ROOT_DIR)/api/config.yml.devbackup; \
	fi
	@cp $(ROOT_DIR)/api/config.yml.playwright $(ROOT_DIR)/api/config.yml
	@printf "$(GREEN)✓ Active api/config.yml is the Playwright config$(RESET)\n"

_playwright-seed-users:
	@printf "$(CYAN)==> Seeding Playwright test users...$(RESET)\n"
	@cd $(ROOT_DIR) && $(PLAYWRIGHT_ENV) $(COMPOSE_PLAYWRIGHT) exec -T mysql \
		mysql -u root -p$(PLAYWRIGHT_DB_ROOT_PASSWORD) $(PLAYWRIGHT_DB_NAME) \
		< $(ROOT_DIR)/db/fixtures/playwright_users.sql && \
		printf "$(GREEN)✓ Test users seeded$(RESET)\n" || \
		(printf "$(RED)✗ Failed to seed test users$(RESET)\n" && exit 1)

playwright-stack: check-docker _playwright-seed-templates ## [test] Bring up Playwright E2E stack (CI-only fixtures)
	@printf "$(CYAN)==> Bringing up Playwright E2E stack...$(RESET)\n"
	@cd $(ROOT_DIR) && $(PLAYWRIGHT_ENV) $(COMPOSE_PLAYWRIGHT) up -d --wait \
		traefik mysql mailpit api app && \
		printf "$(GREEN)✓ Playwright stack started$(RESET)\n" || \
		(printf "$(RED)✗ playwright-stack up failed$(RESET)\n" && exit 1)
	@printf "$(CYAN)Waiting for /api/health/ready (timeout: $(PLAYWRIGHT_HEALTH_TIMEOUT)s)...$(RESET)\n"
	@SECONDS_ELAPSED=0; HEALTH_OK=0; \
	while [ $$SECONDS_ELAPSED -lt $(PLAYWRIGHT_HEALTH_TIMEOUT) ]; do \
		if curl -sf -H "Host: localhost" $(PLAYWRIGHT_HEALTH_ENDPOINT) >/dev/null 2>&1; then \
			HEALTH_OK=1; break; \
		fi; \
		printf "."; sleep 2; SECONDS_ELAPSED=$$((SECONDS_ELAPSED+2)); \
	done; \
	if [ "$$HEALTH_OK" -eq 0 ]; then \
		printf "\n$(RED)Health check timed out — Playwright stack failed to come up$(RESET)\n"; \
		printf "\n$(YELLOW)Last 50 lines of API logs:$(RESET)\n"; \
		$(PLAYWRIGHT_ENV) $(COMPOSE_PLAYWRIGHT) logs api --tail=50; \
		exit 1; \
	fi; \
	printf "\n$(GREEN)✓ API ready$(RESET)\n"
	@if [ -f $(ROOT_DIR)/db/fixtures/playwright_users.sql ]; then \
		$(MAKE) _playwright-seed-users; \
	else \
		printf "$(YELLOW)⚠ db/fixtures/playwright_users.sql missing — skipping user seed$(RESET)\n"; \
	fi
	@printf "\n$(CYAN)Playwright stack ready:$(RESET)\n"
	@printf "  App + API: http://localhost\n"
	@printf "  API direct: http://localhost/api\n"
	@printf "  Run tests: cd app && npx playwright test\n"
	@printf "  Tear down: make playwright-stack-down\n"

playwright-stack-down: check-docker ## [test] Tear down Playwright E2E stack and remove volumes
	@printf "$(CYAN)==> Tearing down Playwright E2E stack...$(RESET)\n"
	@cd $(ROOT_DIR) && $(PLAYWRIGHT_ENV) $(COMPOSE_PLAYWRIGHT) down -v && \
		printf "$(GREEN)✓ Playwright stack torn down$(RESET)\n" || \
		(printf "$(RED)✗ playwright-stack-down failed$(RESET)\n" && exit 1)
	@# Restore the dev's api/config.yml if a backup was taken at stack-up time
	@if [ -f $(ROOT_DIR)/api/config.yml.devbackup ]; then \
		printf "$(YELLOW)Restoring api/config.yml from api/config.yml.devbackup$(RESET)\n"; \
		mv $(ROOT_DIR)/api/config.yml.devbackup $(ROOT_DIR)/api/config.yml; \
		printf "$(GREEN)✓ api/config.yml restored$(RESET)\n"; \
	fi

playwright-stack-logs: check-docker ## [test] Tail Playwright E2E stack logs
	@cd $(ROOT_DIR) && $(PLAYWRIGHT_ENV) $(COMPOSE_PLAYWRIGHT) logs -f --tail=50

# =============================================================================
# Developer Environment (Phase A7)
# =============================================================================
# One-command bootstrap, environment verification, and worktree scaffolding.
# See documentation/08-development.qmd for the human-facing guide.

install-dev: check-r check-npm ## [env] Idempotent bootstrap: install API + frontend dependencies
	@printf "$(CYAN)==> Bootstrapping developer environment...$(RESET)\n"
	@printf "\n$(CYAN)[1/2] Installing R API dependencies...$(RESET)\n"
	@$(MAKE) install-api
	@printf "\n$(CYAN)[2/2] Installing frontend dependencies...$(RESET)\n"
	@$(MAKE) install-app
	@printf "\n$(GREEN)✓ install-dev complete$(RESET)\n"
	@printf "\n$(CYAN)Next steps:$(RESET)\n"
	@printf "  make doctor   Verify the environment is healthy\n"
	@printf "  make dev      Start the full Docker dev stack\n"

doctor: ## [env] Verify local environment is healthy (docker, git, node, R, renv)
	@printf "$(CYAN)==> Running environment checks...$(RESET)\n"
	@set +e; \
	FAIL=0; \
	printf "\n$(CYAN)[1/5] Docker reachable (soft check)...$(RESET)\n"; \
	if docker info > /dev/null 2>&1; then \
		printf "$(GREEN)✓ Docker is reachable$(RESET)\n"; \
	elif command -v docker > /dev/null 2>&1; then \
		printf "$(YELLOW)⚠ docker CLI installed but daemon not reachable$(RESET)\n"; \
		printf "$(YELLOW)  (non-fatal: docker is only needed for 'make dev' and 'make ci-local'.$(RESET)\n"; \
		printf "$(YELLOW)   Start Docker Desktop / colima to use those targets.)$(RESET)\n"; \
	else \
		printf "$(YELLOW)⚠ docker CLI not installed$(RESET)\n"; \
		printf "$(YELLOW)  (non-fatal: needed for 'make dev' and 'make ci-local'.)$(RESET)\n"; \
	fi; \
	printf "\n$(CYAN)[2/5] Git version >= 2.5 (worktree support)...$(RESET)\n"; \
	if command -v git > /dev/null 2>&1; then \
		GIT_VERSION=$$(git --version | awk '{print $$3}'); \
		GIT_MAJOR=$$(printf '%s' "$$GIT_VERSION" | awk -F. '{print $$1}'); \
		GIT_MINOR=$$(printf '%s' "$$GIT_VERSION" | awk -F. '{print $$2}'); \
		if [ "$$GIT_MAJOR" -gt 2 ] || { [ "$$GIT_MAJOR" -eq 2 ] && [ "$$GIT_MINOR" -ge 5 ]; }; then \
			printf "$(GREEN)✓ git %s$(RESET)\n" "$$GIT_VERSION"; \
		else \
			printf "$(RED)✗ git %s is too old (need >= 2.5 for worktrees)$(RESET)\n" "$$GIT_VERSION"; \
			FAIL=1; \
		fi; \
	else \
		printf "$(RED)✗ git is not installed$(RESET)\n"; \
		FAIL=1; \
	fi; \
	printf "\n$(CYAN)[3/5] Node major matches app/.nvmrc...$(RESET)\n"; \
	if [ ! -f $(ROOT_DIR)/app/.nvmrc ]; then \
		printf "$(RED)✗ app/.nvmrc is missing$(RESET)\n"; \
		FAIL=1; \
	elif ! command -v node > /dev/null 2>&1; then \
		printf "$(RED)✗ node is not installed$(RESET)\n"; \
		FAIL=1; \
	else \
		EXPECTED_NODE=$$(tr -d ' \t\r\n' < $(ROOT_DIR)/app/.nvmrc); \
		ACTUAL_NODE=$$(node --version | sed 's/^v//' | awk -F. '{print $$1}'); \
		if [ "$$ACTUAL_NODE" = "$$EXPECTED_NODE" ]; then \
			printf "$(GREEN)✓ node v%s matches .nvmrc ($$EXPECTED_NODE)$(RESET)\n" "$$ACTUAL_NODE"; \
		else \
			printf "$(RED)✗ node major v%s does not match app/.nvmrc (%s)$(RESET)\n" "$$ACTUAL_NODE" "$$EXPECTED_NODE"; \
			FAIL=1; \
		fi; \
	fi; \
	printf "\n$(CYAN)[4/5] R is callable...$(RESET)\n"; \
	if command -v Rscript > /dev/null 2>&1; then \
		R_VERSION=$$(Rscript -e 'cat(as.character(getRversion()))' 2>/dev/null); \
		if [ -n "$$R_VERSION" ]; then \
			printf "$(GREEN)✓ R %s$(RESET)\n" "$$R_VERSION"; \
		else \
			printf "$(RED)✗ Rscript is installed but failed to report a version$(RESET)\n"; \
			FAIL=1; \
		fi; \
	else \
		printf "$(RED)✗ R / Rscript is not installed$(RESET)\n"; \
		FAIL=1; \
	fi; \
	printf "\n$(CYAN)[5/5] Dev packages importable...$(RESET)\n"; \
	if ! command -v Rscript > /dev/null 2>&1; then \
		printf "$(RED)✗ Cannot check dev packages — Rscript not available$(RESET)\n"; \
		FAIL=1; \
	else \
		RENV_OUTPUT=$$(cd $(ROOT_DIR)/api && Rscript -e 'tryCatch({ suppressPackageStartupMessages({ library(lintr); library(styler); library(testthat); library(covr); library(httptest2); library(callr); library(mockery) }); cat("dev-packages-ok") }, error = function(e) cat("ERROR: ", conditionMessage(e), sep = ""))' 2>&1 | tail -n 1); \
		if printf '%s' "$$RENV_OUTPUT" | grep -q "dev-packages-ok"; then \
			printf "$(GREEN)✓ dev packages (lintr, styler, testthat, covr, httptest2, callr, mockery) importable$(RESET)\n"; \
		else \
			printf "$(RED)✗ dev packages not importable$(RESET)\n"; \
			printf "$(YELLOW)  Details: %s$(RESET)\n" "$$RENV_OUTPUT"; \
			printf "$(YELLOW)  Run 'make install-dev' to restore the library and retry$(RESET)\n"; \
			FAIL=1; \
		fi; \
	fi; \
	printf "\n"; \
	if [ "$$FAIL" -ne 0 ]; then \
		printf "$(RED)✗ doctor found problems — fix the items above and re-run$(RESET)\n"; \
		exit 1; \
	fi; \
	printf "Environment healthy\n"

# NAME variable used by worktree-setup; default empty so --warn-undefined-variables stays quiet
NAME ?=

worktree-setup: ## [env] Create a parallel worktree. Usage: make worktree-setup NAME=phase-a/my-unit
	@if [ -z "$(NAME)" ]; then \
		printf "$(RED)ERROR: NAME is required$(RESET)\n"; \
		printf "Usage: make worktree-setup NAME=phase-a/my-unit\n"; \
		exit 1; \
	fi
	@WORKTREE_PATH="$(ROOT_DIR)/worktrees/$(NAME)"; \
	BRANCH="v11.0/$(NAME)"; \
	if [ -e "$$WORKTREE_PATH" ]; then \
		printf "$(RED)ERROR: worktree path already exists: %s$(RESET)\n" "$$WORKTREE_PATH"; \
		printf "Remove it first (git worktree remove) before recreating.\n"; \
		exit 1; \
	fi; \
	if git -C $(ROOT_DIR) show-ref --verify --quiet "refs/heads/$$BRANCH"; then \
		printf "$(RED)ERROR: branch already exists: %s$(RESET)\n" "$$BRANCH"; \
		exit 1; \
	fi; \
	mkdir -p "$$(dirname "$$WORKTREE_PATH")"; \
	printf "$(CYAN)==> Creating worktree at %s on branch %s...$(RESET)\n" "$$WORKTREE_PATH" "$$BRANCH"; \
	git -C $(ROOT_DIR) worktree add "$$WORKTREE_PATH" -b "$$BRANCH" master && \
		printf "$(GREEN)✓ worktree-setup complete$(RESET)\n" || \
		(printf "$(RED)✗ worktree-setup failed$(RESET)\n" && exit 1); \
	printf "\n$(CYAN)Next steps:$(RESET)\n"; \
	printf "  cd %s\n" "$$WORKTREE_PATH"; \
	printf "  make install-dev\n"; \
	printf "  make doctor\n"

# =============================================================================
# Worktree Cleanup (Phase A6)
# =============================================================================
# Canonical git cleanup for parallel worktrees. Idempotent — safe to run on a
# clean tree. Removes references to worktrees whose directories have been
# deleted (e.g. after `rm -rf worktrees/phase-a/foo` without `git worktree
# remove`), then prints the remaining list so you can see what's left.

worktree-prune: ## [env] Prune stale worktree references and list remaining worktrees
	@printf "$(CYAN)==> Pruning stale worktree references...$(RESET)\n"
	@git -C $(ROOT_DIR) worktree prune -v && \
		printf "$(GREEN)✓ worktree prune complete$(RESET)\n" || \
		(printf "$(RED)✗ worktree prune failed$(RESET)\n" && exit 1)
	@printf "\n$(CYAN)Remaining worktrees:$(RESET)\n"
	@git -C $(ROOT_DIR) worktree list

# =============================================================================
# Phase B B2: fixture refresh
# =============================================================================
# `make refresh-fixtures` records fresh httptest2 captures of the live NCBI
# eUtils PubMed API and the PubTator3 API into
# `api/tests/testthat/fixtures/{pubmed,pubtator}/`.
#
# - This target is DEVELOPER-ONLY. It is intentionally NOT invoked from
#   `make ci-local`, `make pre-commit`, or any CI job. Fixtures are committed
#   artefacts; we never let CI silently rewrite them by hitting the upstream
#   APIs.
# - The capture runs inside the `sysndd-api:latest` Docker image because the
#   Ubuntu questing host cannot install `httr2` + `httptest2` dependencies
#   cleanly (see CLAUDE.md "Host-Env Workaround"). The image already has
#   them; we bind-mount the fixtures directory so writes land in-tree.
# - The capture script is `api/scripts/capture-external-fixtures.R`. See
#   `api/tests/testthat/fixtures/README.md` for the full inventory and the
#   exact request URLs each fixture corresponds to.

# Image used for fixture capture. Override with FIXTURE_IMAGE=... to pin a
# specific tag (default: whatever the local `sysndd-api` prod image tag is).
FIXTURE_IMAGE ?= sysndd-api:latest

refresh-fixtures: check-docker ## [test] Refresh live PubMed/PubTator httptest2 fixtures (dev-only, NOT run in CI)
	@printf "$(CYAN)==> Refreshing external-API test fixtures (Phase B B2)$(RESET)\n"
	@printf "$(YELLOW)This hits the live NCBI PubMed and PubTator APIs.$(RESET)\n"
	@printf "$(YELLOW)It is intentionally NOT part of make ci-local.$(RESET)\n"
	@printf "\n$(CYAN)Image:$(RESET) $(FIXTURE_IMAGE)\n"
	@printf "$(CYAN)Target:$(RESET) $(ROOT_DIR)/api/tests/testthat/fixtures/{pubmed,pubtator}/\n\n"
	@docker run --rm --network=host \
		-v "$(ROOT_DIR)/api/tests/testthat/fixtures:/fixtures" \
		-v "$(ROOT_DIR)/api/scripts:/scripts:ro" \
		$(FIXTURE_IMAGE) \
		Rscript /scripts/capture-external-fixtures.R /fixtures && \
		printf "\n$(GREEN)✓ refresh-fixtures complete$(RESET)\n" || \
		(printf "\n$(RED)✗ refresh-fixtures failed$(RESET)\n" && exit 1)
	@printf "\n$(CYAN)Next steps:$(RESET)\n"
	@printf "  git status api/tests/testthat/fixtures/\n"
	@printf "  git diff   api/tests/testthat/fixtures/README.md   # update inventory if fixture set changed\n"
