.PHONY: verify-mcp-select-principal-live

MCP_SELECT_VERIFY_COMPOSE := $(ROOT_DIR)/docker-compose.mcp-select-verify.yml

define verify_mcp_select_assert_labels
	resources="$$(docker ps -aq --filter "label=com.docker.compose.project=$$project")"
	resources="$$resources $$(docker network ls -q --filter "label=com.docker.compose.project=$$project")"
	resources="$$resources $$(docker volume ls -q --filter "label=com.docker.compose.project=$$project")"
	for resource in $$resources; do
		[ -z "$$resource" ] && continue
		actual="$$(docker inspect --format '{{ index .Config.Labels "com.sysndd.mcp-select-verify-id" }}' "$$resource" 2>/dev/null || true)"
		if [ -z "$$actual" ] || [ "$$actual" = "<no value>" ]; then
			actual="$$(docker inspect --format '{{ index .Labels "com.sysndd.mcp-select-verify-id" }}' "$$resource")"
		fi
		[ "$$actual" = "$$verify_id" ] || { printf 'Refusing to mutate an unowned Docker resource\n' >&2; exit 1; }
	done
endef

verify-mcp-select-principal-live: check-docker ## [test] Run disposable SELECT-only MCP live proof
	@command -v openssl >/dev/null
	verify_id="$$(openssl rand -hex 16)"
	project="sysndd-mcp-select-verify-$$verify_id"
	root_password="$$(openssl rand -base64 36 | tr -d '\n')"
	sentinel="mcp-secret-sentinel-$$(openssl rand -hex 12)"
	log_file="$$(mktemp)"
	config_file="$$(mktemp)"
	reader_secret_file="$$(mktemp)"
	mcp_log_file="$$(mktemp)"
	sanitized_log_file="$$(mktemp)"
	root_pattern_file="$$(mktemp)"
	sentinel_pattern_file="$$(mktemp)"
	chmod 0600 "$$reader_secret_file" "$$mcp_log_file" "$$sanitized_log_file" \
		"$$root_pattern_file" "$$sentinel_pattern_file"
	printf '%s' "$$root_password" >"$$root_pattern_file"
	printf '%s' "$$sentinel" >"$$sentinel_pattern_file"
	cleanup() {
		$(verify_mcp_select_assert_labels)
		MCP_SELECT_VERIFY_ID="$$verify_id" MCP_VERIFY_ROOT_PASSWORD="$$root_password" MCP_VERIFY_SENTINEL="$$sentinel" \
			docker compose --project-name "$$project" --file "$(MCP_SELECT_VERIFY_COMPOSE)" down --volumes --remove-orphans >/dev/null 2>&1 || true
		rm -f "$$log_file" "$$config_file" "$$reader_secret_file" \
			"$$mcp_log_file" "$$sanitized_log_file" "$$root_pattern_file" \
			"$$sentinel_pattern_file"
	}
	trap cleanup EXIT INT TERM
	$(verify_mcp_select_assert_labels)
	MCP_SELECT_VERIFY_ID="$$verify_id" MCP_VERIFY_ROOT_PASSWORD="$$root_password" MCP_VERIFY_SENTINEL="$$sentinel" \
		docker compose --project-name "$$project" --file "$(MCP_SELECT_VERIFY_COMPOSE)" config --no-interpolate >"$$config_file"
	for pattern_file in "$$root_pattern_file" "$$sentinel_pattern_file"; do
		if grep -Fq -f "$$pattern_file" "$$config_file"; then
			printf 'Credential sentinel leaked into Compose rendering\n' >&2
			exit 1
		fi
	done
	run_failed=0
	compose() {
		MCP_SELECT_VERIFY_ID="$$verify_id" MCP_VERIFY_ROOT_PASSWORD="$$root_password" MCP_VERIFY_SENTINEL="$$sentinel" \
			docker compose --project-name "$$project" --file "$(MCP_SELECT_VERIFY_COMPOSE)" "$$@"
	}
	compose build >>"$$log_file" 2>&1 || run_failed=1
	[ "$$run_failed" -ne 0 ] || compose up --detach --no-deps mysql >>"$$log_file" 2>&1 || run_failed=1
	if [ "$$run_failed" -eq 0 ]; then
		mysql_id="$$(compose ps --quiet mysql)"
		for attempt in $$(seq 1 90); do
			[ "$$(docker inspect --format '{{.State.Health.Status}}' "$$mysql_id")" = healthy ] && break
			sleep 1
		done
		[ "$$(docker inspect --format '{{.State.Health.Status}}' "$$mysql_id")" = healthy ] || run_failed=1
	fi
	[ "$$run_failed" -ne 0 ] || compose run --rm --no-deps secret-init >>"$$log_file" 2>&1 || run_failed=1
	[ "$$run_failed" -ne 0 ] || compose run --rm --no-deps bootstrap >>"$$log_file" 2>&1 || run_failed=1
	[ "$$run_failed" -ne 0 ] || compose up --detach --no-deps mcp >>"$$log_file" 2>&1 || run_failed=1
	if [ "$$run_failed" -eq 0 ]; then
		mcp_id="$$(compose ps --quiet mcp)"
		for attempt in $$(seq 1 90); do
			[ "$$(docker inspect --format '{{.State.Health.Status}}' "$$mcp_id")" = healthy ] && break
			sleep 1
		done
		[ "$$(docker inspect --format '{{.State.Health.Status}}' "$$mcp_id")" = healthy ] || run_failed=1
	fi
	[ "$$run_failed" -ne 0 ] || compose run --rm --no-deps verify >>"$$log_file" 2>&1 || run_failed=1
	compose run --rm --no-deps -T verify sh -eu -c \
		'cat "$$MCP_DB_PASSWORD_FILE"' >"$$reader_secret_file" 2>/dev/null || true
	if [ -s "$$reader_secret_file" ]; then
		if grep -Fq -f "$$reader_secret_file" "$$log_file"; then
			printf 'generated reader password leaked into verifier logs\n' >&2
			run_failed=1
		fi
		compose logs --no-color mcp >"$$mcp_log_file" 2>/dev/null || true
		if grep -Fq -f "$$reader_secret_file" "$$mcp_log_file"; then
			printf 'generated reader password leaked into MCP logs\n' >&2
			run_failed=1
		fi
	fi
	for pattern_file in "$$root_pattern_file" "$$sentinel_pattern_file"; do
		if grep -Fq -f "$$pattern_file" "$$log_file"; then
			printf 'Credential sentinel leaked into verifier logs\n' >&2
			exit 1
		fi
	done
	if [ "$$run_failed" -ne 0 ]; then
		reader_secret="$$(cat "$$reader_secret_file" 2>/dev/null || true)"
		while IFS= read -r line; do
			case "$$line" in
				*"$$root_password"*|*"$$sentinel"*) printf '%s\n' '[credential-bearing log line redacted]' ;;
				*)
					if [ -n "$$reader_secret" ] && [ "$${line#*"$$reader_secret"}" != "$$line" ]; then
						printf '%s\n' '[credential-bearing log line redacted]'
					else
						printf '%s\n' "$$line"
					fi
					;;
			esac
		done <"$$log_file" >"$$sanitized_log_file"
		printf 'MCP SELECT-only live verification failed; sanitized tail follows\n' >&2
		tail -n 80 "$$sanitized_log_file" >&2
		exit 1
	fi
	[ "$$(grep -c '^MCP_SELECT_VERIFY_OK$$' "$$log_file")" -eq 1 ]
	cleanup
	trap - EXIT INT TERM
	printf 'MCP SELECT-only live verification PASS\n'
