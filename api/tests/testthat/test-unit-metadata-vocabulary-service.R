# tests/testthat/test-unit-metadata-vocabulary-service.R
#
# Host-runnable unit tests for the Admin metadata vocabulary CRUD service
# (issue #32). The repository layer is mocked, so these tests need no
# RMariaDB / live database. They verify:
#   - vocabulary registry shape and editability classification
#   - validation (required fields, length ceilings, flag coercion)
#   - editability rules (anchored vocabularies reject create/delete)
#   - the in-use delete guard (block when referenced, soft-delete otherwise)

library(testthat)
library(tibble)

source_api_file("core/errors.R", local = FALSE)
source_api_file("functions/metadata-vocabulary-repository.R", local = FALSE)
source_api_file("services/metadata-vocabulary-service.R", local = FALSE)

# ---------------------------------------------------------------------------
# Mock harness: override repository functions in .GlobalEnv for one test, then
# restore. Each mock records the calls it received so we can assert behaviour.
# ---------------------------------------------------------------------------

# Mocks are installed in the environment where the service + repository
# functions were sourced (source_api_file(local = FALSE) sources into this
# file's top-level env), so the service's lexical lookups resolve the mock.
repo_env <- environment(svc_metadata_delete)

with_repo_mocks <- function(mocks, code) {
  originals <- list()
  for (name in names(mocks)) {
    originals[[name]] <- get(name, envir = repo_env)
    assign(name, mocks[[name]], envir = repo_env)
  }
  on.exit({
    for (name in names(originals)) {
      assign(name, originals[[name]], envir = repo_env)
    }
  }, add = TRUE)
  force(code)
}

# =============================================================================
# Registry
# =============================================================================

test_that("registry exposes the four managed vocabularies with editability", {
  reg <- metadata_vocabulary_registry()
  expect_setequal(
    names(reg),
    c("modifier", "status_category", "inheritance", "variation_ontology")
  )
  # SysNDD-managed vocabularies are fully editable
  expect_true(isTRUE(reg$modifier$editable))
  expect_true(isTRUE(reg$status_category$editable))
  # Ontology-anchored vocabularies are flagged "anchored", not TRUE
  expect_identical(reg$inheritance$editable, "anchored")
  expect_identical(reg$variation_ontology$editable, "anchored")
})

test_that("unknown slug resolves to a 404 classed error", {
  expect_error(
    svc_metadata_require_descriptor("does_not_exist"),
    class = "error_404"
  )
})

# =============================================================================
# Validation
# =============================================================================

test_that("flag coercion accepts boolean/0-1/strings and rejects junk", {
  expect_identical(svc_metadata_coerce_flag(TRUE, "f"), 1L)
  expect_identical(svc_metadata_coerce_flag(0, "f"), 0L)
  expect_identical(svc_metadata_coerce_flag("true", "f"), 1L)
  expect_identical(svc_metadata_coerce_flag("0", "f"), 0L)
  expect_error(svc_metadata_coerce_flag("maybe", "f"), class = "error_400")
  expect_error(svc_metadata_coerce_flag(5, "f"), class = "error_400")
})

test_that("text validation enforces required and length ceilings", {
  expect_error(
    svc_metadata_clean_text("", "modifier_name", required = TRUE),
    class = "error_400"
  )
  expect_error(
    svc_metadata_clean_text(strrep("x", 16), "modifier_name"),
    class = "error_400"
  )
  expect_identical(
    svc_metadata_clean_text("  present  ", "modifier_name", required = TRUE),
    "present"
  )
  expect_null(svc_metadata_clean_text(NULL, "definition"))
})

# =============================================================================
# Create
# =============================================================================

test_that("create on a sysndd vocabulary inserts with next id and defaults", {
  captured <- new.env()
  with_repo_mocks(
    list(
      metadata_vocabulary_next_id = function(descriptor, conn = NULL) 6L,
      metadata_vocabulary_insert = function(descriptor, columns, conn = NULL) {
        captured$columns <- columns
        1L
      }
    ),
    {
      result <- svc_metadata_create(
        "modifier",
        list(modifier_name = "transient", allowed_phenotype = TRUE),
        pool = NULL
      )
      expect_equal(result$status, 201)
      expect_equal(result$entry$pk, 6L)
    }
  )
  # pk auto-assigned, omitted flag defaults to 0, is_active defaults to 1
  expect_equal(captured$columns$modifier_id, 6L)
  expect_equal(captured$columns$modifier_name, "transient")
  expect_equal(captured$columns$allowed_phenotype, 1L)
  expect_equal(captured$columns$allowed_variation, 0L)
  expect_equal(captured$columns$is_active, 1L)
})

test_that("create requires the primary display field", {
  expect_error(
    svc_metadata_create("modifier", list(allowed_phenotype = TRUE), pool = NULL),
    class = "error_400"
  )
})

