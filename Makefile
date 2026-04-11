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
.PHONY: help check-r check-npm check-docker install-api install-app dev serve-app build-app watch-app test-api test-api-full coverage lint-api lint-app format-api format-app pre-commit ci-local _ci-cleanup preflight docker-build docker-up docker-down docker-dev docker-dev-db docker-logs docker-status install-dev doctor worktree-setup worktree-prune refresh-fixtures verify-gate

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
	@cd $(ROOT_DIR)/api && Rscript -e "testthat::test_dir('tests/testthat')" && \
		printf "$(GREEN)✓ test-api complete$(RESET)\n" || \
		(printf "$(RED)✗ test-api failed$(RESET)\n" && exit 1)

test-api-full: check-r ## [test] Run full R API test suite including slow tests
	@printf "$(CYAN)==> Running full R API test suite (including slow tests)...$(RESET)\n"
	@cd $(ROOT_DIR)/api && RUN_SLOW_TESTS=true Rscript -e "testthat::test_dir('tests/testthat')" && \
		printf "$(GREEN)✓ test-api-full complete$(RESET)\n" || \
		(printf "$(RED)✗ test-api-full failed$(RESET)\n" && exit 1)

coverage: check-r ## [test] Generate test coverage report with covr
	@printf "$(CYAN)==> Calculating test coverage...$(RESET)\n"
	@mkdir -p $(ROOT_DIR)/coverage
	@cd $(ROOT_DIR)/api && Rscript scripts/coverage.R && \
		printf "$(GREEN)✓ coverage complete$(RESET)\n" || \
		(printf "$(RED)✗ coverage failed$(RESET)\n" && exit 1)

# =============================================================================
# Linting Targets
# =============================================================================
lint-api: check-r ## [lint] Check R code with lintr + migration prefix check
	@printf "$(CYAN)==> Checking R code with lintr...$(RESET)\n"
	@cd $(ROOT_DIR)/api && Rscript scripts/lint-check.R && \
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
	@printf "\n$(CYAN)[3/3] Running R API tests...$(RESET)\n"
	@$(MAKE) test-api
	@printf "\n$(GREEN)✓ All pre-commit checks passed!$(RESET)\n"

ci-local: ## [quality] Run CI checks locally (lint + test with DB - mirrors GitHub Actions)
	@printf "$(CYAN)==> Running CI checks locally (mirrors GitHub Actions)...$(RESET)\n"
	@printf "\n$(CYAN)[1/5] Starting test database...$(RESET)\n"
	@cd $(ROOT_DIR) && docker compose -f docker-compose.dev.yml up -d mysql-test && \
		printf "$(GREEN)✓ Test database started$(RESET)\n" || \
		(printf "$(RED)✗ Failed to start test database$(RESET)\n" && exit 1)
	@printf "$(CYAN)Waiting for MySQL to be ready...$(RESET)\n"
	@SECONDS=0; \
	while [ $$SECONDS -lt 30 ]; do \
		if docker compose -f docker-compose.dev.yml exec -T mysql-test mysqladmin ping -h localhost -u bernt -pNur7DoofeFliegen. --silent 2>/dev/null; then \
			printf "$(GREEN)MySQL ready$(RESET)\n"; \
			break; \
		fi; \
		printf "."; \
		sleep 1; \
		SECONDS=$$((SECONDS+1)); \
	done
	@printf "\n$(CYAN)[2/5] Linting R code...$(RESET)\n"
	@$(MAKE) lint-api || ($(MAKE) _ci-cleanup && exit 1)
	@printf "\n$(CYAN)[3/5] Linting frontend code...$(RESET)\n"
	@$(MAKE) lint-app || ($(MAKE) _ci-cleanup && exit 1)
	@printf "\n$(CYAN)[4/5] Type-checking frontend...$(RESET)\n"
	@cd $(ROOT_DIR)/app && npm run type-check || ($(MAKE) _ci-cleanup && exit 1)
	@printf "$(GREEN)✓ Type check passed$(RESET)\n"
	@printf "\n$(CYAN)[5/5] Running R API tests (with database)...$(RESET)\n"
	@cd $(ROOT_DIR)/api && \
		MYSQL_HOST=127.0.0.1 MYSQL_PORT=7655 MYSQL_DATABASE=sysndd_db_test \
		MYSQL_USER=bernt MYSQL_PASSWORD=Nur7DoofeFliegen. \
		Rscript -e "testthat::test_dir('tests/testthat')" || \
		($(MAKE) _ci-cleanup && exit 1)
	@printf "$(GREEN)✓ Tests passed$(RESET)\n"
	@$(MAKE) _ci-cleanup
	@printf "\n$(GREEN)========================================$(RESET)\n"
	@printf "$(GREEN)       CI-LOCAL PASSED                  $(RESET)\n"
	@printf "$(GREEN)========================================$(RESET)\n"
	@printf "\nAll checks that run in GitHub Actions passed locally.\n"
	@printf "Safe to push to trigger CI.\n"

