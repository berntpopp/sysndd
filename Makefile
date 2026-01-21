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
.PHONY: help check-r check-npm check-docker install-api install-app dev docker-build docker-up docker-down

# =============================================================================
# Help Target (Self-documenting)
# =============================================================================
help: ## Show this help message
	@printf "SysNDD Development Commands\n\n"
	@printf "$(CYAN)Development:$(RESET)\n"
	@grep -E '^[a-zA-Z_-]+:.*?## \[dev\]' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## \\[dev\\] "}; {printf "  \033[0;36m%-20s\033[0m %s\n", $$1, $$2}'
	@printf "\n$(CYAN)Docker:$(RESET)\n"
	@grep -E '^[a-zA-Z_-]+:.*?## \[docker\]' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## \\[docker\\] "}; {printf "  \033[0;36m%-20s\033[0m %s\n", $$1, $$2}'

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
	@cd /mnt/c/development/sysndd/api && R -e "renv::restore(prompt = FALSE)" && \
		printf "$(GREEN)✓ install-api complete$(RESET)\n" || \
		(printf "$(RED)✗ install-api failed$(RESET)\n" && exit 1)

install-app: check-npm ## [dev] Install frontend dependencies with npm install
	@printf "$(CYAN)==> Installing frontend dependencies...$(RESET)\n"
	@cd /mnt/c/development/sysndd/app && npm install && \
		printf "$(GREEN)✓ install-app complete$(RESET)\n" || \
		(printf "$(RED)✗ install-app failed$(RESET)\n" && exit 1)

dev: check-docker ## [dev] Start development database containers
	@printf "$(CYAN)==> Starting development databases...$(RESET)\n"
	@docker compose -f /mnt/c/development/sysndd/docker-compose.dev.yml up -d && \
		printf "$(GREEN)✓ Databases started on ports 7654 (dev) and 7655 (test)$(RESET)\n" || \
		(printf "$(RED)✗ dev failed$(RESET)\n" && exit 1)
	@printf "\n$(CYAN)Next steps:$(RESET)\n"
	@printf "  Start API:      cd api && Rscript start_sysndd_api.R\n"
	@printf "  Start frontend: cd app && npm run serve\n"

# =============================================================================
# Docker Targets
# =============================================================================
docker-build: check-docker ## [docker] Build API Docker image
	@printf "$(CYAN)==> Building API Docker image...$(RESET)\n"
	@docker build -t sysndd-api /mnt/c/development/sysndd/api && \
		printf "$(GREEN)✓ docker-build complete$(RESET)\n" || \
		(printf "$(RED)✗ docker-build failed$(RESET)\n" && exit 1)

docker-up: check-docker ## [docker] Start all production containers
	@printf "$(CYAN)==> Starting production containers...$(RESET)\n"
	@docker compose -f /mnt/c/development/sysndd/docker-compose.yml up -d && \
		printf "$(GREEN)✓ docker-up complete$(RESET)\n" || \
		(printf "$(RED)✗ docker-up failed$(RESET)\n" && exit 1)

docker-down: check-docker ## [docker] Stop all containers
	@printf "$(CYAN)==> Stopping containers...$(RESET)\n"
	@docker compose -f /mnt/c/development/sysndd/docker-compose.yml down && \
		printf "$(GREEN)✓ docker-down complete$(RESET)\n" || \
		(printf "$(RED)✗ docker-down failed$(RESET)\n" && exit 1)