test_that("create is rejected for anchored vocabularies", {
  expect_error(
    svc_metadata_create(
      "inheritance",
      list(hpo_mode_of_inheritance_term_name = "New term"),
      pool = NULL
    ),
    class = "error_400"
  )
})

# =============================================================================
# Update
# =============================================================================

test_that("update writes only supplied editable fields", {
  captured <- new.env()
  with_repo_mocks(
    list(
      metadata_vocabulary_get = function(descriptor, pk_value, conn = NULL) {
        tibble(category_id = 2L, category = "Moderate", is_active = 1L)
      },
      metadata_vocabulary_update = function(descriptor, pk_value, columns, conn = NULL) {
        captured$pk <- pk_value
        captured$columns <- columns
        1L
      }
    ),
    {
      result <- svc_metadata_update(
        "status_category", "2", list(category = "Moderate*", is_active = 0),
        pool = NULL
      )
      expect_equal(result$status, 200)
    }
  )
  expect_equal(captured$pk, 2L)
  expect_equal(captured$columns$category, "Moderate*")
  expect_equal(captured$columns$is_active, 0L)
})

test_that("update on a missing row returns 404", {
  with_repo_mocks(
    list(
      metadata_vocabulary_get = function(descriptor, pk_value, conn = NULL) tibble()
    ),
    {
      expect_error(
        svc_metadata_update("modifier", "99", list(modifier_name = "x"), pool = NULL),
        class = "error_404"
      )
    }
  )
})

test_that("anchored vocabulary update is allowed for curated fields", {
  captured <- new.env()
  with_repo_mocks(
    list(
      metadata_vocabulary_get = function(descriptor, pk_value, conn = NULL) {
        tibble(vario_id = "VariO:0001", vario_name = "old", is_active = 1L)
      },
      metadata_vocabulary_update = function(descriptor, pk_value, columns, conn = NULL) {
        captured$pk <- pk_value
        captured$columns <- columns
        1L
      }
    ),
    {
      result <- svc_metadata_update(
        "variation_ontology", "VariO:0001",
        list(vario_name = "new name", is_active = 0), pool = NULL
      )
      expect_equal(result$status, 200)
    }
  )
  expect_equal(captured$pk, "VariO:0001")
  expect_equal(captured$columns$vario_name, "new name")
  expect_equal(captured$columns$is_active, 0L)
})

test_that("update with no editable fields returns 400", {
  with_repo_mocks(
    list(
      metadata_vocabulary_get = function(descriptor, pk_value, conn = NULL) {
        tibble(modifier_id = 2L, modifier_name = "x")
      }
    ),
    {
      expect_error(
        svc_metadata_update("modifier", "2", list(unrelated = "y"), pool = NULL),
        class = "error_400"
      )
    }
  )
})

# =============================================================================
# Delete + in-use guard
# =============================================================================

test_that("delete blocks an in-use value with a 400", {
  with_repo_mocks(
    list(
      metadata_vocabulary_get = function(descriptor, pk_value, conn = NULL) {
        tibble(modifier_id = 2L, modifier_name = "uncertain")
      },
      metadata_vocabulary_usage_count = function(descriptor, pk_value, conn = NULL) 3L,
      metadata_vocabulary_soft_delete = function(descriptor, pk_value, conn = NULL) {
        stop("soft_delete must not run when value is in use")
      }
    ),
    {
      expect_error(
        svc_metadata_delete("modifier", "2", pool = NULL),
        class = "error_400"
      )
    }
  )
})

test_that("delete soft-deletes an unused value", {
  captured <- new.env()
  with_repo_mocks(
    list(
      metadata_vocabulary_get = function(descriptor, pk_value, conn = NULL) {
        tibble(modifier_id = 9L, modifier_name = "spare")
      },
      metadata_vocabulary_usage_count = function(descriptor, pk_value, conn = NULL) 0L,
      metadata_vocabulary_soft_delete = function(descriptor, pk_value, conn = NULL) {
        captured$pk <- pk_value
        1L
      }
    ),
    {
      result <- svc_metadata_delete("modifier", "9", pool = NULL)
      expect_equal(result$status, 200)
    }
  )
  expect_equal(captured$pk, 9L)
})

test_that("delete is rejected for anchored vocabularies", {
  expect_error(
    svc_metadata_delete("inheritance", "HP:0000006", pool = NULL),
    class = "error_400"
  )
})

test_that("delete of a missing row returns 404", {
  with_repo_mocks(
    list(
      metadata_vocabulary_get = function(descriptor, pk_value, conn = NULL) tibble()
    ),
    {
      expect_error(
        svc_metadata_delete("status_category", "99", pool = NULL),
        class = "error_404"
      )
    }
  )
})

# =============================================================================
# Service prefix / no-shadowing invariant
# =============================================================================

test_that("service functions keep the svc_metadata_ prefix", {
  expect_true(is.function(svc_metadata_list))
  expect_true(is.function(svc_metadata_create))
  expect_true(is.function(svc_metadata_update))
  expect_true(is.function(svc_metadata_delete))
})
