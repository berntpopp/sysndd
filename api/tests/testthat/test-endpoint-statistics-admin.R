# tests/testthat/test-endpoint-statistics-admin.R
#
# Phase C unit C7 (read-only batch) — route-surface and handler-shape tests
# for the Administrator-gated routes of api/endpoints/statistics_endpoints.R:
# /updates, /rereview, /updated_reviews, /updated_statuses,
# /contributor_leaderboard, and /rereview_leaderboard.
#
# Split out of test-endpoint-statistics.R (which keeps the four public
# routes: /category_count, /news, /entities_over_time, /publication_stats)
# to keep both files under the repo's 600-line file-size ceiling; the split
# mirrors the production public/admin service split
# (api/services/statistics-public-endpoint-service.R vs
# api/services/statistics-admin-endpoint-service.R, #346 Wave 3 Task 8).
#
# Testing strategy matches test-endpoint-search.R and test-endpoint-list.R:
# parse the endpoint file, extract each handler body, and assert the body
# references the expected backing table + response shape. Wrapped in
# with_test_db_transaction() so future handler invocations stay transactional.
#
# The `require_role(req, res, "Administrator")` gate stays in the endpoint
# shell (unmoved by the Wave 3 extraction), so each route's "permission path"
# test keeps reading the shell's handler body directly. Each route's "happy
# path" test asserts the shell delegates to the correct svc_statistics_admin_*
# function AND reads the backing-table/response-shape assertions from that
# function's own source via read_service_source().

library(testthat)

# -----------------------------------------------------------------------------
# Shared helpers (duplicated from test-endpoint-statistics.R by design — see
# test-endpoint-search.R header for the repo-wide rationale).
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

