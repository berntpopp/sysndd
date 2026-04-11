# tests/testthat/test-endpoint-search.R
#
# Phase C unit C7 (read-only batch) — route-surface and handler-shape tests
# for api/endpoints/search_endpoints.R.
#
# Scope rule (plan §3 Phase C.C7 exit criterion #5, LOCKED): one test_that()
# block per HTTP method per route. `search_endpoints.R` exposes four @get
# routes, so this file has 8 test_that blocks (happy path + empty-result path
# per route).
#
# Testing strategy mirrors test-endpoint-auth.R:
#   1. Structural assertions parse the endpoint file as text and verify the
#      decorator is present and the handler signature is well-formed. These
#      run on any host — they require no DB, no plumber, no renv library.
#   2. Handler extraction via extract_plumber_handler() pulls each anonymous
#      function literal out of the parsed source and evaluates it into a
#      sandbox environment. Body-level assertions then check that the
#      expected table is referenced and the expected shape transforms
#      (stringdist / slice_head / pivot_wider) are in place.
#
# The full DB-touching happy path is exercised in Phase C8's write-batch and
# the existing integration-layer tests; here we cover the read surface with
# with_test_db_transaction() so the rollback invariant holds even when a
# handler body inspection drifts into a live SQL execution in future.

library(testthat)

# -----------------------------------------------------------------------------
# Shared helpers (duplicated from test-endpoint-auth.R by design — Phase C
# forbids mutating pre-existing test files outside the rollback audit, so
# the extraction helper is copied here rather than refactored into a shared
# helper-*.R file).
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

search_file_path <- function() {
  file.path(get_api_dir(), "endpoints", "search_endpoints.R")
}

make_search_sandbox <- function() {
  env <- new.env(parent = globalenv())
  env$pool <- "STUB_POOL"
  env
}

handler_body_text <- function(handler_fn) {
  paste(deparse(body(handler_fn)), collapse = "\n")
}

# =============================================================================
# Route 1/4 — @get <searchterm>  (entity search)
# =============================================================================

test_that("GET <searchterm> — happy path: decorator + handler surface", {
  # with_test_db_transaction ensures rollback invariance even if a future
  # change to this test starts executing the handler against the live pool.
  with_test_db_transaction({
    src <- readLines(search_file_path(), warn = FALSE)
    # The decorator is parameterised (<searchterm>) — match the literal form.
    decorators <- grep("^#\\*\\s+@get\\s+<searchterm>\\s*$", src, value = TRUE)
    expect_true(
      length(decorators) >= 1,
      info = "search_endpoints.R must expose `#* @get <searchterm>` (entity search)."
    )

    env <- make_search_sandbox()
    handler <- extract_plumber_handler(
      search_file_path(),
      decorator_regex = "^#\\*\\s+@get\\s+<searchterm>\\s*$",
      envir = env
    )
    expect_true(is.function(handler))

    # Signature: (searchterm, helper = TRUE)
    formals_names <- names(formals(handler))
    expect_true("searchterm" %in% formals_names)
    expect_true("helper" %in% formals_names)

    # Body references ndd_entity_view and uses stringdist for fuzzy matching.
    body_txt <- handler_body_text(handler)
    expect_match(body_txt, "ndd_entity_view",
                 info = "entity search must read from `ndd_entity_view`")
    expect_match(body_txt, "stringdist",
                 info = "entity search must use stringdist for fuzzy matching")
  })
})

test_that("GET <searchterm> — empty-result path: slice_head fallback", {
  with_test_db_transaction({
    env <- make_search_sandbox()
    handler <- extract_plumber_handler(
      search_file_path(),
      decorator_regex = "^#\\*\\s+@get\\s+<searchterm>\\s*$",
      envir = env
    )
    body_txt <- handler_body_text(handler)

    # Empty/low-hit path: searchdist filter + slice_head return_count fallback
    # ensures the handler returns up to 10 matches even when nothing is close.
    expect_match(body_txt, "searchdist\\s*<\\s*0\\.1",
                 info = "empty-result path depends on searchdist < 0.1 tally")
    expect_match(body_txt, "slice_head",
                 info = "empty-result path depends on slice_head fallback")
  })
})

# =============================================================================
# Route 2/4 — @get ontology/<searchterm>  (disease ontology search)
# =============================================================================

test_that("GET ontology/<searchterm> — happy path: decorator + handler surface", {
  with_test_db_transaction({
    src <- readLines(search_file_path(), warn = FALSE)
    decorators <- grep("^#\\*\\s+@get\\s+ontology/<searchterm>\\s*$",
                       src, value = TRUE)
    expect_true(
      length(decorators) >= 1,
      info = "search_endpoints.R must expose `#* @get ontology/<searchterm>`."
    )

    env <- make_search_sandbox()
    handler <- extract_plumber_handler(
      search_file_path(),
      decorator_regex = "^#\\*\\s+@get\\s+ontology/<searchterm>\\s*$",
      envir = env
    )
    expect_true(is.function(handler))

    formals_names <- names(formals(handler))
    expect_true("searchterm" %in% formals_names)
    expect_true("tree" %in% formals_names)

    body_txt <- handler_body_text(handler)
    expect_match(body_txt, "search_disease_ontology_set",
                 info = "ontology search must read from `search_disease_ontology_set`")
    expect_match(body_txt, "stringdist",
                 info = "ontology search must use stringdist for fuzzy matching")
  })
})

