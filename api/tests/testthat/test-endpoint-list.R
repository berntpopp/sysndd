# tests/testthat/test-endpoint-list.R
#
# Phase C unit C7 (read-only batch) — route-surface and handler-shape tests
# for api/endpoints/list_endpoints.R.
#
# Scope rule (plan §3 Phase C.C7 exit criterion #5, LOCKED): one test_that()
# block per HTTP method per route. `list_endpoints.R` exposes four @get
# routes, so this file has 8 test_that blocks (happy path + empty/tree path
# per route).
#
# Testing strategy — same pattern as test-endpoint-search.R: parse the
# endpoint file, extract each anonymous handler via its decorator regex,
# and assert the body references the expected backing table + pagination
# shape. Every block is wrapped in with_test_db_transaction() so the
# rollback invariant holds even if a future change invokes the handler
# against the live pool.

library(testthat)

# -----------------------------------------------------------------------------
# Shared helpers (duplicated from test-endpoint-auth.R — Phase C forbids
# mutating pre-existing test files, so the extractor is copied per file.)
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

list_file_path <- function() {
  file.path(get_api_dir(), "endpoints", "list_endpoints.R")
}

make_list_sandbox <- function() {
  env <- new.env(parent = globalenv())
  env$pool <- "STUB_POOL"
  env
}

handler_body_text <- function(handler_fn) {
  paste(deparse(body(handler_fn)), collapse = "\n")
}

# =============================================================================
# Route 1/4 — @get status  (ndd_entity_status_categories_list)
# =============================================================================

test_that("GET status — happy path: decorator + handler + pagination shape", {
  with_test_db_transaction({
    src <- readLines(list_file_path(), warn = FALSE)
    decorators <- grep("^#\\*\\s+@get\\s+status\\s*$", src, value = TRUE)
    expect_true(
      length(decorators) >= 1,
      info = "list_endpoints.R must expose `#* @get status`."
    )

    env <- make_list_sandbox()
    handler <- extract_plumber_handler(
      list_file_path(),
      decorator_regex = "^#\\*\\s+@get\\s+status\\s*$",
      envir = env
    )
    expect_true(is.function(handler))

    formals_names <- names(formals(handler))
    expect_true("tree" %in% formals_names)
    expect_true("page_after" %in% formals_names)
    expect_true("page_size" %in% formals_names)

    body_txt <- handler_body_text(handler)
    expect_match(body_txt, "ndd_entity_status_categories_list",
                 info = "status list must read from `ndd_entity_status_categories_list`")
    # Default paginated response has links/meta/data shape (non-tree path).
    expect_match(body_txt, "generate_cursor_pag_inf_safe",
                 info = "status list must paginate via generate_cursor_pag_inf_safe")
    expect_match(body_txt, "links\\s*=\\s*pagination_info\\$links",
                 info = "status list must return pagination links")
    expect_match(body_txt, "meta\\s*=\\s*pagination_info\\$meta",
                 info = "status list must return pagination meta")
    expect_match(body_txt, "data\\s*=\\s*pagination_info\\$data",
                 info = "status list must return pagination data")
  })
})

test_that("GET status — empty/tree path: tree mode bypasses pagination", {
  with_test_db_transaction({
    env <- make_list_sandbox()
    handler <- extract_plumber_handler(
      list_file_path(),
      decorator_regex = "^#\\*\\s+@get\\s+status\\s*$",
      envir = env
    )
    body_txt <- handler_body_text(handler)

    # Tree mode selects id = category_id, label = category and returns the
    # tibble directly (no pagination wrapper).
    expect_match(body_txt, "id\\s*=\\s*category_id",
                 info = "status tree mode aliases category_id as id")
    expect_match(body_txt, "label\\s*=\\s*category",
                 info = "status tree mode aliases category as label")
    expect_match(body_txt, "if \\(tree\\)",
                 info = "status handler must branch on tree = TRUE/FALSE")
  })
})

# =============================================================================
# Route 2/4 — @get phenotype  (phenotype_list + modifier_list)
# =============================================================================

test_that("GET phenotype — happy path: decorator + handler + pagination shape", {
  with_test_db_transaction({
    src <- readLines(list_file_path(), warn = FALSE)
    decorators <- grep("^#\\*\\s+@get\\s+phenotype\\s*$", src, value = TRUE)
    expect_true(
      length(decorators) >= 1,
      info = "list_endpoints.R must expose `#* @get phenotype`."
    )

    env <- make_list_sandbox()
    handler <- extract_plumber_handler(
      list_file_path(),
      decorator_regex = "^#\\*\\s+@get\\s+phenotype\\s*$",
      envir = env
    )
    expect_true(is.function(handler))

    formals_names <- names(formals(handler))
    expect_true("tree" %in% formals_names)
    expect_true("page_after" %in% formals_names)
    expect_true("page_size" %in% formals_names)

    body_txt <- handler_body_text(handler)
    expect_match(body_txt, "phenotype_list",
                 info = "phenotype list must read from `phenotype_list`")
    expect_match(body_txt, "generate_cursor_pag_inf_safe",
                 info = "phenotype list must paginate non-tree branch")
  })
})

