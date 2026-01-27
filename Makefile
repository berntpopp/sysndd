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
.PHONY: help check-r check-npm check-docker install-api install-app dev serve-app build-app watch-app test-api test-api-full coverage lint-api lint-app format-api format-app pre-commit docker-build docker-up docker-down docker-dev docker-dev-db docker-logs docker-status

# =============================================================================
# Help Target (Self-documenting)
# =============================================================================
help: ## Show this help message
	@printf "SysNDD Development Commands\n\n"
	@printf "$(CYAN)Development:$(RESET)\n"
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
lint-api: check-r ## [lint] Check R code with lintr
	@printf "$(CYAN)==> Checking R code with lintr...$(RESET)\n"
	@cd $(ROOT_DIR)/api && Rscript scripts/lint-check.R && \
		printf "$(GREEN)✓ lint-api complete$(RESET)\n" || \
		(printf "$(RED)✗ lint-api failed$(RESET)\n" && exit 1)

lint-app: check-npm ## [lint] Check frontend code with ESLint
	@printf "$(CYAN)==> Checking frontend code with ESLint...$(RESET)\n"
	@cd $(ROOT_DIR)/app && npm run lint && \
		printf "$(GREEN)✓ lint-app complete$(RESET)\n" || \
		(printf "$(RED)✗ lint-app failed$(RESET)\n" && exit 1)

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
