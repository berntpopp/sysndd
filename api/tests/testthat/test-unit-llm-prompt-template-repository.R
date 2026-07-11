# tests/testthat/test-unit-llm-prompt-template-repository.R
#
# Direct-source tests for functions/llm-prompt-template-repository.R (#346
# Wave 4, Task 7): get_prompt_template(), get_default_prompt_template(),
# save_prompt_template(), get_all_prompt_templates(). Extracted verbatim
# from llm-service.R; prompt content and behavior are unchanged.
#
# Pure-logic tests stub db_execute_query/db_with_transaction in an isolated
# env so no DB is required (real PASS on host). The transactional
# save/current-row-retirement test exercises the real `llm_prompt_templates`
# table (migration 008) and SKIPs when no test DB is configured.

library(testthat)
library(tibble)

source_api_file("functions/db-helpers.R", local = FALSE)
source_api_file("functions/llm-prompt-template-repository.R", local = FALSE)

# ---------------------------------------------------------------------------
# Pure-logic tests (no DB) - each gets an isolated env so stubs don't leak
# ---------------------------------------------------------------------------

source_prompt_repo_for_stub_tests <- function() {
  env <- new.env(parent = globalenv())
  source_api_file("functions/llm-prompt-template-repository.R", local = FALSE, envir = env)
  env
}

test_that("get_prompt_template rejects an invalid prompt_type", {
  env <- source_prompt_repo_for_stub_tests()
  expect_error(env$get_prompt_template("bogus_type"))
})

test_that("get_prompt_template falls back to the hardcoded default on query failure", {
  env <- source_prompt_repo_for_stub_tests()
  env$db_execute_query <- function(...) stop("no DB in this test")

  result <- env$get_prompt_template("functional_generation")

  expect_true(is.na(result$template_id))
  expect_equal(result$version, "1.0")
  expect_equal(result$description, "Default hardcoded template")
  expect_match(result$template_text, "genomics expert", fixed = TRUE)
})

test_that("get_prompt_template falls back to default when no active row exists", {
  env <- source_prompt_repo_for_stub_tests()
  env$db_execute_query <- function(...) tibble::tibble()

  result <- env$get_prompt_template("phenotype_judge")

  expect_true(is.na(result$template_id))
  expect_equal(result$prompt_type, "phenotype_judge")
  expect_match(result$template_text, "STRICT validator", fixed = TRUE)
})

test_that("get_prompt_template returns the current DB row when present", {
  env <- source_prompt_repo_for_stub_tests()
  captured_params <- NULL
  env$db_execute_query <- function(sql, params = list(), conn = NULL) {
    captured_params <<- params
    tibble::tibble(
      template_id = 42L,
      prompt_type = "functional_judge",
      version = "2.0",
      template_text = "Custom judge prompt",
      description = "Curator edit"
    )
  }

  result <- env$get_prompt_template("functional_judge")

  expect_equal(captured_params, list("functional_judge"))
  expect_equal(result$template_id, 42L)
  expect_equal(result$version, "2.0")
  expect_equal(result$template_text, "Custom judge prompt")
  expect_equal(result$description, "Curator edit")
})

test_that("get_default_prompt_template covers all four prompt types with non-empty text", {
  env <- source_prompt_repo_for_stub_tests()

  for (prompt_type in c(
    "functional_generation", "functional_judge",
    "phenotype_generation", "phenotype_judge"
  )) {
    result <- env$get_default_prompt_template(prompt_type)
    expect_equal(result$prompt_type, prompt_type)
    expect_true(is.na(result$template_id))
    expect_true(nchar(result$template_text) > 0)
  }
})