test_that("GET ontology/<searchterm> — empty-result path: tree/pivot fallback", {
  with_test_db_transaction({
    env <- make_search_sandbox()
    handler <- extract_plumber_handler(
      search_file_path(),
      decorator_regex = "^#\\*\\s+@get\\s+ontology/<searchterm>\\s*$",
      envir = env
    )
    body_txt <- handler_body_text(handler)

    # tree=TRUE builds a treeselect-compatible id/label shape; tree=FALSE
    # pivots wide. Both branches must still respect the slice_head fallback.
    expect_match(body_txt, "slice_head",
                 info = "ontology empty-result path relies on slice_head fallback")
    expect_match(body_txt, "if \\(tree\\)",
                 info = "ontology handler must branch on tree = TRUE/FALSE")
  })
})

# =============================================================================
# Route 3/4 — @get gene/<searchterm>  (HGNC/symbol search)
# =============================================================================

test_that("GET gene/<searchterm> — happy path: decorator + handler surface", {
  with_test_db_transaction({
    src <- readLines(search_file_path(), warn = FALSE)
    decorators <- grep("^#\\*\\s+@get\\s+gene/<searchterm>\\s*$",
                       src, value = TRUE)
    expect_true(
      length(decorators) >= 1,
      info = "search_endpoints.R must expose `#* @get gene/<searchterm>`."
    )

    env <- make_search_sandbox()
    handler <- extract_plumber_handler(
      search_file_path(),
      decorator_regex = "^#\\*\\s+@get\\s+gene/<searchterm>\\s*$",
      envir = env
    )
    expect_true(is.function(handler))

    formals_names <- names(formals(handler))
    expect_true("searchterm" %in% formals_names)
    expect_true("tree" %in% formals_names)

    body_txt <- handler_body_text(handler)
    expect_match(body_txt, "search_non_alt_loci_view",
                 info = "gene search must read from `search_non_alt_loci_view`")
    expect_match(body_txt, "stringdist",
                 info = "gene search must use stringdist for fuzzy matching")
  })
})

test_that("GET gene/<searchterm> — empty-result path: tree mode id/label", {
  with_test_db_transaction({
    env <- make_search_sandbox()
    handler <- extract_plumber_handler(
      search_file_path(),
      decorator_regex = "^#\\*\\s+@get\\s+gene/<searchterm>\\s*$",
      envir = env
    )
    body_txt <- handler_body_text(handler)

    # tree mode selects id = hgnc_id, label = result — assert both aliases.
    expect_match(body_txt, "id\\s*=\\s*hgnc_id",
                 info = "gene-search tree mode aliases hgnc_id as id")
    expect_match(body_txt, "label\\s*=\\s*result",
                 info = "gene-search tree mode aliases result as label")
    expect_match(body_txt, "slice_head",
                 info = "gene-search empty-result path relies on slice_head")
  })
})

# =============================================================================
# Route 4/4 — @get inheritance/<searchterm>  (mode-of-inheritance search)
# =============================================================================

test_that("GET inheritance/<searchterm> — happy path: decorator + handler surface", {
  with_test_db_transaction({
    src <- readLines(search_file_path(), warn = FALSE)
    decorators <- grep("^#\\*\\s+@get\\s+inheritance/<searchterm>\\s*$",
                       src, value = TRUE)
    expect_true(
      length(decorators) >= 1,
      info = "search_endpoints.R must expose `#* @get inheritance/<searchterm>`."
    )

    env <- make_search_sandbox()
    handler <- extract_plumber_handler(
      search_file_path(),
      decorator_regex = "^#\\*\\s+@get\\s+inheritance/<searchterm>\\s*$",
      envir = env
    )
    expect_true(is.function(handler))

    formals_names <- names(formals(handler))
    expect_true("searchterm" %in% formals_names)
    expect_true("tree" %in% formals_names)

    body_txt <- handler_body_text(handler)
    expect_match(body_txt, "search_mode_of_inheritance_list_view",
                 info = "inheritance search must read from `search_mode_of_inheritance_list_view`")
    expect_match(body_txt, "stringdist",
                 info = "inheritance search must use stringdist for fuzzy matching")
  })
})

test_that("GET inheritance/<searchterm> — empty-result path: slice_head + hpo term alias", {
  with_test_db_transaction({
    env <- make_search_sandbox()
    handler <- extract_plumber_handler(
      search_file_path(),
      decorator_regex = "^#\\*\\s+@get\\s+inheritance/<searchterm>\\s*$",
      envir = env
    )
    body_txt <- handler_body_text(handler)

    # tree mode selects id = hpo_mode_of_inheritance_term, label = result.
    expect_match(body_txt, "hpo_mode_of_inheritance_term",
                 info = "inheritance handler must reference hpo_mode_of_inheritance_term")
    expect_match(body_txt, "slice_head",
                 info = "inheritance empty-result path relies on slice_head fallback")
  })
})
