.PHONY: mcp-local-up mcp-local-down

# Standalone MCP sidecar of this checkout on a restored dump (docker-compose.mcp-local.yml).
# MCP_LOCAL_DUMP: a *.sysndd_db.sql.gz dump; default: the newest one in the
# sysndd_mysql_backup volume, copied into MCP_LOCAL_SECRETS.
MCP_LOCAL_SECRETS ?= $(ROOT_DIR)/secrets/mcp-local
MCP_LOCAL_PORT ?= 8787
COMPOSE_MCP_LOCAL = MCP_LOCAL_SECRETS="$(MCP_LOCAL_SECRETS)" \
	MCP_LOCAL_ROOT_PASSWORD="$$(cat "$(MCP_LOCAL_SECRETS)/admin/root-password" 2>/dev/null)" MCP_LOCAL_DUMP="$${MCP_LOCAL_DUMP:-$(MCP_LOCAL_SECRETS)/admin/sysndd_db.sql.gz}" \
	MCP_LOCAL_PORT="$(MCP_LOCAL_PORT)" docker compose -p sysndd-mcp-local -f $(ROOT_DIR)/docker-compose.mcp-local.yml

mcp-local-up: check-docker ## [docker] Run this checkout's MCP sidecar on a restored dump at 127.0.0.1:$(MCP_LOCAL_PORT)
	@set -eu; umask 077; mkdir -p "$(MCP_LOCAL_SECRETS)/admin" "$(MCP_LOCAL_SECRETS)/reader"; \
	chmod 0700 "$(MCP_LOCAL_SECRETS)" "$(MCP_LOCAL_SECRETS)/admin" "$(MCP_LOCAL_SECRETS)/reader"; \
	[ -s "$(MCP_LOCAL_SECRETS)/admin/root-password" ] || openssl rand -hex 24 | tr -d '\n' > "$(MCP_LOCAL_SECRETS)/admin/root-password"; \
	if [ -z "$${MCP_LOCAL_DUMP:-}" ] && [ ! -s "$(MCP_LOCAL_SECRETS)/admin/sysndd_db.sql.gz" ]; then \
		docker run --rm -v sysndd_mysql_backup:/data:ro alpine cat /data/latest.sysndd_db.sql.gz \
			> "$(MCP_LOCAL_SECRETS)/admin/sysndd_db.sql.gz"; \
		chmod 0644 "$(MCP_LOCAL_SECRETS)/admin/sysndd_db.sql.gz"; \
	fi; \
	$(COMPOSE_MCP_LOCAL) up -d --wait mcp
	@printf "$(GREEN)✓ MCP sidecar at http://127.0.0.1:$(MCP_LOCAL_PORT)/mcp (health: /health)$(RESET)\n"

mcp-local-down: check-docker ## [docker] Stop the local MCP sidecar (add MCP_LOCAL_PURGE=1 to drop the restored DB)
	@$(COMPOSE_MCP_LOCAL) down $${MCP_LOCAL_PURGE:+-v}
