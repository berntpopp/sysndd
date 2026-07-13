# tests/testthat/test-mcp-select-principal-compose.R

library(testthat)

.mcp_compose_repo_root <- normalizePath(
  file.path(testthat::test_path(), "..", "..", ".."),
  mustWork = TRUE
)

.mcp_compose_service_block <- function(path, service) {
  lines <- readLines(path, warn = FALSE)
  start <- grep(paste0("^  ", service, ":$"), lines)
  stopifnot(length(start) == 1L)
  later_services <- grep("^  [a-zA-Z0-9_-]+:$", lines)
  later_services <- later_services[later_services > start]
  end <- if (length(later_services)) min(later_services) - 1L else length(lines)
  lines[start:end]
}

test_that("MCP compose wiring injects only its dedicated database principal", {
  compose <- file.path(.mcp_compose_repo_root, "docker-compose.yml")
  block <- .mcp_compose_service_block(compose, "mcp")
  text <- paste(block, collapse = "\n")

  expect_match(text, "MCP_DB_HOST:")
  expect_match(text, "MCP_DB_PORT:")
  expect_match(text, "MCP_DB_NAME:")
  expect_match(text, "MCP_DB_USER: sysndd_mcp", fixed = TRUE)
  expect_match(text, "MCP_DB_PASSWORD_FILE: /run/secrets/mcp_db_password", fixed = TRUE)
  expect_match(text, "type: bind", fixed = TRUE)
  expect_match(
    text, "source: ${MCP_DB_PASSWORD_OUTPUT_FILE:-./secrets/mcp-db-password}",
    fixed = TRUE
  )
  expect_match(text, "target: /run/secrets/mcp_db_password", fixed = TRUE)
  expect_match(text, "read_only: true", fixed = TRUE)
  expect_match(text, "create_host_path: false", fixed = TRUE)
  expect_false(grepl("MCP_DB_PASSWORD:", text, fixed = TRUE))
  expect_false(grepl("MYSQL_USER|MYSQL_PASSWORD|MYSQL_ROOT_PASSWORD", text))
  expect_false(grepl("/app/config.yml|api_cache|/app/data", text))
  expect_false(grepl("CACHE_VERSION", text, fixed = TRUE))
  expect_match(text, "./api/config/mcp:/app/config/mcp:ro", fixed = TRUE)
})

test_that("MCP is opt-in without weakening missing-secret failure", {
  compose <- file.path(.mcp_compose_repo_root, "docker-compose.yml")
  block <- .mcp_compose_service_block(compose, "mcp")
  text <- paste(block, collapse = "\n")

  expect_match(text, 'profiles: ["mcp"]', fixed = TRUE)
  expect_false(grepl("MCP_DB_PASSWORD_OUTPUT_FILE:?", text, fixed = TRUE))
  expect_match(text, "create_host_path: false", fixed = TRUE)
})

test_that("MCP provisioner is an isolated one-off backend service", {
  compose <- file.path(.mcp_compose_repo_root, "docker-compose.yml")
  block <- .mcp_compose_service_block(compose, "mcp-provisioner")
  text <- paste(block, collapse = "\n")

  expect_match(text, 'profiles: ["mcp-provision"]', fixed = TRUE)
  expect_match(
    text, 'command: ["Rscript", "scripts/provision-mcp-readonly-principal.R"]',
    fixed = TRUE
  )
  expect_match(text, "source: ./secrets", fixed = TRUE)
  expect_match(text, "target: /run/secrets/sysndd", fixed = TRUE)
  expect_match(text, "read_only: false", fixed = TRUE)
  expect_match(text, "create_host_path: false", fixed = TRUE)
  expect_match(text, "MCP_ADMIN_DB_PASSWORD_FILE:", fixed = TRUE)
  expect_match(text, "MCP_DB_PASSWORD_OUTPUT_FILE:", fixed = TRUE)
  expect_match(text, "MCP_MIGRATION_PATH:", fixed = TRUE)
  expect_match(text, "- backend", fixed = TRUE)
  expect_false(grepl("MCP_ADMIN_DB_PASSWORD:", text, fixed = TRUE))
  expect_false(grepl("MYSQL_PASSWORD|MYSQL_ROOT_PASSWORD", text))
})

test_that("example environment documents reader and operator inputs without values", {
  example <- readLines(
    file.path(.mcp_compose_repo_root, ".env.example"),
    warn = FALSE
  )
  text <- paste(example, collapse = "\n")

  expect_match(
    text, "MCP_DB_PASSWORD_OUTPUT_FILE=./secrets/mcp-db-password",
    fixed = TRUE
  )
  expect_match(
    text, "MCP_ADMIN_DB_PASSWORD_FILE=./secrets/mcp-admin-db-password",
    fixed = TRUE
  )
  expect_match(text, "MCP_EXPECTED_VIEW_DEFINER=", fixed = TRUE)
  expect_false(any(grepl("^MCP_ADMIN_DB_PASSWORD=", example)))
  expect_false(grepl("MCP_DB_USER=", text, fixed = TRUE))
})

test_that("deployment documents a containerized file-only provisioner", {
  deployment <- readLines(
    file.path(.mcp_compose_repo_root, "documentation", "09-deployment.qmd"),
    warn = FALSE
  )
  text <- paste(deployment, collapse = "\n")

  expect_match(
    text,
    "docker compose --profile mcp-provision run --rm --no-deps mcp-provisioner",
    fixed = TRUE
  )
  expect_match(
    text,
    "MCP_ADMIN_DB_PASSWORD_FILE=/run/secrets/sysndd/mcp-admin-db-password",
    fixed = TRUE
  )
  expect_match(
    text,
    "MCP_DB_PASSWORD_OUTPUT_FILE=/run/secrets/sysndd/mcp-db-password",
    fixed = TRUE
  )
  expect_match(text, "docker compose --profile mcp up -d mcp", fixed = TRUE)
  expect_false(grepl("MCP_ADMIN_DB_PASSWORD=", text, fixed = TRUE))
})