stats_admin_service_path <- function() {
  file.path(get_api_dir(), "services", "statistics-admin-endpoint-service.R")
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
# Route 4/10 — @get /updates  (ndd_entity, Administrator-gated)
# =============================================================================

test_that("GET /updates — happy path: decorator + handler surface", {
  with_test_db_transaction({
    src <- readLines(stats_file_path(), warn = FALSE)
    decorators <- grep("^#\\*\\s+@get\\s+/updates\\s*$", src, value = TRUE)
    expect_true(
      length(decorators) >= 1,
      info = "statistics_endpoints.R must expose `#* @get /updates`."
    )

    env <- make_stats_sandbox()
    handler <- extract_plumber_handler(
      stats_file_path(),
      decorator_regex = "^#\\*\\s+@get\\s+/updates\\s*$",
      envir = env
    )
    expect_true(is.function(handler))

    formals_names <- names(formals(handler))
    expect_true("start_date" %in% formals_names)
    expect_true("end_date" %in% formals_names)

    body_txt <- handler_body_text(handler)
    expect_match(body_txt, "svc_statistics_admin_updates",
                 info = "updates must delegate to svc_statistics_admin_updates")

    service_txt <- read_service_source(stats_admin_service_path(), "svc_statistics_admin_updates")
    expect_match(service_txt, "ndd_entity",
                 info = "svc_statistics_admin_updates must read from ndd_entity")
    expect_match(service_txt, "total_new_entities",
                 info = "svc_statistics_admin_updates must return total_new_entities in list shape")
  })
})

test_that("GET /updates — permission path: require_role Administrator", {
  with_test_db_transaction({
    env <- make_stats_sandbox()
    handler <- extract_plumber_handler(
      stats_file_path(),
      decorator_regex = "^#\\*\\s+@get\\s+/updates\\s*$",
      envir = env
    )
    body_txt <- handler_body_text(handler)
    expect_match(body_txt, "require_role\\([^)]*\"Administrator\"",
                 info = "updates must gate on require_role(..., \"Administrator\")")
  })
})

# =============================================================================
# Route 5/10 — @get /rereview
# =============================================================================

test_that("GET /rereview — happy path: decorator + handler surface", {
  with_test_db_transaction({
    src <- readLines(stats_file_path(), warn = FALSE)
    decorators <- grep("^#\\*\\s+@get\\s+/rereview\\s*$", src, value = TRUE)
    expect_true(
      length(decorators) >= 1,
      info = "statistics_endpoints.R must expose `#* @get /rereview`."
    )

    env <- make_stats_sandbox()
    handler <- extract_plumber_handler(
      stats_file_path(),
      decorator_regex = "^#\\*\\s+@get\\s+/rereview\\s*$",
      envir = env
    )
    expect_true(is.function(handler))

    formals_names <- names(formals(handler))
    expect_true("start_date" %in% formals_names)
    expect_true("end_date" %in% formals_names)

    body_txt <- handler_body_text(handler)
    expect_match(body_txt, "svc_statistics_admin_rereview\\(",
                 info = "rereview must delegate to svc_statistics_admin_rereview")

    service_txt <- read_service_source(stats_admin_service_path(), "svc_statistics_admin_rereview")
    expect_match(service_txt, "re_review_entity_connect",
                 info = "svc_statistics_admin_rereview must read from re_review_entity_connect")
    expect_match(service_txt, "total_rereviews",
                 info = "svc_statistics_admin_rereview must return total_rereviews")
  })
})

test_that("GET /rereview — permission path: require_role Administrator", {
  with_test_db_transaction({
    env <- make_stats_sandbox()
    handler <- extract_plumber_handler(
      stats_file_path(),
      decorator_regex = "^#\\*\\s+@get\\s+/rereview\\s*$",
      envir = env
    )
    body_txt <- handler_body_text(handler)
    expect_match(body_txt, "require_role\\([^)]*\"Administrator\"",
                 info = "rereview must gate on require_role(..., \"Administrator\")")
  })
})

# =============================================================================
# Route 6/10 — @get /updated_reviews
# =============================================================================

test_that("GET /updated_reviews — happy path: decorator + handler surface", {
  with_test_db_transaction({
    src <- readLines(stats_file_path(), warn = FALSE)
    decorators <- grep("^#\\*\\s+@get\\s+/updated_reviews\\s*$",
                       src, value = TRUE)
    expect_true(
      length(decorators) >= 1,
      info = "statistics_endpoints.R must expose `#* @get /updated_reviews`."
    )

    env <- make_stats_sandbox()
    handler <- extract_plumber_handler(
      stats_file_path(),
      decorator_regex = "^#\\*\\s+@get\\s+/updated_reviews\\s*$",
      envir = env
    )
    expect_true(is.function(handler))

    formals_names <- names(formals(handler))
    expect_true("start_date" %in% formals_names)
    expect_true("end_date" %in% formals_names)

    body_txt <- handler_body_text(handler)
    expect_match(body_txt, "svc_statistics_admin_updated_reviews",
                 info = "updated_reviews must delegate to svc_statistics_admin_updated_reviews")

    service_txt <- read_service_source(stats_admin_service_path(), "svc_statistics_admin_updated_reviews")
    expect_match(service_txt, "ndd_entity_review",
                 info = "svc_statistics_admin_updated_reviews must read from ndd_entity_review")
    expect_match(service_txt, "total_updated_reviews",
                 info = "svc_statistics_admin_updated_reviews must return total_updated_reviews")
  })
})

test_that("GET /updated_reviews — permission path: require_role Administrator", {
  with_test_db_transaction({
    env <- make_stats_sandbox()
    handler <- extract_plumber_handler(
      stats_file_path(),
      decorator_regex = "^#\\*\\s+@get\\s+/updated_reviews\\s*$",
      envir = env
    )
    body_txt <- handler_body_text(handler)
    expect_match(body_txt, "require_role\\([^)]*\"Administrator\"",
                 info = "updated_reviews must gate on require_role(..., \"Administrator\")")
  })
})

# =============================================================================
# Route 7/10 — @get /updated_statuses
# =============================================================================

test_that("GET /updated_statuses — happy path: decorator + handler surface", {
  with_test_db_transaction({
    src <- readLines(stats_file_path(), warn = FALSE)
    decorators <- grep("^#\\*\\s+@get\\s+/updated_statuses\\s*$",
                       src, value = TRUE)
    expect_true(
      length(decorators) >= 1,
      info = "statistics_endpoints.R must expose `#* @get /updated_statuses`."
    )

    env <- make_stats_sandbox()
    handler <- extract_plumber_handler(
      stats_file_path(),
      decorator_regex = "^#\\*\\s+@get\\s+/updated_statuses\\s*$",
      envir = env
    )
    expect_true(is.function(handler))

    formals_names <- names(formals(handler))
    expect_true("start_date" %in% formals_names)
    expect_true("end_date" %in% formals_names)

    body_txt <- handler_body_text(handler)
    expect_match(body_txt, "svc_statistics_admin_updated_statuses",
                 info = "updated_statuses must delegate to svc_statistics_admin_updated_statuses")

    service_txt <- read_service_source(stats_admin_service_path(), "svc_statistics_admin_updated_statuses")
    expect_match(service_txt, "ndd_entity_status",
                 info = "svc_statistics_admin_updated_statuses must read from ndd_entity_status")
    expect_match(service_txt, "total_updated_statuses",
                 info = "svc_statistics_admin_updated_statuses must return total_updated_statuses")
  })
})

test_that("GET /updated_statuses — permission path: require_role Administrator", {
  with_test_db_transaction({
    env <- make_stats_sandbox()
    handler <- extract_plumber_handler(
      stats_file_path(),
      decorator_regex = "^#\\*\\s+@get\\s+/updated_statuses\\s*$",
      envir = env
    )
    body_txt <- handler_body_text(handler)
    expect_match(body_txt, "require_role\\([^)]*\"Administrator\"",
                 info = "updated_statuses must gate on require_role(..., \"Administrator\")")
  })
})

# =============================================================================
# Route 9/10 — @get /contributor_leaderboard
# =============================================================================

test_that("GET /contributor_leaderboard — happy path: decorator + handler surface", {
  with_test_db_transaction({
    src <- readLines(stats_file_path(), warn = FALSE)
    decorators <- grep("^#\\*\\s+@get\\s+/contributor_leaderboard\\s*$",
                       src, value = TRUE)
    expect_true(
      length(decorators) >= 1,
      info = "statistics_endpoints.R must expose `#* @get /contributor_leaderboard`."
    )

    env <- make_stats_sandbox()
    handler <- extract_plumber_handler(
      stats_file_path(),
      decorator_regex = "^#\\*\\s+@get\\s+/contributor_leaderboard\\s*$",
      envir = env
    )
    expect_true(is.function(handler))

    formals_names <- names(formals(handler))
    expect_true("top" %in% formals_names)
    expect_true("start_date" %in% formals_names)
    expect_true("end_date" %in% formals_names)
    expect_true("scope" %in% formals_names)

    body_txt <- handler_body_text(handler)
    expect_match(body_txt, "svc_statistics_admin_contributor_leaderboard",
                 info = "contributor_leaderboard must delegate to svc_statistics_admin_contributor_leaderboard")

    service_txt <- read_service_source(
      stats_admin_service_path(), "svc_statistics_admin_contributor_leaderboard"
    )
    expect_match(service_txt, "ndd_entity_status",
                 info = "svc_statistics_admin_contributor_leaderboard must join on ndd_entity_status")
    expect_match(service_txt, "status_user_id",
                 info = "svc_statistics_admin_contributor_leaderboard must aggregate on status_user_id")
  })
})

test_that("GET /contributor_leaderboard — permission path: require_role Administrator", {
  with_test_db_transaction({
    env <- make_stats_sandbox()
    handler <- extract_plumber_handler(
      stats_file_path(),
      decorator_regex = "^#\\*\\s+@get\\s+/contributor_leaderboard\\s*$",
      envir = env
    )
    body_txt <- handler_body_text(handler)
    expect_match(body_txt, "require_role\\([^)]*\"Administrator\"",
                 info = "contributor_leaderboard must gate on require_role(..., \"Administrator\")")
  })
})

# =============================================================================
# Route 10/10 — @get /rereview_leaderboard
# =============================================================================

test_that("GET /rereview_leaderboard — happy path: decorator + handler surface", {
  with_test_db_transaction({
    src <- readLines(stats_file_path(), warn = FALSE)
    decorators <- grep("^#\\*\\s+@get\\s+/rereview_leaderboard\\s*$",
                       src, value = TRUE)
    expect_true(
      length(decorators) >= 1,
      info = "statistics_endpoints.R must expose `#* @get /rereview_leaderboard`."
    )

    env <- make_stats_sandbox()
    handler <- extract_plumber_handler(
      stats_file_path(),
      decorator_regex = "^#\\*\\s+@get\\s+/rereview_leaderboard\\s*$",
      envir = env
    )
    expect_true(is.function(handler))

    formals_names <- names(formals(handler))
    expect_true("top" %in% formals_names)
    expect_true("start_date" %in% formals_names)
    expect_true("end_date" %in% formals_names)
    expect_true("scope" %in% formals_names)

    body_txt <- handler_body_text(handler)
    expect_match(body_txt, "svc_statistics_admin_rereview_leaderboard",
                 info = "rereview_leaderboard must delegate to svc_statistics_admin_rereview_leaderboard")

    service_txt <- read_service_source(
      stats_admin_service_path(), "svc_statistics_admin_rereview_leaderboard"
    )
    expect_match(service_txt, "re_review_entity_connect",
                 info = "svc_statistics_admin_rereview_leaderboard must read from re_review_entity_connect")
    expect_match(service_txt, "re_review_assignment",
                 info = "svc_statistics_admin_rereview_leaderboard must join on re_review_assignment")
    expect_match(service_txt, "submitted_count",
                 info = "svc_statistics_admin_rereview_leaderboard must surface submitted_count aggregate")
  })
})

test_that("GET /rereview_leaderboard — permission path: require_role Administrator", {
  with_test_db_transaction({
    env <- make_stats_sandbox()
    handler <- extract_plumber_handler(
      stats_file_path(),
      decorator_regex = "^#\\*\\s+@get\\s+/rereview_leaderboard\\s*$",
      envir = env
    )
    body_txt <- handler_body_text(handler)
    expect_match(body_txt, "require_role\\([^)]*\"Administrator\"",
                 info = "rereview_leaderboard must gate on require_role(..., \"Administrator\")")
  })
})
