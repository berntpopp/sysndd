library(testthat)

publication_endpoint_path <- function() {
  file.path(get_api_dir(), "endpoints", "publication_endpoints.R")
}

publication_source <- function() {
  readLines(publication_endpoint_path(), warn = FALSE)
}

publication_body_blob <- function(decorator_regex) {
  src <- publication_source()
  dec_hits <- grep(decorator_regex, src)
  if (length(dec_hits) == 0L) {
    stop("Decorator not found in publication_endpoints.R: ", decorator_regex)
  }
  dec_idx <- dec_hits[[1L]]
  next_dec <- grep("^#\\*\\s+@(get|post|put|delete)\\b", src)
  after_idx <- next_dec[next_dec > dec_idx]
  after <- if (length(after_idx) == 0L) length(src) + 1L else after_idx[[1L]]
  paste(src[dec_idx:(after - 1L)], collapse = "\n")
}

test_that("publication_endpoints.R exposes public read route surface", {
  with_test_db_transaction({
    src <- publication_source()
    expect_true(any(grepl("^#\\*\\s+@get\\s+/stats\\s*$", src)))
    expect_true(any(grepl("^#\\*\\s+@get\\s+<pmid>\\s*$", src)))
    expect_true(any(grepl("^#\\*\\s+@get\\s+pubtator/search\\s*$", src)))
    expect_true(any(grepl("^#\\*\\s+@get\\s+/\\s*$", src)))
    expect_true(any(grepl("^#\\*\\s+@get\\s+/pubtator/table\\s*$", src)))
    expect_true(any(grepl("^#\\*\\s+@get\\s+/pubtator/genes\\s*$", src)))
  })
})

test_that("publication public read routes do not require Administrator role", {
  with_test_db_transaction({
    public_routes <- c(
      "^#\\*\\s+@get\\s+/stats\\s*$",
      "^#\\*\\s+@get\\s+<pmid>\\s*$",
      "^#\\*\\s+@get\\s+pubtator/search\\s*$",
      "^#\\*\\s+@get\\s+/\\s*$",
      "^#\\*\\s+@get\\s+/pubtator/table\\s*$",
      "^#\\*\\s+@get\\s+/pubtator/genes\\s*$"
    )
    for (route in public_routes) {
      expect_false(grepl("require_role\\(", publication_body_blob(route)))
    }
  })
})

test_that("PubTator list routes keep cursor pagination and xlsx branches", {
  with_test_db_transaction({
    table_body <- publication_body_blob("^#\\*\\s+@get\\s+/pubtator/table\\s*$")
    genes_body <- publication_body_blob("^#\\*\\s+@get\\s+/pubtator/genes\\s*$")
    expect_match(table_body, "page_after")
    expect_match(table_body, "page_size")
    expect_match(table_body, "\"xlsx\"")
    expect_match(genes_body, "page_after")
    expect_match(genes_body, "page_size")
    expect_match(genes_body, "\"xlsx\"")
  })
})

test_that("PubTator mutation routes require Administrator role", {
  with_test_db_transaction({
    mutation_routes <- c(
      "^#\\*\\s+@post\\s+/pubtator/backfill-genes\\s*$",
      "^#\\*\\s+@post\\s+/pubtator/update\\s*$",
      "^#\\*\\s+@post\\s+/pubtator/update/submit\\s*$",
      "^#\\*\\s+@post\\s+/pubtator/clear-cache\\s*$"
    )
    for (route in mutation_routes) {
      body <- publication_body_blob(route)
      expect_match(body, 'require_role\\(req, res, "Administrator"\\)')
    }
  })
})

test_that("PubTator mutation routes are not globally allowlisted", {
  source(file.path(get_api_dir(), "core", "middleware.R"), local = TRUE)
  forbidden <- c(
    "/api/publication/pubtator/backfill-genes",
    "/api/publication/pubtator/update",
    "/api/publication/pubtator/update/submit",
    "/api/publication/pubtator/clear-cache"
  )
  expect_false(any(forbidden %in% AUTH_ALLOWLIST))
  expect_true("/api/publication/pubtator/cache-status" %in% AUTH_ALLOWLIST)
})

test_that("PubTator cache-status and update routes validate required query input", {
  with_test_db_transaction({
    cache_body <- publication_body_blob("^#\\*\\s+@get\\s+/pubtator/cache-status\\s*$")
    update_body <- publication_body_blob("^#\\*\\s+@post\\s+/pubtator/update\\s*$")
    submit_body <- publication_body_blob("^#\\*\\s+@post\\s+/pubtator/update/submit\\s*$")
    expect_match(cache_body, "query")
    expect_match(cache_body, "400")
    expect_match(update_body, "query")
    expect_match(update_body, "400")
    expect_match(submit_body, "query")
    expect_match(submit_body, "400")
  })
})

test_that("PubTator async submit keeps duplicate-job response path", {
  with_test_db_transaction({
    submit_body <- publication_body_blob("^#\\*\\s+@post\\s+/pubtator/update/submit\\s*$")
    expect_match(submit_body, "check_duplicate_job")
    expect_match(submit_body, "409")
    expect_match(submit_body, "already running")
  })
})