test_that("get_all_prompt_templates returns one entry per type via get_prompt_template", {
  env <- source_prompt_repo_for_stub_tests()
  requested_types <- character()
  env$get_prompt_template <- function(prompt_type) {
    requested_types <<- c(requested_types, prompt_type)
    list(prompt_type = prompt_type, version = "1.0")
  }

  result <- env$get_all_prompt_templates()

  expect_equal(
    sort(names(result)),
    sort(c(
      "functional_generation", "functional_judge",
      "phenotype_generation", "phenotype_judge"
    ))
  )
  expect_equal(length(requested_types), 4L)
})

# ---------------------------------------------------------------------------
# DB-writing test: transactional save + current-row retirement
#
# save_prompt_template()/get_prompt_template() have no injectable `conn`
# parameter (their own db_with_transaction()/db_execute_query() always
# resolve the connection via get_db_connection(), which reads the global
# `pool`). with_test_db_transaction()'s single already-in-transaction
# connection cannot be threaded through without a nested BEGIN (MySQL
# implicitly commits the outer transaction on a second BEGIN, breaking
# rollback isolation). This test instead points the global `pool` at a
# throwaway pool::dbPool (mirrors make_test_pool() in
# test-integration-entity-rename.R) and cleans up its own rows manually in
# on.exit(), per the AGENTS.md "or document why rollback is not possible"
# exception for DB-writing tests.
# ---------------------------------------------------------------------------

test_that("save_prompt_template retires the previous current row; get_prompt_template reads it back", {
  skip_if_no_test_db()

  conn <- get_test_db_connection()
  on.exit(DBI::dbDisconnect(conn), add = TRUE)

  if (!DBI::dbExistsTable(conn, "llm_prompt_templates")) {
    skip("llm_prompt_templates table not present in test DB (migration 008 not applied)")
  }

  test_prompt_type <- "functional_generation"
  had_global_pool <- base::exists("pool", envir = .GlobalEnv)
  original_pool <- if (had_global_pool) base::get("pool", envir = .GlobalEnv) else NULL

  test_config <- get_test_config()
  test_pool <- pool::dbPool(
    RMariaDB::MariaDB(),
    dbname = test_config$dbname,
    host = test_config$host,
    user = test_config$user,
    password = test_config$password,
    port = as.integer(test_config$port)
  )
  base::assign("pool", test_pool, envir = .GlobalEnv)

  inserted_ids <- integer()
  on.exit(
    {
      if (length(inserted_ids) > 0) {
        DBI::dbExecute(
          conn,
          paste0(
            "DELETE FROM llm_prompt_templates WHERE template_id IN (",
            paste(inserted_ids, collapse = ","), ")"
          ),
          immediate = TRUE
        )
      }
      pool::poolClose(test_pool)
      if (had_global_pool) {
        base::assign("pool", original_pool, envir = .GlobalEnv)
      } else {
        base::rm("pool", envir = .GlobalEnv)
      }
    },
    add = TRUE
  )

  stamp <- format(Sys.time(), "%Y%m%d%H%M%OS6")
  version_1 <- paste0("task7-test-", stamp, "-a")
  version_2 <- paste0("task7-test-", stamp, "-b")

  id_1 <- save_prompt_template(
    prompt_type = test_prompt_type,
    template_text = "First test template",
    version = version_1,
    description = "Task 7 repository test (v1)"
  )
  inserted_ids <- c(inserted_ids, id_1)

  id_2 <- save_prompt_template(
    prompt_type = test_prompt_type,
    template_text = "Second test template",
    version = version_2,
    description = "Task 7 repository test (v2)"
  )
  inserted_ids <- c(inserted_ids, id_2)

  expect_false(id_1 == id_2)

  row_1 <- DBI::dbGetQuery(
    conn,
    paste0("SELECT is_active FROM llm_prompt_templates WHERE template_id = ", id_1)
  )
  expect_equal(as.integer(row_1$is_active[1]), 0L)

  current <- get_prompt_template(test_prompt_type)
  expect_equal(current$template_id, id_2)
  expect_equal(current$version, version_2)
  expect_equal(current$template_text, "Second test template")
})