_ci-cleanup:
	@printf "\n$(CYAN)Cleaning up test database...$(RESET)\n"
	@cd $(ROOT_DIR) && docker compose -f docker-compose.dev.yml stop mysql-test 2>/dev/null || true

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
PREFLIGHT_TIMEOUT := 120
PREFLIGHT_HEALTH_ENDPOINT := http://localhost/api/health/ready

preflight: check-docker ## [quality] Run production preflight validation
	@printf "$(CYAN)==> Running production preflight validation...$(RESET)\n"
	@printf "\n$(CYAN)[1/4] Building production API image...$(RESET)\n"
	@docker build -t sysndd-api:preflight -f $(ROOT_DIR)/api/Dockerfile $(ROOT_DIR)/api/ || \
		(printf "$(RED)Build failed$(RESET)\n" && exit 1)
	@printf "$(GREEN)Build complete$(RESET)\n"
	@printf "\n$(CYAN)[2/4] Starting production containers...$(RESET)\n"
	@cd $(ROOT_DIR) && docker compose -f docker-compose.yml up -d || \
		(printf "$(RED)Container startup failed$(RESET)\n" && exit 1)
	@printf "$(GREEN)Containers started$(RESET)\n"
	@printf "\n$(CYAN)[3/4] Waiting for health check (timeout: $(PREFLIGHT_TIMEOUT)s)...$(RESET)\n"
	@SECONDS=0; \
	while [ $$SECONDS -lt $(PREFLIGHT_TIMEOUT) ]; do \
		RESPONSE=$$(curl -sf $(PREFLIGHT_HEALTH_ENDPOINT) 2>/dev/null); \
		if [ $$? -eq 0 ]; then \
			printf "$(GREEN)Health check passed!$(RESET)\n"; \
			printf "Response: $$RESPONSE\n"; \
			HEALTH_OK=1; \
			break; \
		fi; \
		printf "."; \
		sleep 2; \
		SECONDS=$$((SECONDS+2)); \
	done; \
	if [ -z "$$HEALTH_OK" ]; then \
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

docker-build: check-docker ## [docker] Build API Docker image
	@printf "$(CYAN)==> Building API Docker image...$(RESET)\n"
	@cd $(ROOT_DIR) && docker build -t sysndd-api api && \
		printf "$(GREEN)✓ docker-build complete$(RESET)\n" || \
		(printf "$(RED)✗ docker-build failed$(RESET)\n" && exit 1)

docker-up: check-docker ## [docker] Start production containers (no dev overrides)
	@printf "$(CYAN)==> Starting production containers...$(RESET)\n"
	@cd $(ROOT_DIR) && docker compose -f docker-compose.yml up -d && \
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
	@printf "  make docker-logs    View container logs\n"
	@printf "  make docker-status  Show container status\n"
	@printf "  make watch-app      Enable Compose Watch for hot-reload\n"
	@printf "  make docker-down    Stop everything\n"

docker-dev-db: check-docker ## [docker] Start only dev databases (for local API/app development)
	@printf "$(CYAN)==> Starting development databases only...$(RESET)\n"
	@cd $(ROOT_DIR) && docker compose -f docker-compose.dev.yml up -d && \
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
# Developer Environment (Phase A7)
# =============================================================================
# One-command bootstrap, environment verification, and worktree scaffolding.
# See docs/DEVELOPMENT.md for the human-facing guide.

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
#   Ubuntu questing host cannot install `httr2` + `httptest2` + `easyPubMed`
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