test_that("GET phenotype — empty/tree path: modifier nesting and id aliases", {
  with_test_db_transaction({
    env <- make_list_sandbox()
    handler <- extract_plumber_handler(
      list_file_path(),
      decorator_regex = "^#\\*\\s+@get\\s+phenotype\\s*$",
      envir = env
    )
    body_txt <- handler_body_text(handler)

    # Tree mode joins phenotype_list with modifier_list and nests modifiers
    # as children — assert both table refs and the nesting shape.
    expect_match(body_txt, "modifier_list",
                 info = "phenotype tree mode joins with modifier_list")
    expect_match(body_txt, "allowed_phenotype",
                 info = "phenotype tree mode filters on allowed_phenotype")
    expect_match(body_txt, "children",
                 info = "phenotype tree mode nests modifiers as children")
  })
})

# =============================================================================
# Route 3/4 — @get inheritance  (mode_of_inheritance_list)
# =============================================================================

test_that("GET inheritance — happy path: decorator + handler + pagination shape", {
  with_test_db_transaction({
    src <- readLines(list_file_path(), warn = FALSE)
    decorators <- grep("^#\\*\\s+@get\\s+inheritance\\s*$", src, value = TRUE)
    expect_true(
      length(decorators) >= 1,
      info = "list_endpoints.R must expose `#* @get inheritance`."
    )

    env <- make_list_sandbox()
    handler <- extract_plumber_handler(
      list_file_path(),
      decorator_regex = "^#\\*\\s+@get\\s+inheritance\\s*$",
      envir = env
    )
    expect_true(is.function(handler))

    formals_names <- names(formals(handler))
    expect_true("tree" %in% formals_names)
    expect_true("page_after" %in% formals_names)
    expect_true("page_size" %in% formals_names)

    body_txt <- handler_body_text(handler)
    expect_match(body_txt, "mode_of_inheritance_list",
                 info = "inheritance list must read from `mode_of_inheritance_list`")
    expect_match(body_txt, "is_active\\s*==\\s*1",
                 info = "inheritance list must filter on is_active = 1")
  })
})

test_that("GET inheritance — empty/tree path: hpo term id/label aliases", {
  with_test_db_transaction({
    env <- make_list_sandbox()
    handler <- extract_plumber_handler(
      list_file_path(),
      decorator_regex = "^#\\*\\s+@get\\s+inheritance\\s*$",
      envir = env
    )
    body_txt <- handler_body_text(handler)

    # Tree mode: id = hpo_mode_of_inheritance_term, label = hpo_..._name
    expect_match(body_txt, "id\\s*=\\s*hpo_mode_of_inheritance_term",
                 info = "inheritance tree mode aliases hpo term as id")
    expect_match(body_txt, "label\\s*=\\s*hpo_mode_of_inheritance_term_name",
                 info = "inheritance tree mode aliases hpo term name as label")
    expect_match(body_txt, "if \\(tree\\)",
                 info = "inheritance handler must branch on tree")
  })
})

# =============================================================================
# Route 4/4 — @get variation_ontology  (variation_ontology_list + modifier_list)
# =============================================================================

test_that("GET variation_ontology — happy path: decorator + handler + pagination shape", {
  with_test_db_transaction({
    src <- readLines(list_file_path(), warn = FALSE)
    decorators <- grep("^#\\*\\s+@get\\s+variation_ontology\\s*$",
                       src, value = TRUE)
    expect_true(
      length(decorators) >= 1,
      info = "list_endpoints.R must expose `#* @get variation_ontology`."
    )

    env <- make_list_sandbox()
    handler <- extract_plumber_handler(
      list_file_path(),
      decorator_regex = "^#\\*\\s+@get\\s+variation_ontology\\s*$",
      envir = env
    )
    expect_true(is.function(handler))

    formals_names <- names(formals(handler))
    expect_true("tree" %in% formals_names)
    expect_true("page_after" %in% formals_names)
    expect_true("page_size" %in% formals_names)

    body_txt <- handler_body_text(handler)
    expect_match(body_txt, "variation_ontology_list",
                 info = "variation_ontology list must read from `variation_ontology_list`")
    expect_match(body_txt, "generate_cursor_pag_inf_safe",
                 info = "variation_ontology list must paginate non-tree branch")
  })
})

test_that("GET variation_ontology — empty/tree path: modifier nesting and vario aliases", {
  with_test_db_transaction({
    env <- make_list_sandbox()
    handler <- extract_plumber_handler(
      list_file_path(),
      decorator_regex = "^#\\*\\s+@get\\s+variation_ontology\\s*$",
      envir = env
    )
    body_txt <- handler_body_text(handler)

    # Tree mode joins variation_ontology_list with modifier_list filtered by
    # allowed_variation, nests children, then aliases ids to vario_id.
    expect_match(body_txt, "modifier_list",
                 info = "variation_ontology tree mode joins modifier_list")
    expect_match(body_txt, "allowed_variation",
                 info = "variation_ontology tree mode filters on allowed_variation")
    expect_match(body_txt, "id\\s*=\\s*vario_id",
                 info = "variation_ontology tree mode aliases vario_id as id")
    expect_match(body_txt, "label\\s*=\\s*vario_name",
                 info = "variation_ontology tree mode aliases vario_name as label")
  })
})
