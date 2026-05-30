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
