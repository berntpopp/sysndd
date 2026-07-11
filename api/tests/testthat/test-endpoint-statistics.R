# tests/testthat/test-endpoint-statistics.R
#
# Phase C unit C7 (read-only batch) — route-surface and handler-shape tests
# for the PUBLIC routes of api/endpoints/statistics_endpoints.R (no
# require_role() gate): /category_count, /news, /entities_over_time, and
# /publication_stats.
#
# Scope rule (plan §3 Phase C.C7 exit criterion #5, LOCKED): one test_that()
# block per HTTP method per route.
#
# Testing strategy matches test-endpoint-search.R and test-endpoint-list.R:
# parse the endpoint file, extract each handler body, and assert the body
# references the expected backing table + response shape. Wrapped in
# with_test_db_transaction() so future handler invocations stay transactional.
#
# #346 Wave 3 Task 8 extracted every handler body into
# api/services/statistics-public-endpoint-service.R (public routes, covered
# here) and api/services/statistics-admin-endpoint-service.R
# (Administrator-gated routes, covered by the sibling
# test-endpoint-statistics-admin.R — split out to keep both files under the
# repo's 600-line file-size ceiling, mirroring the production public/admin
# service split); the endpoint shells now only keep the decorator, formals,
# and a one-line delegation call. Each route's "happy path" test below now
# asserts the delegation call AND reads the backing-table/response-shape
# assertions from the extracted svc_statistics_* function's own source via
# read_service_source() — the route-surface/formals assertions stay pointed
# at the shell.

library(testthat)

# -----------------------------------------------------------------------------
# Shared helpers (duplicated from test-endpoint-statistics-admin.R by design —
# see test-endpoint-search.R header for the repo-wide rationale).
# -----------------------------------------------------------------------------

extract_plumber_handler <- function(file_path, decorator_regex, envir) {
  src_lines <- readLines(file_path, warn = FALSE)
  dec_line <- grep(decorator_regex, src_lines)
  if (length(dec_line) == 0L) {
    stop("Decorator not found: ", decorator_regex)
  }
  dec_line <- dec_line[[1L]]

  parsed <- parse(file = file_path, keep.source = TRUE)
  srcrefs <- attr(parsed, "srcref")
  if (is.null(srcrefs)) {
    stop("Unable to read source refs for ", file_path)
  }

  handler_expr <- NULL
  for (i in seq_along(parsed)) {
    start_line <- srcrefs[[i]][1L]
    if (start_line > dec_line) {
      handler_expr <- parsed[[i]]
      break
    }
  }
  if (is.null(handler_expr)) {
    stop("No top-level expression found after decorator line ", dec_line)
  }

  eval(handler_expr, envir = envir)
}

stats_file_path <- function() {
  file.path(get_api_dir(), "endpoints", "statistics_endpoints.R")
}

stats_public_service_path <- function() {
  file.path(get_api_dir(), "services", "statistics-public-endpoint-service.R")
}

# Read the deparsed source text of a single top-level `fn_name <- function(...) {...}`
# definition out of a service file (mirrors extract_plumber_handler()'s
# parse-then-locate approach, scoped to one named function instead of one
# decorator so a match can't spuriously come from a sibling svc_ function in
# the same file). Falls back to the whole-file text when fn_name is omitted.
read_service_source <- function(file_path, fn_name = NULL) {
  if (is.null(fn_name)) {
    return(paste(readLines(file_path, warn = FALSE), collapse = "\n"))
  }

  parsed <- parse(file = file_path, keep.source = TRUE)
  for (expr in as.list(parsed)) {
    if (is.call(expr) && identical(expr[[1]], as.name("<-")) &&
        length(expr) >= 3 && identical(as.character(expr[[2]]), fn_name)) {
      return(paste(deparse(expr[[3]]), collapse = "\n"))
    }
  }
  stop("Service function not found: ", fn_name, " in ", file_path)
}

make_stats_sandbox <- function() {
  env <- new.env(parent = globalenv())
  env$pool <- "STUB_POOL"
  # Stub helpers used in statistics handlers so function literals eval cleanly.
  env$generate_stat_tibble_mem <- function(...) NULL
  env$generate_gene_news_tibble_mem <- function(...) NULL
  env$generate_filter_expressions <- function(...) ""
  env$require_role <- function(...) NULL
  env
}

handler_body_text <- function(handler_fn) {
  paste(deparse(body(handler_fn)), collapse = "\n")
}

