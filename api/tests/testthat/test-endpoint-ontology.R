# tests/testthat/test-endpoint-ontology.R
#
# Phase C unit C7 (read-only batch) — route-surface and handler-shape tests
# for api/endpoints/ontology_endpoints.R.
#
# Scope rule (plan §3 Phase C.C7 exit criterion #5, LOCKED): one test_that()
# block per HTTP method per route. `ontology_endpoints.R` exposes three
# routes — two @get (ontology lookup, variant table) and one @put (variant
# update) — for 6 test_that blocks total. The @put is included even though
# this file lives in the "read-only batch": exit criterion #5 is about the
# file scope, not the method; C8's write-batch does not own this file.
#
# Testing strategy — same as the other C7 files: parse, extract handler,
# assert body/signature shape, all wrapped in with_test_db_transaction().

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

ontology_file_path <- function() {
  file.path(get_api_dir(), "endpoints", "ontology_endpoints.R")
}

make_ontology_sandbox <- function() {
  env <- new.env(parent = globalenv())
  env$pool <- "STUB_POOL"
  env$require_role <- function(...) NULL
  env$generate_sort_expressions <- function(...) ""
  env$generate_filter_expressions <- function(...) ""
  env$generate_cursor_pag_inf_safe <- function(...) list(
    links = list(), meta = list(), data = list()
  )
  env$db_execute_query <- function(...) data.frame()
  env$db_execute_statement <- function(...) TRUE
  env
}

handler_body_text <- function(handler_fn) {
  paste(deparse(body(handler_fn)), collapse = "\n")
}

# =============================================================================
# Route 1/3 — @get <ontology_input>  (disease ontology lookup)
# =============================================================================

test_that("GET <ontology_input> — happy path: decorator + handler surface", {
  with_test_db_transaction({
    src <- readLines(ontology_file_path(), warn = FALSE)
    decorators <- grep("^#\\*\\s+@get\\s+<ontology_input>\\s*$",
                       src, value = TRUE)
    expect_true(
      length(decorators) >= 1,
      info = "ontology_endpoints.R must expose `#* @get <ontology_input>`."
    )

    env <- make_ontology_sandbox()
    handler <- extract_plumber_handler(
      ontology_file_path(),
      decorator_regex = "^#\\*\\s+@get\\s+<ontology_input>\\s*$",
      envir = env
    )
    expect_true(is.function(handler))

    formals_names <- names(formals(handler))
    expect_true("ontology_input" %in% formals_names)
    expect_true("input_type" %in% formals_names)

    body_txt <- handler_body_text(handler)
    expect_match(body_txt, "disease_ontology_set",
                 info = "ontology lookup must read from disease_ontology_set")
    expect_match(body_txt, "mode_of_inheritance_list",
                 info = "ontology lookup must join with mode_of_inheritance_list")
  })
})

test_that("GET <ontology_input> — empty-result path: pivot_longer filter fallback", {
  with_test_db_transaction({
    env <- make_ontology_sandbox()
    handler <- extract_plumber_handler(
      ontology_file_path(),
      decorator_regex = "^#\\*\\s+@get\\s+<ontology_input>\\s*$",
      envir = env
    )
    body_txt <- handler_body_text(handler)

    # Empty-result path: the handler pivots disease_ontology_set long so that
    # both disease_ontology_id_search and disease_ontology_name_search get
    # compared against the input. If nothing matches, the filter simply
    # returns an empty tibble that still round-trips through str_split.
    expect_match(body_txt, "pivot_longer",
                 info = "ontology lookup must pivot id/name columns into rows")
    expect_match(body_txt, "disease_ontology_id_search",
                 info = "ontology lookup must compare against disease_ontology_id_search")
    expect_match(body_txt, "disease_ontology_name_search",
                 info = "ontology lookup must compare against disease_ontology_name_search")
    expect_match(body_txt, "str_split",
                 info = "ontology lookup must round-trip nullable fields through str_split")
  })
})

# =============================================================================
# Route 2/3 — @get variant/table  (Administrator-gated)
# =============================================================================

