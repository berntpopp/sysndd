# tests/testthat/test-mcp-select-principal-secret-hardening.R

library(testthat)

source_api_file("functions/mcp-readonly-provisioner-secret.R", local = FALSE)

.generated_password_row <- function(auth_factor = 1L) {
  data.frame(
    user = "sysndd_mcp",
    host = "%",
    `generated password` = "server-generated-secret",
    auth_factor = auth_factor,
    check.names = FALSE
  )
}

test_that("generated-password factor is exact and lossless", {
  expect_identical(
    mcp_readonly_generated_password(.generated_password_row()),
    "server-generated-secret"
  )
  expect_identical(
    mcp_readonly_generated_password(
      .generated_password_row(bit64::as.integer64("1"))
    ),
    "server-generated-secret"
  )
  expect_error(
    mcp_readonly_generated_password(.generated_password_row("1")),
    "factor"
  )
  expect_error(
    mcp_readonly_generated_password(
      .generated_password_row(bit64::as.integer64(NA))
    ),
    "factor"
  )
  expect_error(
    mcp_readonly_generated_password(
      .generated_password_row(bit64::as.integer64("2"))
    ),
    "factor"
  )
  expect_error(
    mcp_readonly_generated_password(
      .generated_password_row(bit64::as.integer64("9223372036854775807"))
    ),
    "factor"
  )
  expect_error(
    mcp_readonly_generated_password(.generated_password_row(1.5)),
    "factor"
  )
})

test_that("secret output requires an owner-only parent", {
  parent <- tempfile("mcp-insecure-parent-")
  dir.create(parent, mode = "0700")
  Sys.chmod(parent, mode = "0770", use_umask = FALSE)
  withr::defer(unlink(parent, recursive = TRUE))

  expect_error(
    mcp_readonly_write_secret(
      file.path(parent, "reader-password"),
      "server-generated-secret"
    ),
    "owner-only"
  )
})

test_that("secret rotation replaces content and preserves verified mode", {
  parent <- tempfile("mcp-secure-parent-")
  dir.create(parent, mode = "0700")
  Sys.chmod(parent, mode = "0700", use_umask = FALSE)
  withr::defer(unlink(parent, recursive = TRUE))
  path <- file.path(parent, "reader-password")

  mcp_readonly_write_secret(path, "first-server-secret")
  mcp_readonly_write_secret(path, "second-server-secret")

  expect_identical(readChar(path, file.info(path)$size), "second-server-secret")
  expect_identical(
    as.integer(file.info(path)$mode),
    as.integer(as.octmode("600"))
  )

  implementation <- paste(
    readLines(
      file.path(get_api_dir(), "functions", "mcp-readonly-provisioner-secret.R"),
      warn = FALSE
    ),
    collapse = "\n"
  )
  expect_match(implementation, 'file_test("-f", target)', fixed = TRUE)
})
