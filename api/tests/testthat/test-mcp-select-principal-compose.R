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

.mcp_compose_model <- function() {
  yaml::read_yaml(file.path(.mcp_compose_repo_root, "docker-compose.yml"))
}

.mcp_compose_label_map <- function(service) {
  labels <- unlist(service$labels, use.names = FALSE)
  stopifnot(is.character(labels), is.null(names(labels)))
  parts <- strsplit(labels, "=", fixed = TRUE)
  keys <- vapply(parts, `[[`, character(1), 1L)
  values <- vapply(parts, function(x) paste(x[-1L], collapse = "="), character(1))
  stats::setNames(values, keys)
}

.mcp_markdown_section <- function(path, heading, next_heading_pattern) {
  lines <- readLines(path, warn = FALSE)
  start <- grep(paste0("^", heading, "$"), lines)
  stopifnot(length(start) == 1L)
  later_headings <- grep(next_heading_pattern, lines)
  later_headings <- later_headings[later_headings > start]
  end <- if (length(later_headings)) min(later_headings) - 1L else length(lines)
  paste(lines[start:end], collapse = "\n")
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

test_that("MCP profile exposes a bounded credential-free transport without egress", {
  model <- .mcp_compose_model()
  mcp <- model$services$mcp
  traefik <- model$services$traefik
  labels <- .mcp_compose_label_map(mcp)

  expect_setequal(unlist(mcp$networks), c("backend", "mcp_edge"))
  expect_false("proxy" %in% unlist(mcp$networks))
  expect_true("mcp_edge" %in% unlist(traefik$networks))
  expect_true(isTRUE(model$networks$mcp_edge$internal))
  expect_identical(model$networks$mcp_edge$name, "sysndd_mcp_edge")

  expected <- c(
    "traefik.enable" = "true",
    "traefik.docker.network" = "sysndd_mcp_edge",
    "traefik.http.routers.mcp-post.rule" =
      "Host(`sysndd.dbmr.unibe.ch`) && Path(`/mcp`) && Method(`POST`)",
    "traefik.http.routers.mcp-post.entrypoints" = "web",
    "traefik.http.routers.mcp-post.priority" = "200",
    "traefik.http.routers.mcp-post.service" = "mcp",
    "traefik.http.routers.mcp-post.middlewares" =
      "mcp-shared-rate,mcp-post-body,mcp-post-inflight,mcp-strip",
    "traefik.http.routers.mcp-post.observability.accesslogs" = "true",
    "traefik.http.routers.mcp-get.rule" =
      paste0(
        "Host(`sysndd.dbmr.unibe.ch`) && Path(`/mcp`) && Method(`GET`) && ",
        "HeaderRegexp(`Accept`, `text/event-stream`)"
      ),
    "traefik.http.routers.mcp-get.entrypoints" = "web",
    "traefik.http.routers.mcp-get.priority" = "200",
    "traefik.http.routers.mcp-get.service" = "mcp",
    "traefik.http.routers.mcp-get.middlewares" = "mcp-shared-rate,mcp-strip",
    "traefik.http.routers.mcp-get.observability.accesslogs" = "true",
    "traefik.http.middlewares.mcp-shared-rate.ratelimit.average" = "120",
    "traefik.http.middlewares.mcp-shared-rate.ratelimit.period" = "1m",
    "traefik.http.middlewares.mcp-shared-rate.ratelimit.burst" = "20",
    "traefik.http.middlewares.mcp-shared-rate.ratelimit.sourcecriterion.requesthost" = "true",
    "traefik.http.middlewares.mcp-post-body.buffering.maxrequestbodybytes" = "262144",
    "traefik.http.middlewares.mcp-post-inflight.inflightreq.amount" = "4",
    "traefik.http.middlewares.mcp-post-inflight.inflightreq.sourcecriterion.requesthost" = "true",
    "traefik.http.middlewares.mcp-strip.stripprefix.prefixes" = "/mcp",
    "traefik.http.services.mcp.loadbalancer.server.port" = "8787"
  )

  expect_identical(labels[names(expected)], expected)
  expect_false(any(grepl(
    "basic.?auth|forward.?auth|oauth|bearer|mcp-auth",
    paste(names(labels), labels),
    ignore.case = TRUE
  )))

  command <- unlist(traefik$command, use.names = FALSE)
  expect_true("--entryPoints.web.transport.respondingTimeouts.readTimeout=60s" %in% command)
  expect_true("--accesslog=true" %in% command)
  expect_true("--accesslog.format=json" %in% command)
  expect_true("--accesslog.fields.headers.defaultmode=drop" %in% command)
  expect_true("--accesslog.fields.queryparameters.defaultmode=drop" %in% command)
  expect_true("--entryPoints.web.observability.accessLogs=false" %in% command)
})

test_that("MCP operator and contributor documentation matches the public edge contract", {
  agents <- .mcp_markdown_section(
    file.path(.mcp_compose_repo_root, "AGENTS.md"),
    "### Read-only MCP sidecar",
    "^### "
  )
  api_docs <- .mcp_markdown_section(
    file.path(.mcp_compose_repo_root, "documentation", "03-api.qmd"),
    "## Read-only MCP sidecar",
    "^## "
  )
  deployment <- .mcp_markdown_section(
    file.path(.mcp_compose_repo_root, "documentation", "09-deployment.qmd"),
    "### MCP sidecar settings",
    "^#{2,3} "
  )

  for (section in list(agents, api_docs, deployment)) {
    expect_match(section, "public and credential-free", fixed = TRUE)
    expect_match(section, "approved-public", fixed = TRUE)
    expect_false(grepl("private/internal by default", section, fixed = TRUE))
    expect_false(grepl("static bearer", section, ignore.case = TRUE))
    expect_false(grepl("mcp-auth", section, fixed = TRUE))
  }

  expect_match(deployment, "120 requests per minute", fixed = TRUE)
  expect_match(deployment, "20-request burst", fixed = TRUE)
  expect_match(deployment, "256 KiB", fixed = TRUE)
  expect_match(deployment, "4 concurrent POST requests", fixed = TRUE)
  expect_match(deployment, "60-second", fixed = TRUE)
  expect_match(deployment, "HTTP 429", fixed = TRUE)
  expect_match(deployment, "HTTP 413", fixed = TRUE)
  expect_match(deployment, "shared Host bucket", fixed = TRUE)
  expect_match(deployment, "mcp_edge", fixed = TRUE)
  expect_match(deployment, "no outbound internet egress", fixed = TRUE)
  expect_match(deployment, "invalid non-empty `Origin`", fixed = TRUE)
  expect_match(deployment, "does not replace authentication", fixed = TRUE)
  expect_match(deployment, "bodies, headers, and query parameters are not logged", fixed = TRUE)

  override <- paste(readLines(
    file.path(.mcp_compose_repo_root, "docker-compose.override.yml"),
    warn = FALSE
  ), collapse = "\n")
  expect_match(override, "Production MCP uses the public\\s+credential-free Traefik route")
  expect_false(grepl("Production compose does not expose", override, fixed = TRUE))

  changelog <- .mcp_markdown_section(
    file.path(.mcp_compose_repo_root, "CHANGELOG.md"),
    "## \\[Unreleased\\]",
    "^## \\["
  )
  expect_match(changelog, "credential-free", fixed = TRUE)
  expect_match(changelog, "#629", fixed = TRUE)
})
