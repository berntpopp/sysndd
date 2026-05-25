library(testthat)

metadata_refresh_runtime_files <- c(
  "endpoints/admin_endpoints.R",
  "functions/async-job-handlers.R"
)

find_executable_metadata_truncates <- function(relative_path) {
  path <- file.path(get_api_dir(), relative_path)
  lines <- readLines(path, warn = FALSE)
  hits <- grep(
    "\\bTRUNCATE\\s+TABLE\\s+`?(disease_ontology_set|non_alt_loci_set)\\b`?",
    lines,
    ignore.case = TRUE
  )
  hits <- hits[!grepl("^\\s*#", lines[hits])]

  if (length(hits) == 0) {
    return(character(0))
  }

  sprintf("%s:%d: %s", relative_path, hits, trimws(lines[hits]))
}

test_that("metadata refresh runtime code does not use TRUNCATE", {
  violations <- unlist(
    lapply(metadata_refresh_runtime_files, find_executable_metadata_truncates),
    use.names = FALSE
  )

  if (length(violations) > 0) {
    fail(paste(
      "Found rollback-unsafe metadata TRUNCATE statements:",
      paste(violations, collapse = "\n"),
      sep = "\n"
    ))
  }

  expect_length(violations, 0)
})

test_that("admin ontology job submissions do not keep dead inline executors", {
  admin_path <- file.path(get_api_dir(), "endpoints", "admin_endpoints.R")
  admin_body <- paste(readLines(admin_path, warn = FALSE), collapse = "\n")

  expect_false(
    grepl(
      "operation\\s*=\\s*\"omim_update\"[\\s\\S]{0,8000}executor_fn\\s*=\\s*function",
      admin_body,
      perl = TRUE
    )
  )
  expect_false(
    grepl(
      "operation\\s*=\\s*\"force_apply_ontology\"[\\s\\S]{0,8000}executor_fn\\s*=\\s*function",
      admin_body,
      perl = TRUE
    )
  )
})