# =============================================================================
# Route 1/10 — @get /category_count  (generate_stat_tibble_mem)
# =============================================================================

test_that("GET /category_count — happy path: decorator + handler surface", {
  with_test_db_transaction({
    src <- readLines(stats_file_path(), warn = FALSE)
    decorators <- grep("^#\\*\\s+@get\\s+/category_count\\s*$", src, value = TRUE)
    expect_true(
      length(decorators) >= 1,
      info = "statistics_endpoints.R must expose `#* @get /category_count`."
    )

    env <- make_stats_sandbox()
    handler <- extract_plumber_handler(
      stats_file_path(),
      decorator_regex = "^#\\*\\s+@get\\s+/category_count\\s*$",
      envir = env
    )
    expect_true(is.function(handler))

    formals_names <- names(formals(handler))
    expect_true("sort" %in% formals_names)
    expect_true("type" %in% formals_names)

    body_txt <- handler_body_text(handler)
    expect_match(body_txt, "svc_statistics_category_count",
                 info = "category_count must delegate to svc_statistics_category_count")

    service_txt <- read_service_source(stats_public_service_path(), "svc_statistics_category_count")
    expect_match(service_txt, "generate_stat_tibble_mem",
                 info = "svc_statistics_category_count must delegate to generate_stat_tibble_mem")
  })
})

test_that("GET /category_count — empty-result path: default sort + type", {
  with_test_db_transaction({
    env <- make_stats_sandbox()
    handler <- extract_plumber_handler(
      stats_file_path(),
      decorator_regex = "^#\\*\\s+@get\\s+/category_count\\s*$",
      envir = env
    )
    # Defaults must be "category_id,-n" and "gene" (the stat cache relies on
    # these being stable keys).
    sort_default <- eval(formals(handler)$sort)
    type_default <- eval(formals(handler)$type)
    expect_equal(sort_default, "category_id,-n")
    expect_equal(type_default, "gene")
  })
})

# =============================================================================
# Route 2/10 — @get /news  (generate_gene_news_tibble_mem)
# =============================================================================

test_that("GET /news — happy path: decorator + handler surface", {
  with_test_db_transaction({
    src <- readLines(stats_file_path(), warn = FALSE)
    decorators <- grep("^#\\*\\s+@get\\s+/news\\s*$", src, value = TRUE)
    expect_true(
      length(decorators) >= 1,
      info = "statistics_endpoints.R must expose `#* @get /news`."
    )

    env <- make_stats_sandbox()
    handler <- extract_plumber_handler(
      stats_file_path(),
      decorator_regex = "^#\\*\\s+@get\\s+/news\\s*$",
      envir = env
    )
    expect_true(is.function(handler))

    formals_names <- names(formals(handler))
    expect_true("n" %in% formals_names)

    body_txt <- handler_body_text(handler)
    expect_match(body_txt, "svc_statistics_gene_news",
                 info = "news must delegate to svc_statistics_gene_news")

    service_txt <- read_service_source(stats_public_service_path(), "svc_statistics_gene_news")
    expect_match(service_txt, "generate_gene_news_tibble_mem",
                 info = "svc_statistics_gene_news must delegate to generate_gene_news_tibble_mem")
  })
})

test_that("GET /news — empty-result path: default n = 5", {
  with_test_db_transaction({
    env <- make_stats_sandbox()
    handler <- extract_plumber_handler(
      stats_file_path(),
      decorator_regex = "^#\\*\\s+@get\\s+/news\\s*$",
      envir = env
    )
    n_default <- eval(formals(handler)$n)
    expect_equal(n_default, 5)
  })
})

# =============================================================================
# Route 3/10 — @get /entities_over_time  (ndd_entity_view + summarize_by_time)
# =============================================================================

test_that("GET /entities_over_time — happy path: decorator + handler surface", {
  with_test_db_transaction({
    src <- readLines(stats_file_path(), warn = FALSE)
    decorators <- grep("^#\\*\\s+@get\\s+/entities_over_time\\s*$",
                       src, value = TRUE)
    expect_true(
      length(decorators) >= 1,
      info = "statistics_endpoints.R must expose `#* @get /entities_over_time`."
    )

    env <- make_stats_sandbox()
    handler <- extract_plumber_handler(
      stats_file_path(),
      decorator_regex = "^#\\*\\s+@get\\s+/entities_over_time\\s*$",
      envir = env
    )
    expect_true(is.function(handler))

    formals_names <- names(formals(handler))
    expect_true("aggregate" %in% formals_names)
    expect_true("group" %in% formals_names)
    expect_true("summarize" %in% formals_names)
    expect_true("filter" %in% formals_names)

    body_txt <- handler_body_text(handler)
    expect_match(body_txt, "svc_statistics_entities_over_time",
                 info = "entities_over_time must delegate to svc_statistics_entities_over_time")

    service_txt <- read_service_source(stats_public_service_path(), "svc_statistics_entities_over_time")
    expect_match(service_txt, "ndd_entity_view",
                 info = "svc_statistics_entities_over_time must read from ndd_entity_view")
    expect_match(service_txt, "summarize_by_time",
                 info = "svc_statistics_entities_over_time must aggregate via summarize_by_time")
  })
})

