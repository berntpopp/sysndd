# tests/testthat/test-unit-admin-backup-na-serializer.R
# The Administrator pages rendered R's missing values as text ("Last: NA" on
# Manage Annotations, "NaN tables" on Manage Backups) because these routes used
# `list(na="string")`, which serializes NA as the literal string "NA". They now
# use `na="null"`, so a missing date or count reaches the client as JSON null.

library(testthat)

na_serializer_files <- function() {
  file.path(get_api_dir(), "endpoints", c("admin_endpoints.R", "backup_endpoints.R"))
}

test_that("admin and backup routes never serialize NA as the string \"NA\"", {
  for (path in na_serializer_files()) {
    src <- readLines(path, warn = FALSE)
    serializers <- grep("^#\\*\\s+@serializer\\s+(unboxed)?(json|JSON)", src, value = TRUE)
    expect_gt(length(serializers), 0L)
    expect_false(
      any(grepl('na\\s*=\\s*"string"', serializers)),
      info = paste(basename(path), "still declares na=\"string\"")
    )
  }
})

test_that("na=\"null\" renders a missing annotation date and table count as null", {
  payload <- list(omim_update = NA_character_, table_count = NA_integer_)
  json <- as.character(jsonlite::toJSON(payload, na = "null"))
  expect_identical(json, '{"omim_update":[null],"table_count":[null]}')
  expect_false(grepl('"NA"', json, fixed = TRUE))
})