test_that("GET variant/table — happy path: decorator + handler + pagination shape", {
  with_test_db_transaction({
    src <- readLines(ontology_file_path(), warn = FALSE)
    decorators <- grep("^#\\*\\s+@get\\s+variant/table\\s*$",
                       src, value = TRUE)
    expect_true(
      length(decorators) >= 1,
      info = "ontology_endpoints.R must expose `#* @get variant/table`."
    )

    env <- make_ontology_sandbox()
    handler <- extract_plumber_handler(
      ontology_file_path(),
      decorator_regex = "^#\\*\\s+@get\\s+variant/table\\s*$",
      envir = env
    )
    expect_true(is.function(handler))

    formals_names <- names(formals(handler))
    expect_true("filter" %in% formals_names)
    expect_true("sort" %in% formals_names)
    expect_true("page_after" %in% formals_names)
    expect_true("page_size" %in% formals_names)
    expect_true("fspec" %in% formals_names)

    body_txt <- handler_body_text(handler)
    expect_match(body_txt, "variation_ontology_list",
                 info = "variant/table must read from variation_ontology_list")
    expect_match(body_txt, "generate_cursor_pag_inf_safe",
                 info = "variant/table must paginate via generate_cursor_pag_inf_safe")
    expect_match(body_txt, "links\\s*=\\s*pagination_info\\$links",
                 info = "variant/table must return pagination links")
    expect_match(body_txt, "fspec_parsed",
                 info = "variant/table must build fspec metadata for BVT")
  })
})

test_that("GET variant/table — permission path: require_role Administrator", {
  with_test_db_transaction({
    env <- make_ontology_sandbox()
    handler <- extract_plumber_handler(
      ontology_file_path(),
      decorator_regex = "^#\\*\\s+@get\\s+variant/table\\s*$",
      envir = env
    )
    body_txt <- handler_body_text(handler)
    expect_match(body_txt, "require_role\\([^)]*\"Administrator\"",
                 info = "variant/table must gate on require_role(..., \"Administrator\")")
  })
})

# =============================================================================
# Route 3/3 — @put variant/update  (Administrator-gated write)
# =============================================================================

test_that("PUT variant/update — happy path: decorator + handler surface", {
  with_test_db_transaction({
    src <- readLines(ontology_file_path(), warn = FALSE)
    decorators <- grep("^#\\*\\s+@put\\s+variant/update\\s*$",
                       src, value = TRUE)
    expect_true(
      length(decorators) >= 1,
      info = "ontology_endpoints.R must expose `#* @put variant/update`."
    )

    env <- make_ontology_sandbox()
    handler <- extract_plumber_handler(
      ontology_file_path(),
      decorator_regex = "^#\\*\\s+@put\\s+variant/update\\s*$",
      envir = env
    )
    expect_true(is.function(handler))

    formals_names <- names(formals(handler))
    expect_true("req" %in% formals_names)
    expect_true("res" %in% formals_names)

    body_txt <- handler_body_text(handler)
    # Happy path reads ontology_details from req$argsBody, builds an UPDATE
    # statement with parameter placeholders, and calls db_execute_statement.
    expect_match(body_txt, "argsBody\\$ontology_details",
                 info = "variant/update must parse req$argsBody$ontology_details")
    expect_match(body_txt, "UPDATE variation_ontology_list",
                 info = "variant/update must issue UPDATE variation_ontology_list")
    expect_match(body_txt, "db_execute_statement",
                 info = "variant/update must call db_execute_statement")
  })
})

test_that("PUT variant/update — validation + permission path: 400/404 + require_role", {
  with_test_db_transaction({
    env <- make_ontology_sandbox()
    handler <- extract_plumber_handler(
      ontology_file_path(),
      decorator_regex = "^#\\*\\s+@put\\s+variant/update\\s*$",
      envir = env
    )
    body_txt <- handler_body_text(handler)

    # Admin gate
    expect_match(body_txt, "require_role\\([^)]*\"Administrator\"",
                 info = "variant/update must gate on require_role(..., \"Administrator\")")
    # 400 when vario_id is missing
    expect_match(body_txt, "res\\$status\\s*<-\\s*400",
                 info = "variant/update must set 400 on missing vario_id / no changes")
    # 404 when the vario_id is not found
    expect_match(body_txt, "res\\$status\\s*<-\\s*404",
                 info = "variant/update must set 404 when vario_id is not found")
    # Specific error message for missing id
    expect_match(body_txt, "vario_id field is required",
                 info = "variant/update must return a descriptive missing-id error")
  })
})
