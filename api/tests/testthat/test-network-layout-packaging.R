test_that("API Dockerfile installs Node 24 and layout helper dependencies", {
  dockerfile <- paste(readLines(file.path(get_api_dir(), "Dockerfile"), warn = FALSE), collapse = "\n")

  expect_match(dockerfile, "setup_24\\.x")
  expect_match(dockerfile, "apt-get install -y --no-install-recommends nodejs")
  expect_match(dockerfile, "COPY .*layout/package\\.json layout/package-lock\\.json /app/layout/")
  expect_match(dockerfile, "npm ci --omit=dev")
  expect_match(dockerfile, "COPY .*layout/gene-network-fcose-layout\\.mjs /app/layout/gene-network-fcose-layout\\.mjs")
  expect_false(grepl("gene-network-fcose-layout.test.mjs", dockerfile, fixed = TRUE))
})

test_that("compose mounts layout helper files without hiding installed node_modules", {
  compose <- readLines(file.path(dirname(get_api_dir()), "docker-compose.yml"), warn = FALSE)

  service_block <- function(service) {
    start <- grep(paste0("^  ", service, ":"), compose)
    next_service <- grep("^  [a-zA-Z0-9_-]+:", compose)
    end <- min(next_service[next_service > start], length(compose) + 1L) - 1L
    compose[start:end]
  }

  expected_mounts <- c(
    "./api/layout/gene-network-fcose-layout.mjs:/app/layout/gene-network-fcose-layout.mjs:ro",
    "./api/layout/package.json:/app/layout/package.json:ro",
    "./api/layout/package-lock.json:/app/layout/package-lock.json:ro"
  )

  for (service in c("api", "worker")) {
    block <- service_block(service)

    expect_false(any(grepl("./api/layout:/app/layout", block, fixed = TRUE)))
    expect_false(any(grepl("/app/layout/node_modules", block, fixed = TRUE)))

    for (mount in expected_mounts) {
      expect_true(any(grepl(mount, block, fixed = TRUE)))
    }
  }
})

test_that("API Docker build context ignores host layout node_modules", {
  dockerignore <- readLines(file.path(get_api_dir(), ".dockerignore"), warn = FALSE)

  expect_true(any(grepl("^layout/node_modules/?$", dockerignore)))
})

test_that("API Docker image does not copy real runtime config.yml", {
  dockerfile <- paste(readLines(file.path(get_api_dir(), "Dockerfile"), warn = FALSE), collapse = "\n")

  expect_false(grepl("COPY .*config\\.yml config\\.yml", dockerfile))
})

test_that("API Docker image healthcheck uses mounted API health route", {
  dockerfile <- paste(readLines(file.path(get_api_dir(), "Dockerfile"), warn = FALSE), collapse = "\n")

  expect_match(dockerfile, "http://localhost:7777/api/health/")
  expect_false(grepl("http://localhost:7777/health/", dockerfile, fixed = TRUE))
})

test_that("API Docker build context excludes real runtime config files", {
  dockerignore <- readLines(file.path(get_api_dir(), ".dockerignore"), warn = FALSE)

  expect_true(any(grepl("^config[.]yml$", dockerignore)))
  expect_true(any(grepl("^config[.]yml[.]devbackup$", dockerignore)))
})

test_that("compose mounts API runtime config read-only", {
  compose <- readLines(file.path(dirname(get_api_dir()), "docker-compose.yml"), warn = FALSE)

  service_block <- function(service) {
    start <- grep(paste0("^  ", service, ":"), compose)
    next_service <- grep("^  [a-zA-Z0-9_-]+:", compose)
    end <- min(next_service[next_service > start], length(compose) + 1L) - 1L
    compose[start:end]
  }

  for (service in c("api", "worker", "mcp")) {
    block <- service_block(service)
    expect_true(any(grepl("./api/config.yml:/app/config.yml:ro", block, fixed = TRUE)), info = service)
  }
})
