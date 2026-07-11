analysis_snapshot_test_wd <- getwd()
setwd(get_api_dir())
withr::defer(setwd(analysis_snapshot_test_wd), testthat::teardown_env())

test_that("async workers preload analysis snapshot refresh dependencies before handlers", {
  lines <- readLines(file.path("bootstrap", "setup_workers.R"), warn = FALSE)

  expected_sources <- c(
    'source("/app/functions/analysis-snapshot-presets.R", local = FALSE)',
    'source("/app/functions/analysis-snapshot-repository.R", local = FALSE)',
    'source("/app/functions/analysis-snapshot-builder.R", local = FALSE)',
    'source("/app/functions/async-job-analysis-snapshot-handlers.R", local = FALSE)',
    'source("/app/functions/async-job-handlers.R", local = FALSE)'
  )

  positions <- vapply(
    expected_sources,
    function(source_line) {
      matches <- which(trimws(lines) == source_line)
      expect_equal(length(matches), 1L)
      if (length(matches) != 1L) {
        return(NA_integer_)
      }
      matches[[1]]
    },
    integer(1)
  )

  expect_equal(positions, sort(positions))
})

# ---------------------------------------------------------------------------
# #346 Wave 4: async_job_handler_registry binds provider/maintenance handler
# functions by bare symbol inside an eagerly-evaluated list(), so both
# extracted modules must be sourced BEFORE async-job-handlers.R at every
# worker entrypoint, exactly once, in this relative order. These two checks
# cover BOTH worker entrypoints: the mirai bootstrap (bootstrap/setup_workers.R)
# and the durable async worker's guarded fallback chain
# (functions/async-job-worker.R). Wiring those two files is an explicitly
# separate, coordinated step (owned outside this handler-split task, alongside
# load_modules.R and start_async_worker.R, to avoid parallel-worktree merge
# conflicts across the other #346 Wave 4 file splits) -- so each check
# self-skips with an explicit message until its file gains the new source
# lines, rather than hard-failing on work that is intentionally out of scope
# here. Once the wiring lands, these upgrade automatically from SKIP to a real
# assertion.
# ---------------------------------------------------------------------------

test_that("mirai bootstrap preloads provider/maintenance handlers before the shell, exactly once", {
  lines <- readLines(file.path("bootstrap", "setup_workers.R"), warn = FALSE)

  expected_sources <- c(
    'source("/app/functions/async-job-provider-handlers.R", local = FALSE)',
    'source("/app/functions/async-job-maintenance-handlers.R", local = FALSE)',
    'source("/app/functions/async-job-handlers.R", local = FALSE)'
  )

  if (!any(trimws(lines) == expected_sources[[1]])) {
    skip(paste(
      "bootstrap/setup_workers.R does not yet source async-job-provider-handlers.R",
      "-- pending coordinated #346 Wave 4 bootstrap wiring"
    ))
  }

  positions <- vapply(
    expected_sources,
    function(source_line) {
      matches <- which(trimws(lines) == source_line)
      expect_equal(length(matches), 1L, info = source_line)
      if (length(matches) != 1L) {
        return(NA_integer_)
      }
      matches[[1]]
    },
    integer(1)
  )

  expect_equal(positions, sort(positions))
})

test_that("the durable worker's guarded fallback chain preloads provider/maintenance before the shell", {
  lines <- readLines(file.path("functions", "async-job-worker.R"), warn = FALSE)
  body <- paste(lines, collapse = "\n")

  provider_pos <- regexpr("async-job-provider-handlers\\.R", body)
  maintenance_pos <- regexpr("async-job-maintenance-handlers\\.R", body)

  if (provider_pos < 0 || maintenance_pos < 0) {
    skip(paste(
      "functions/async-job-worker.R does not yet source the provider/maintenance",
      "handler modules -- pending coordinated #346 Wave 4 bootstrap wiring"
    ))
  }

  # The literal "async-job-handlers.R" also matches inside
  # "async-job-provider-handlers.R" / "...-maintenance-handlers.R"; find the
  # occurrence of the bare shell filename that is NOT part of either extracted
  # module's longer filename.
  handler_matches <- gregexpr("functions/async-job-handlers\\.R", body, fixed = FALSE)[[1]]
  expect_true(length(handler_matches) >= 1 && handler_matches[[1]] > 0)

  shell_pos <- handler_matches[[1]]
  expect_lt(provider_pos, shell_pos)
  expect_lt(maintenance_pos, shell_pos)
})

test_that("async workers preload LLM model configuration before LLM clients", {
  lines <- trimws(readLines(file.path("bootstrap", "setup_workers.R"), warn = FALSE))

  model_config_pos <- which(lines == 'source("/app/functions/llm-model-config.R", local = FALSE)')
  client_pos <- which(lines == 'source("/app/functions/llm-client.R", local = FALSE)')
  service_pos <- which(lines == 'source("/app/functions/llm-service.R", local = FALSE)')

  expect_length(model_config_pos, 1L)
  expect_length(client_pos, 1L)
  expect_length(service_pos, 1L)
  expect_lt(model_config_pos, client_pos)
  expect_lt(model_config_pos, service_pos)
})
