#!/usr/bin/env Rscript

resolve_ci_test_dir <- function(test_dir = "tests/testthat") {
  candidate_dirs <- c(
    test_dir,
    file.path("api", test_dir),
    file.path("..", test_dir),
    file.path("..", "..", test_dir)
  )

  if (exists("get_api_dir", mode = "function")) {
    candidate_dirs <- c(candidate_dirs, file.path(get_api_dir(), test_dir))
  }

  for (candidate_dir in unique(candidate_dirs)) {
    if (dir.exists(candidate_dir)) {
      return(normalizePath(candidate_dir))
    }
  }

  stop("Cannot resolve CI test directory: ", test_dir, call. = FALSE)
}

list_all_ci_test_files <- function(test_dir = "tests/testthat") {
  resolved_test_dir <- resolve_ci_test_dir(test_dir)

  list.files(
    resolved_test_dir,
    pattern = "^test-.*\\.R$",
    full.names = TRUE
  )
}

fast_ci_excluded_test_files <- function() {
  c(
    "test-e2e-user-lifecycle.R",
    "test-external-ensembl.R",
    "test-external-hgnc.R",
    "test-external-pubmed.R",
    "test-external-pubtator.R",
    "test-integration-async.R",
    "test-integration-email.R",
    "test-integration-health.R",
    "test-integration-llm-endpoints.R",
    "test-integration-logs-pagination.R",
    "test-integration-pagination.R",
    "test-integration-version.R",
    "test-llm-benchmark.R"
  )
}

list_ci_test_files <- function(mode = c("fast", "full"), test_dir = "tests/testthat") {
  normalized_mode <- tolower(mode[[1]])

  if (!normalized_mode %in% c("fast", "full")) {
    stop("Unknown CI test selection mode: ", normalized_mode, call. = FALSE)
  }

  all_files <- sort(list_all_ci_test_files(test_dir))

  if (normalized_mode == "full") {
    return(all_files)
  }

  excluded_files <- file.path(resolve_ci_test_dir(test_dir), fast_ci_excluded_test_files())
  setdiff(all_files, excluded_files)
}

build_test_file_filter <- function(test_files) {
  escaped_names <- vapply(
    basename(test_files),
    function(file_name) {
      test_stem <- sub("\\.R$", "", sub("^test-", "", file_name))
      gsub("([][{}()+*^$|\\\\?.])", "\\\\\\1", test_stem)
    },
    character(1)
  )

  paste0("^(", paste(escaped_names, collapse = "|"), ")$")
}
