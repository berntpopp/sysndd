# tests/testthat/test-endpoint-statistics.R
#
# Phase C unit C7 (read-only batch) — route-surface and handler-shape tests
# for api/endpoints/statistics_endpoints.R.
#
# Scope rule (plan §3 Phase C.C7 exit criterion #5, LOCKED): one test_that()
# block per HTTP method per route. `statistics_endpoints.R` exposes ten @get
# routes, so this file has 20 test_that blocks (happy path + empty/auth path
# per route).
#
# Testing strategy matches test-endpoint-search.R and test-endpoint-list.R:
# parse the endpoint file, extract each handler body, and assert the body
# references the expected backing table + response shape. Wrapped in
# with_test_db_transaction() so future handler invocations stay transactional.

library(testthat)

# -----------------------------------------------------------------------------
# Shared helpers (duplicated by design — see test-endpoint-search.R header).
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
    expect_match(body_txt, "generate_stat_tibble_mem",
                 info = "category_count must delegate to generate_stat_tibble_mem")
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
    expect_match(body_txt, "generate_gene_news_tibble_mem",
                 info = "news must delegate to generate_gene_news_tibble_mem")
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
    expect_match(body_txt, "ndd_entity_view",
                 info = "entities_over_time must read from ndd_entity_view")
    expect_match(body_txt, "summarize_by_time",
                 info = "entities_over_time must aggregate via summarize_by_time")
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
    body_txt <- handler_body_text(handler)

    # 400 guard: aggregate must be in {entity_id, symbol}, group must be in
    # {category, inheritance_filter, inheritance_multiple}. Plus the
    # aggregate=entity_id + group=inheritance_multiple combo is rejected.
    expect_match(body_txt, "res\\$status\\s*<-\\s*400",
                 info = "entities_over_time must set 400 on invalid aggregate/group")
    expect_match(body_txt, "\"entity_id\"",
                 info = "aggregate allowlist includes entity_id")
    expect_match(body_txt, "\"symbol\"",
                 info = "aggregate allowlist includes symbol")
    expect_match(body_txt, "inheritance_multiple",
                 info = "entities_over_time must special-case inheritance_multiple")
  })
})

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
    expect_match(body_txt, "ndd_entity",
                 info = "updates must read from ndd_entity")
    expect_match(body_txt, "total_new_entities",
                 info = "updates must return total_new_entities in list shape")
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
    expect_match(body_txt, "re_review_entity_connect",
                 info = "rereview must read from re_review_entity_connect")
    expect_match(body_txt, "total_rereviews",
                 info = "rereview must return total_rereviews")
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
    expect_match(body_txt, "ndd_entity_review",
                 info = "updated_reviews must read from ndd_entity_review")
    expect_match(body_txt, "total_updated_reviews",
                 info = "updated_reviews must return total_updated_reviews")
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
    expect_match(body_txt, "ndd_entity_status",
                 info = "updated_statuses must read from ndd_entity_status")
    expect_match(body_txt, "total_updated_statuses",
                 info = "updated_statuses must return total_updated_statuses")
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
    expect_match(body_txt, "publication",
                 info = "publication_stats must read from publication table")
    expect_match(body_txt, "stats_list",
                 info = "publication_stats must build stats_list response")
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
    body_txt <- handler_body_text(handler)

    # Empty / low-count path: threshold filters drop rows below the min
    # counts; handler still sets res$status <- 200 and returns stats_list.
    expect_match(body_txt, "min_journal_count",
                 info = "publication_stats must honour min_journal_count threshold")
    expect_match(body_txt, "min_keyword_count",
                 info = "publication_stats must honour min_keyword_count threshold")
    expect_match(body_txt, "res\\$status\\s*<-\\s*200",
                 info = "publication_stats must set res$status <- 200 on empty results")
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
    expect_match(body_txt, "ndd_entity_status",
                 info = "contributor_leaderboard must join on ndd_entity_status")
    expect_match(body_txt, "status_user_id",
                 info = "contributor_leaderboard must aggregate on status_user_id")
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
    expect_match(body_txt, "re_review_entity_connect",
                 info = "rereview_leaderboard must read from re_review_entity_connect")
    expect_match(body_txt, "re_review_assignment",
                 info = "rereview_leaderboard must join on re_review_assignment")
    expect_match(body_txt, "submitted_count",
                 info = "rereview_leaderboard must surface submitted_count aggregate")
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
