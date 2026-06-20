# tests/testthat/test-unit-disease-mapping-endpoint.R
#
# Unit tests for disease cross-ontology mapping read path (WP-D).
# Pure tests (no DB / no network) — runs on host.

library(testthat)
library(tibble)

source_api_file("functions/disease-ontology-mapping-repository.R", local = FALSE)

# ---------------------------------------------------------------------------
# D1 tests: disease_mapping_group_rows (pure function)
# ---------------------------------------------------------------------------

test_that("disease_mapping_group_rows groups by prefix in allowlist order", {
  rows <- tibble::tibble(
    target_prefix = c("Orphanet", "MONDO", "OMIM"),
    target_id     = c("Orphanet:530983", "MONDO:0032745", "OMIM:618524"),
    target_label  = c("Some disease", NA_character_, "OMIM label"),
    predicate     = c("exactMatch", "exactMatch", NA_character_),
    source        = c("mondo_sssom", "mondo_sssom", "sysndd_native")
  )
  result <- disease_mapping_group_rows(rows)

  expect_named(result, c("mappings", "mondo_id"))
  expect_equal(result$mondo_id, "MONDO:0032745")

  # Groups ordered by allowlist: MONDO first, then Orphanet, then OMIM
  group_names <- names(result$mappings)
  expect_equal(group_names[1], "MONDO")
  expect_equal(group_names[2], "Orphanet")
  expect_equal(group_names[3], "OMIM")

  # Each entry has the right fields
  mondo_entry <- result$mappings$MONDO[[1]]
  expect_equal(mondo_entry$id, "MONDO:0032745")
  expect_equal(mondo_entry$predicate, "exactMatch")
  expect_equal(mondo_entry$source, "mondo_sssom")

  # Orphanet entry has label
  orphanet_entry <- result$mappings$Orphanet[[1]]
  expect_equal(orphanet_entry$label, "Some disease")

  # OMIM entry has null predicate (NA becomes null in JSON)
  omim_entry <- result$mappings$OMIM[[1]]
  expect_true(is.na(omim_entry$predicate) || is.null(omim_entry$predicate))
})

test_that("disease_mapping_group_rows returns NULL mondo_id when no MONDO group", {
  rows <- tibble::tibble(
    target_prefix = c("OMIM"),
    target_id     = c("OMIM:618524"),
    target_label  = c(NA_character_),
    predicate     = c(NA_character_),
    source        = c("sysndd_native")
  )
  result <- disease_mapping_group_rows(rows)
  expect_null(result$mondo_id)
  expect_true("OMIM" %in% names(result$mappings))
})

test_that("disease_mapping_group_rows with empty rows returns empty", {
  rows <- tibble::tibble(
    target_prefix = character(0),
    target_id     = character(0),
    target_label  = character(0),
    predicate     = character(0),
    source        = character(0)
  )
  result <- disease_mapping_group_rows(rows)
  expect_null(result$mondo_id)
  expect_equal(result$mappings, list())
})

# m1: non-allowlisted prefixes must be dropped from the public response
test_that("disease_mapping_group_rows drops non-allowlisted prefixes", {
  rows <- tibble::tibble(
    target_prefix = c("OMIM", "PROPRIETARY", "MONDO", "INTERNAL_DB"),
    target_id     = c("OMIM:618524", "PROP:999", "MONDO:0032745", "INT:123"),
    target_label  = c(NA_character_, "Private label", NA_character_, "Internal"),
    predicate     = c(NA_character_, "exactMatch", "exactMatch", "closeMatch"),
    source        = c("sysndd_native", "internal", "mondo_sssom", "internal")
  )
  result <- disease_mapping_group_rows(rows)

  # Only allowlisted prefixes should appear
  group_names <- names(result$mappings)
  expect_false("PROPRIETARY" %in% group_names,
    info = "Non-allowlisted prefix PROPRIETARY must be dropped")
  expect_false("INTERNAL_DB" %in% group_names,
    info = "Non-allowlisted prefix INTERNAL_DB must be dropped")
  expect_true("OMIM" %in% group_names)
  expect_true("MONDO" %in% group_names)
  # MONDO is first in allowlist order
  expect_equal(group_names[1], "MONDO")
})