test_that("GET /entities_over_time — empty/400 path: aggregate/group validation", {
  with_test_db_transaction({
    env <- make_stats_sandbox()
    handler <- extract_plumber_handler(
      stats_file_path(),
      decorator_regex = "^#\\*\\s+@get\\s+/entities_over_time\\s*$",
      envir = env
    )
    service_txt <- read_service_source(stats_public_service_path(), "svc_statistics_entities_over_time")

    # 400 guard: aggregate must be in {entity_id, symbol}, group must be in
    # {category, inheritance_filter, inheritance_multiple}. Plus the
    # aggregate=entity_id + group=inheritance_multiple combo is rejected.
    expect_match(service_txt, "res\\$status\\s*<-\\s*400",
                 info = "svc_statistics_entities_over_time must set 400 on invalid aggregate/group")
    expect_match(service_txt, "\"entity_id\"",
                 info = "aggregate allowlist includes entity_id")
    expect_match(service_txt, "\"symbol\"",
                 info = "aggregate allowlist includes symbol")
    expect_match(service_txt, "inheritance_multiple",
                 info = "svc_statistics_entities_over_time must special-case inheritance_multiple")
  })
})

# =============================================================================
# Route 8/10 — @get /publication_stats
# =============================================================================

test_that("GET /publication_stats — happy path: decorator + handler surface", {
  with_test_db_transaction({
    src <- readLines(stats_file_path(), warn = FALSE)
    decorators <- grep("^#\\*\\s+@get\\s+/publication_stats\\s*$",
                       src, value = TRUE)
    expect_true(
      length(decorators) >= 1,
      info = "statistics_endpoints.R must expose `#* @get /publication_stats`."
    )

    env <- make_stats_sandbox()
    handler <- extract_plumber_handler(
      stats_file_path(),
      decorator_regex = "^#\\*\\s+@get\\s+/publication_stats\\s*$",
      envir = env
    )
    expect_true(is.function(handler))

    formals_names <- names(formals(handler))
    expect_true("time_aggregate" %in% formals_names)
    expect_true("filter" %in% formals_names)
    expect_true("min_journal_count" %in% formals_names)
    expect_true("min_lastname_count" %in% formals_names)
    expect_true("min_keyword_count" %in% formals_names)

    body_txt <- handler_body_text(handler)
    expect_match(body_txt, "svc_statistics_publication_stats",
                 info = "publication_stats must delegate to svc_statistics_publication_stats")

    service_txt <- read_service_source(stats_public_service_path(), "svc_statistics_publication_stats")
    expect_match(service_txt, "publication",
                 info = "svc_statistics_publication_stats must read from publication table")
    expect_match(service_txt, "stats_list",
                 info = "svc_statistics_publication_stats must build stats_list response")
  })
})

test_that("GET /publication_stats — empty-result path: min-count thresholds + 200", {
  with_test_db_transaction({
    env <- make_stats_sandbox()
    handler <- extract_plumber_handler(
      stats_file_path(),
      decorator_regex = "^#\\*\\s+@get\\s+/publication_stats\\s*$",
      envir = env
    )
    service_txt <- read_service_source(stats_public_service_path(), "svc_statistics_publication_stats")

    # Empty / low-count path: threshold filters drop rows below the min
    # counts; service still sets res$status <- 200 and returns stats_list.
    expect_match(service_txt, "min_journal_count",
                 info = "svc_statistics_publication_stats must honour min_journal_count threshold")
    expect_match(service_txt, "min_keyword_count",
                 info = "svc_statistics_publication_stats must honour min_keyword_count threshold")
    expect_match(service_txt, "res\\$status\\s*<-\\s*200",
                 info = "svc_statistics_publication_stats must set res$status <- 200 on empty results")
  })
})
