# test-unit-llm-model-default-guard.R
#
# Static guard for GitHub issue #348: the default Gemini model must be a single
# centralized, currently-supported value. Shut-down preview models such as
# `gemini-3-pro-preview` (retired 2026-03-09) and `gemini-3-flash-preview` must
# never be reintroduced as a hardcoded default, fallback, or function-arg
# default in runtime source. They may only appear inside the central catalog in
# `functions/llm-model-config.R`, where they are explicitly marked shut-down and
# disallowed for historical cache metadata.

library(testthat)

# Runtime source trees scanned for default/fallback Gemini model literals.
llm_runtime_dirs <- c("functions", "endpoints", "services", "core", "bootstrap")

# Models Google has shut down; never allowed as a runtime default.
retired_gemini_models <- c("gemini-3-pro-preview", "gemini-3-flash-preview")

# Single file permitted to *name* shut-down models, and only as catalog metadata.
llm_model_catalog_file <- "functions/llm-model-config.R"

llm_runtime_source_files <- function() {
  api_dir <- normalizePath(get_api_dir())
  files <- unlist(
    lapply(llm_runtime_dirs, function(dir) {
      full <- file.path(api_dir, dir)
      if (!dir.exists(full)) {
        return(character(0))
      }
      list.files(full, pattern = "\\.R$", full.names = TRUE, recursive = TRUE)
    }),
    use.names = FALSE
  )
  # Return paths relative to api_dir for readable failure messages.
  sub(paste0("^", api_dir, "/?"), "", normalizePath(files))
}

# Patterns that indicate a model literal is being used as a *default* value:
#   - function argument default:      model = "gemini-3-pro-preview"
#   - null-coalescing fallback:       ... %||% "gemini-3-pro-preview"
#   - config-style assignment:        gemini_model = "gemini-3-pro-preview"
#   - variable default assignment:    SOMETHING <- "gemini-3-pro-preview"
default_usage_patterns <- function(model) {
  q <- gsub("\\.", "\\\\.", model) # escape dots for regex
  c(
    sprintf("\\bmodel\\s*=\\s*[\"']%s[\"']", q),
    sprintf("%%\\|\\|%%\\s*[\"']%s[\"']", q),
    sprintf("\\bgemini_model\\s*=\\s*[\"']%s[\"']", q),
    sprintf("<-\\s*[\"']%s[\"']", q)
  )
}

find_retired_default_usages <- function(relative_path) {
  if (identical(relative_path, llm_model_catalog_file)) {
    return(character(0))
  }

  lines <- readLines(file.path(get_api_dir(), relative_path), warn = FALSE)
  violations <- character(0)

  for (model in retired_gemini_models) {
    for (pattern in default_usage_patterns(model)) {
      hits <- grep(pattern, lines, perl = TRUE)
      hits <- hits[!grepl("^\\s*#", lines[hits])] # ignore comment lines
      if (length(hits) > 0) {
        violations <- c(
          violations,
          sprintf("%s:%d: %s", relative_path, hits, trimws(lines[hits]))
        )
      }
    }
  }

  violations
}

test_that("no runtime source uses a shut-down Gemini model as a default", {
  violations <- unlist(
    lapply(llm_runtime_source_files(), find_retired_default_usages),
    use.names = FALSE
  )

  if (length(violations) > 0) {
    fail(paste(
      "Shut-down Gemini model used as a default/fallback (issue #348):",
      paste(violations, collapse = "\n"),
      "Resolve the default via get_default_gemini_model() instead.",
      sep = "\n"
    ))
  }

  expect_length(violations, 0)
})

test_that("centralized default Gemini model is currently supported", {
  source(testthat::test_path("../../functions/llm-model-config.R"), local = TRUE)

  # The single in-code default must be an allowed, non-retired catalog model.
  expect_true(LLM_DEFAULT_GEMINI_MODEL %in% list_gemini_models())
  expect_false(LLM_DEFAULT_GEMINI_MODEL %in% retired_gemini_models)

  default_meta <- llm_model_metadata(LLM_DEFAULT_GEMINI_MODEL)
  expect_true(isTRUE(default_meta$allowed))
  expect_equal(default_meta$status, "stable")
})

test_that("retired Gemini models stay disallowed in the catalog", {
  source(testthat::test_path("../../functions/llm-model-config.R"), local = TRUE)

  for (model in retired_gemini_models) {
    meta <- llm_model_metadata(model)
    # Either absent from the catalog (status "unknown") or present but shut down;
    # in both cases it must not be allowed and must not be a selectable model.
    expect_false(isTRUE(meta$allowed))
    expect_false(model %in% list_gemini_models())
  }
})