test_that("disease_mapping_group_rows with only non-allowlisted prefixes returns empty", {
  rows <- tibble::tibble(
    target_prefix = c("PROPRIETARY", "INTERNAL_DB"),
    target_id     = c("PROP:999", "INT:123"),
    target_label  = c("Private", "Internal"),
    predicate     = c("exactMatch", "closeMatch"),
    source        = c("internal", "internal")
  )
  result <- disease_mapping_group_rows(rows)
  expect_equal(result$mappings, list())
  expect_null(result$mondo_id)
})

# ---------------------------------------------------------------------------
# C1 tests: security — inactive/non-public entity returns "missing" with no data
# ---------------------------------------------------------------------------

test_that("disease_mapping_for_entity returns missing with no data when entity absent from ndd_entity_view", {
  # This test guards the invariant that inactive/non-public entities never leak
  # mapping data. The function must query ndd_entity_view (not ndd_entity), and
  # an empty result must produce status="missing" with empty mappings.
  # If someone changes the view name to ndd_entity, the SQL mock won't match
  # and the function will hit the real pool (or fail), causing this test to break.

  query_calls <- character(0)

  local_mocked_bindings(
    dbGetQuery = function(conn, statement, params = list(), ...) {
      query_calls <<- c(query_calls, statement)
      # Return zero rows for ndd_entity_view query (entity absent from public view)
      if (grepl("ndd_entity_view", statement)) {
        return(data.frame(disease_ontology_id_version = character(0), stringsAsFactors = FALSE))
      }
      # Should not reach any other query
      stop("Unexpected query in test: ", statement)
    },
    .package = "DBI"
  )

  fake_conn <- structure(list(label = "test_conn"), class = "DBIConnection")
  result <- disease_mapping_for_entity(99999L, conn = fake_conn)

  # Status must be missing
  expect_equal(result$status, "missing")
  # Mappings must be empty
  expect_equal(length(result$mappings), 0L)
  # No mapping data leaked
  expect_null(result$mondo_id)
  expect_null(result$release_version)
  # The function must have queried ndd_entity_view, not ndd_entity
  expect_true(any(grepl("ndd_entity_view", query_calls)),
    info = "Must query ndd_entity_view for public-only resolution")
  expect_false(any(grepl("FROM ndd_entity[^_]", query_calls)),
    info = "Must NOT query bare ndd_entity table directly")
})

test_that("disease_mapping_for_entity delegates to disease_mapping_for_disease when entity found in view", {
  # Positive case: view returns a row, dos lookup returns a base disease_ontology_id,
  # then the disease-level lookup returns mapping data.
  call_count <- 0L

  local_mocked_bindings(
    dbGetQuery = function(conn, statement, params = list(), ...) {
      call_count <<- call_count + 1L
      if (grepl("ndd_entity_view", statement)) {
        return(data.frame(
          disease_ontology_id_version = "OMIM:618524v1",
          stringsAsFactors = FALSE
        ))
      }
      if (grepl("disease_ontology_set.*disease_ontology_id_version", statement)) {
        return(data.frame(
          disease_ontology_id = "OMIM:618524",
          stringsAsFactors = FALSE
        ))
      }
      # disease_ontology_set metadata query (SELECT disease_ontology_name)
      if (grepl("disease_ontology_set", statement)) {
        return(data.frame(
          disease_ontology_name = "Test Disease",
          stringsAsFactors = FALSE
        ))
      }
      # disease_ontology_mapping query
      if (grepl("disease_ontology_mapping", statement)) {
        return(data.frame(
          target_prefix   = "OMIM",
          target_id       = "OMIM:618524",
          target_label    = NA_character_,
          predicate       = NA_character_,
          source          = "sysndd_native",
          release_version = "2024-01",
          stringsAsFactors = FALSE
        ))
      }
      stop("Unexpected query: ", statement)
    },
    .package = "DBI"
  )

  fake_conn <- structure(list(label = "test_conn"), class = "DBIConnection")
  result <- disease_mapping_for_entity(42L, conn = fake_conn)

  # Should produce a current result with mappings
  expect_equal(result$status, "current")
  expect_true(length(result$mappings) > 0L)
  expect_true("OMIM" %in% names(result$mappings))
  expect_equal(result$disease_ontology_id, "OMIM:618524")
  expect_equal(result$release_version, "2024-01")
  # ontology_mapping_release must NOT be in the response (I2: single release field)
  expect_false("ontology_mapping_release" %in% names(result),
    info = "ontology_mapping_release must be removed; use only release_version")
})

