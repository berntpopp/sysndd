library(testthat)

find_repo_root <- function(start = getwd()) {
  current <- normalizePath(start, mustWork = TRUE)
  repeat {
    candidate <- file.path(current, "docker-compose.yml")
    if (file.exists(candidate)) {
      return(current)
    }
    parent <- dirname(current)
    if (identical(parent, current)) {
      stop("docker-compose.yml not found from ", start, call. = FALSE)
    }
    current <- parent
  }
}

repo_root <- find_repo_root()
compose_path <- file.path(repo_root, "docker-compose.yml")

test_that("async worker has outbound egress for external provider calls", {
  skip_if_not_installed("yaml")

  compose <- yaml::read_yaml(compose_path)

  expect_true(isTRUE(compose$networks$backend$internal))
  expect_true("backend" %in% compose$services$worker$networks)
  expect_true("proxy" %in% compose$services$worker$networks)
})

test_that("production API and MCP wait for DB readiness and use cheap MCP healthcheck", {
  skip_if_not_installed("yaml")

  compose <- yaml::read_yaml(compose_path)

  expect_equal(compose$services$api$depends_on$mysql$condition, "service_healthy")
  expect_equal(compose$services$mcp$depends_on$mysql$condition, "service_healthy")
  expect_false(any(grepl("mcp-smoke", compose$services$mcp$healthcheck$test, fixed = TRUE)))
  expect_true(any(grepl("mcp-healthcheck.R", compose$services$mcp$healthcheck$test, fixed = TRUE)))
  expect_true(file.exists(file.path(repo_root, "api", "scripts", "mcp-healthcheck.R")))
})

test_that("Playwright auth load is bounded without weakening proxy header stripping", {
  skip_if_not_installed("yaml")

  overlay <- yaml::read_yaml(file.path(repo_root, "docker-compose.playwright.yml"))
  api <- overlay$services$api
  labels <- unlist(api$labels, use.names = FALSE)

  expect_equal(api$environment$AUTH_ENDPOINT_PER_CALLER_MAX, 1000L)
  expect_true(any(grepl(
    "api-strip-xff-alias.headers.customRequestHeaders.X_Forwarded_For=",
    labels, fixed = TRUE
  )))
  expect_true(any(grepl(
    "playwright-api.middlewares=api-strip-xff-alias@docker",
    labels, fixed = TRUE
  )))
})