# ---------------------------------------------------------------------------
# I2 test: single release_version field in disease_mapping_for_disease
# ---------------------------------------------------------------------------

test_that("disease_mapping_for_disease exposes release_version and NOT ontology_mapping_release", {
  local_mocked_bindings(
    dbGetQuery = function(conn, statement, params = list(), ...) {
      if (grepl("disease_ontology_set", statement)) {
        return(data.frame(
          disease_ontology_name = "Test Disease",
          stringsAsFactors = FALSE
        ))
      }
      if (grepl("disease_ontology_mapping", statement)) {
        return(data.frame(
          target_prefix   = c("MONDO", "OMIM"),
          target_id       = c("MONDO:0032745", "OMIM:618524"),
          target_label    = c(NA_character_, NA_character_),
          predicate       = c("exactMatch", NA_character_),
          source          = c("mondo_sssom", "sysndd_native"),
          release_version = c("2024-01", "2024-01"),
          stringsAsFactors = FALSE
        ))
      }
      stop("Unexpected query: ", statement)
    },
    .package = "DBI"
  )

  fake_conn <- structure(list(label = "test_conn"), class = "DBIConnection")
  result <- disease_mapping_for_disease("OMIM:618524", conn = fake_conn)

  expect_equal(result$status, "current")
  # release_version must be present
  expect_true("release_version" %in% names(result),
    info = "release_version must be present in response")
  expect_equal(result$release_version, "2024-01")
  # ontology_mapping_release must NOT be present (I2)
  expect_false("ontology_mapping_release" %in% names(result),
    info = "ontology_mapping_release must not appear in response (use only release_version)")
})

test_that("disease_mapping_for_disease missing returns no ontology_mapping_release", {
  local_mocked_bindings(
    dbGetQuery = function(conn, statement, params = list(), ...) {
      if (grepl("disease_ontology_set", statement)) {
        return(data.frame(
          disease_ontology_name = NA_character_,
          stringsAsFactors = FALSE
        ))
      }
      if (grepl("disease_ontology_mapping", statement)) {
        return(data.frame(
          target_prefix   = character(0),
          target_id       = character(0),
          target_label    = character(0),
          predicate       = character(0),
          source          = character(0),
          release_version = character(0),
          stringsAsFactors = FALSE
        ))
      }
      stop("Unexpected query: ", statement)
    },
    .package = "DBI"
  )

  fake_conn <- structure(list(label = "test_conn"), class = "DBIConnection")
  result <- disease_mapping_for_disease("UNKNOWN:0000", conn = fake_conn)

  expect_equal(result$status, "missing")
  expect_false("ontology_mapping_release" %in% names(result),
    info = "ontology_mapping_release must not appear in missing response")
  expect_equal(length(result$mappings), 0L)
})

# ---------------------------------------------------------------------------
# I1 tests: endpoint parameter validation
#
# The endpoint file defines a plumber anonymous function (not a named symbol),
# so we test the handler logic directly by defining a named wrapper that
# mirrors the endpoint body exactly (body is short and stable).
# This is the established pattern in this repo for endpoint validation tests.
# ---------------------------------------------------------------------------

# Mirror of the disease_mapping_endpoints.R handler logic (pure logic, no plumber)
make_disease_mapping_handler <- function(
  stop_fn        = stop_for_bad_request,
  entity_fn      = disease_mapping_for_entity,
  disease_fn     = disease_mapping_for_disease
) {
  function(req, res, entity_id = NULL, disease_ontology_id = NULL) {
    entity_id           <- if (is.null(entity_id)) NULL else entity_id[[1]]
    disease_ontology_id <- if (is.null(disease_ontology_id)) NULL else disease_ontology_id[[1]]

    has_entity  <- !is.null(entity_id) && !is.na(entity_id) &&
                   nchar(as.character(entity_id)) > 0
    has_disease <- !is.null(disease_ontology_id) && !is.na(disease_ontology_id) &&
                   nchar(as.character(disease_ontology_id)) > 0

    if (has_entity == has_disease) {
      stop_fn("Exactly one of entity_id or disease_ontology_id is required.")
    }

    if (has_entity) {
      entity_id_int <- suppressWarnings(as.integer(entity_id))
      if (is.na(entity_id_int)) stop_fn("entity_id must be an integer.")
      entity_fn(entity_id_int)
    } else {
      disease_fn(as.character(disease_ontology_id))
    }
  }
}

# Guard: endpoint source text must match what the handler mirror tests
test_that("endpoint source text matches the handler mirror used in I1 tests", {
  ep_path <- file.path(get_api_dir(), "endpoints", "disease_mapping_endpoints.R")
  if (!file.exists(ep_path)) skip("disease_mapping_endpoints.R not found")
  src <- paste(readLines(ep_path, warn = FALSE), collapse = "\n")
  # The key phrases that the mirror above reproduces:
  expect_match(src, "has_entity == has_disease")
  expect_match(src, "Exactly one of entity_id or disease_ontology_id is required")
  expect_match(src, "entity_id must be an integer")
  expect_match(src, "disease_mapping_for_entity")
  expect_match(src, "disease_mapping_for_disease")
})

source_api_file("core/errors.R", local = FALSE)

test_that("endpoint handler raises error_400 when both params absent", {
  handler <- make_disease_mapping_handler()
  expect_error(
    handler(req = list(), res = list(), entity_id = NULL, disease_ontology_id = NULL),
    class = "error_400"
  )
})

test_that("endpoint handler raises error_400 when both params present", {
  handler <- make_disease_mapping_handler()
  expect_error(
    handler(req = list(), res = list(),
            entity_id = "42", disease_ontology_id = "OMIM:618524"),
    class = "error_400"
  )
})

test_that("endpoint handler passes through to entity lookup when entity_id provided", {
  handler <- make_disease_mapping_handler(
    entity_fn  = function(entity_id, ...) list(status = "current", entity_id_seen = entity_id),
    disease_fn = function(...) stop("disease_mapping_for_disease should not be called")
  )
  result <- handler(req = list(), res = list(),
                    entity_id = "42", disease_ontology_id = NULL)
  expect_equal(result$status, "current")
  expect_equal(result$entity_id_seen, 42L)
})

test_that("endpoint handler passes through to disease lookup when disease_ontology_id provided", {
  handler <- make_disease_mapping_handler(
    entity_fn  = function(...) stop("disease_mapping_for_entity should not be called"),
    disease_fn = function(disease_ontology_id, ...) list(status = "current", disease_id_seen = disease_ontology_id)
  )
  result <- handler(req = list(), res = list(),
                    entity_id = NULL, disease_ontology_id = "OMIM:618524")
  expect_equal(result$status, "current")
  expect_equal(result$disease_id_seen, "OMIM:618524")
})

test_that("endpoint handler returns status missing (HTTP 200, no error) for unknown disease", {
  # An unknown disease_ontology_id must not throw — it returns status:"missing"
  handler <- make_disease_mapping_handler(
    entity_fn  = function(...) stop("should not be called"),
    disease_fn = function(disease_ontology_id, ...) {
      list(status = "missing", mappings = list(),
           disease_ontology_id = disease_ontology_id)
    }
  )
  result <- expect_no_error(
    handler(req = list(), res = list(),
            entity_id = NULL, disease_ontology_id = "UNKNOWN:9999")
  )
  expect_equal(result$status, "missing")
})

test_that("endpoint handler raises error_400 for non-integer entity_id", {
  handler <- make_disease_mapping_handler()
  expect_error(
    handler(req = list(), res = list(),
            entity_id = "not-an-int", disease_ontology_id = NULL),
    class = "error_400"
  )
})

# ---------------------------------------------------------------------------
# D3 test: ontology_endpoints.R select() includes new projection columns
# ---------------------------------------------------------------------------

test_that("ontology_endpoints.R select() includes the new projection columns", {
  ontology_path <- file.path(get_api_dir(), "endpoints", "ontology_endpoints.R")
  if (!file.exists(ontology_path)) skip("ontology_endpoints.R not found")
  src <- readLines(ontology_path, warn = FALSE)
  for (col in c("UMLS", "MedGen", "NCIT", "GARD", "ontology_mapping_release")) {
    expect_true(
      any(grepl(paste0("\\b", col, "\\b"), src)),
      info = paste("Column", col, "missing from ontology_endpoints.R select()")
    )
  }
})
