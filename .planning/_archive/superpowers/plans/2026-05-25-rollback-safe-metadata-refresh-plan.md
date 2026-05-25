# Rollback-Safe Metadata Refresh Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace rollback-unsafe MySQL `TRUNCATE` metadata refreshes with transaction-safe `DELETE` plus insert behavior.

**Architecture:** Add one focused metadata-refresh helper for FK-check restoration and ontology refresh reuse, delete dead inline ontology executor bodies from admin endpoints, and route the live durable ontology handlers through the helper. Keep the synchronous HGNC endpoint local and narrow: preserve its dynamic insert loop while replacing `TRUNCATE` with transactional `DELETE`.

**Tech Stack:** R/Plumber, DBI, RMariaDB, testthat, mockery, MySQL/InnoDB, SysNDD durable async workers.

---

## File Map

- Create `api/functions/metadata-refresh.R`: shared FK-check cleanup helper and ontology refresh helper.
- Modify `api/bootstrap/load_modules.R`: source `functions/metadata-refresh.R` before endpoints and async handlers need it.
- Modify `api/bootstrap/setup_workers.R`: source `/app/functions/metadata-refresh.R` in mirai daemon setup.
- Modify `api/endpoints/admin_endpoints.R`: delete dead inline ontology executor bodies and replace the synchronous HGNC `TRUNCATE` path.
- Modify `api/functions/async-job-handlers.R`: replace durable worker ontology refreshes.
- Create `api/tests/testthat/test-unit-metadata-refresh.R`: unit and session-state coverage for helper behavior.
- Create `api/tests/testthat/test-unit-metadata-refresh-patterns.R`: static guard against executable metadata `TRUNCATE` statements.
- Create `api/tests/testthat/test-unit-async-job-handlers.R`: structural coverage that durable ontology handlers call the shared helper and do not keep manual transaction rollback code.
- Modify `AGENTS.md`: persistent guidance for rollback-safe metadata refreshes.

No worktree is required if the implementation starts from the clean repo state observed during planning. If `git status --short` shows unrelated user changes, do not commit over them; implement without checkpoint commits or ask for direction if they affect these files.

---

### Task 1: Add Failing Tests For Rollback-Safe Refreshes

**Files:**
- Create: `api/tests/testthat/test-unit-metadata-refresh.R`
- Create: `api/tests/testthat/test-unit-metadata-refresh-patterns.R`
- Create: `api/tests/testthat/test-unit-async-job-handlers.R`

- [ ] **Step 1: Create the helper behavior tests**

Create `api/tests/testthat/test-unit-metadata-refresh.R`:

```r
library(testthat)
library(mockery)

source_api_file("functions/metadata-refresh.R", local = FALSE)

describe("metadata_with_foreign_key_checks_disabled", {
  it("restores foreign key checks when the callback errors", {
    mock_conn <- structure(list(), class = "MockConnection")
    statements <- character()

    local_mocked_bindings(
      dbExecute = function(conn, statement, ...) {
        statements <<- c(statements, statement)
        1L
      },
      .package = "DBI"
    )

    expect_error(
      metadata_with_foreign_key_checks_disabled(mock_conn, function() {
        stop("simulated refresh failure", call. = FALSE)
      }),
      "simulated refresh failure"
    )

    expect_equal(
      statements,
      c("SET FOREIGN_KEY_CHECKS = 0", "SET FOREIGN_KEY_CHECKS = 1")
    )
  })

  it("restores foreign key checks after a successful callback", {
    mock_conn <- structure(list(), class = "MockConnection")
    statements <- character()

    local_mocked_bindings(
      dbExecute = function(conn, statement, ...) {
        statements <<- c(statements, statement)
        1L
      },
      .package = "DBI"
    )

    result <- metadata_with_foreign_key_checks_disabled(mock_conn, function() "ok")

    expect_equal(result, "ok")
    expect_equal(
      statements,
      c("SET FOREIGN_KEY_CHECKS = 0", "SET FOREIGN_KEY_CHECKS = 1")
    )
  })

  it("surfaces success-path foreign key restoration failures", {
    mock_conn <- structure(list(), class = "MockConnection")
    call_count <- 0L

    local_mocked_bindings(
      dbExecute = function(conn, statement, ...) {
        call_count <<- call_count + 1L
        if (identical(statement, "SET FOREIGN_KEY_CHECKS = 1")) {
          stop("restore failed", call. = FALSE)
        }
        1L
      },
      .package = "DBI"
    )

    expect_error(
      suppressWarnings(metadata_with_foreign_key_checks_disabled(mock_conn, function() "ok")),
      "Failed to restore FOREIGN_KEY_CHECKS"
    )
    expect_true(call_count >= 2L)
  })
})

describe("refresh_disease_ontology_set", {
  it("deletes and inserts ontology rows in a transaction without TRUNCATE", {
    mock_conn <- structure(list(), class = "MockConnection")
    state <- new.env(parent = emptyenv())
    state$statements <- character()
    state$params <- list()
    state$appends <- list()
    state$transaction_used <- FALSE

    local_mocked_bindings(
      dbExecute = function(conn, statement, params = NULL, ...) {
        state$statements <- c(state$statements, statement)
        if (!is.null(params)) {
          state$params <- c(state$params, list(params))
        }
        1L
      },
      dbWithTransaction = function(conn, code) {
        state$transaction_used <- TRUE
        force(code)
      },
      dbAppendTable = function(conn, name, value, ...) {
        state$appends <- c(state$appends, list(list(name = name, rows = nrow(value))))
        TRUE
      },
      .package = "DBI"
    )

    update_rows <- tibble::tibble(
      disease_ontology_id_version = "OMIM:100001",
      disease_ontology_id = "OMIM:100001",
      disease_ontology_name = "Updated disease",
      disease_ontology_source = "mim2gene",
      disease_ontology_date = as.POSIXct("2026-05-25", tz = "UTC"),
      disease_ontology_is_specific = TRUE,
      hgnc_id = "HGNC:1",
      hpo_mode_of_inheritance_term = "HP:0000006",
      is_active = TRUE
    )
    compatibility_rows <- dplyr::mutate(update_rows, disease_ontology_id_version = "OMIM:000001", is_active = FALSE)
    auto_fixes <- tibble::tibble(old_version = "OMIM:000001", new_version = "OMIM:100001")

    result <- refresh_disease_ontology_set(
      conn = mock_conn,
      disease_ontology_set_update = update_rows,
      auto_fixes = auto_fixes,
      compatibility_rows = compatibility_rows
    )

    expect_true(state$transaction_used)
    expect_true(any(grepl("^DELETE FROM disease_ontology_set$", state$statements)))
    expect_false(any(grepl("\\bTRUNCATE\\b", state$statements, ignore.case = TRUE)))
    expect_equal(vapply(state$appends, `[[`, character(1), "name"), c("disease_ontology_set", "disease_ontology_set"))
    expect_equal(vapply(state$appends, `[[`, integer(1), "rows"), c(1L, 1L))
    expect_equal(result$auto_fixes_applied, 1L)
    expect_equal(result$compatibility_rows, 1L)
    expect_equal(state$params[[1]], list("OMIM:100001", "OMIM:000001"))
  })

  it("rolls back real database rows when an auto-fix update fails", {
    with_test_db_transaction({
      conn <- getOption(".test_db_con")
      suffix <- as.integer(Sys.time()) %% 100000L
      hgnc_id <- paste0("HGNC:", 9000L + suffix %% 500L)
      old_version <- paste0("OMIM:", 970000L + suffix %% 500L)
      keep_version <- paste0("OMIM:", 980000L + suffix %% 500L)
      new_version <- paste0("OMIM:", 990000L + suffix %% 500L)
      bad_version <- paste0("OMIM:", paste(rep("9", 40), collapse = ""))
      user_name <- paste0("metadata_refresh_", suffix)

      DBI::dbExecute(
        conn,
        "INSERT INTO user (user_name, email, user_role, approved) VALUES (?, ?, 'Administrator', 1)",
        params = unname(list(user_name, paste0(user_name, "@example.test")))
      )
      user_id <- DBI::dbGetQuery(conn, "SELECT LAST_INSERT_ID() AS user_id")$user_id[[1]]

      DBI::dbExecute(
        conn,
        "INSERT IGNORE INTO mode_of_inheritance_list (hpo_mode_of_inheritance_term) VALUES ('HP:0000006')"
      )
      DBI::dbExecute(
        conn,
        "INSERT INTO non_alt_loci_set (hgnc_id, symbol) VALUES (?, ?)",
        params = unname(list(hgnc_id, paste0("MR", suffix)))
      )
      DBI::dbAppendTable(
        conn,
        "disease_ontology_set",
        tibble::tibble(
          disease_ontology_id_version = c(old_version, keep_version),
          disease_ontology_id = c(old_version, keep_version),
          disease_ontology_name = c("Original old disease", "Original keep disease"),
          disease_ontology_source = "test",
          disease_ontology_date = as.POSIXct("2026-05-25", tz = "UTC"),
          disease_ontology_is_specific = TRUE,
          hgnc_id = hgnc_id,
          hpo_mode_of_inheritance_term = "HP:0000006",
          is_active = TRUE
        )
      )
      DBI::dbExecute(
        conn,
        paste(
          "INSERT INTO ndd_entity",
          "(hgnc_id, hpo_mode_of_inheritance_term, disease_ontology_id_version,",
          "ndd_phenotype, entry_user_id, is_active)",
          "VALUES (?, 'HP:0000006', ?, 1, ?, 1)"
        ),
        params = unname(list(hgnc_id, old_version, user_id))
      )

      update_rows <- tibble::tibble(
        disease_ontology_id_version = new_version,
        disease_ontology_id = new_version,
        disease_ontology_name = "Replacement disease",
        disease_ontology_source = "test",
        disease_ontology_date = as.POSIXct("2026-05-25", tz = "UTC"),
        disease_ontology_is_specific = TRUE,
        hgnc_id = hgnc_id,
        hpo_mode_of_inheritance_term = "HP:0000006",
        is_active = TRUE
      )
      auto_fixes <- tibble::tibble(old_version = old_version, new_version = bad_version)

      expect_error(
        refresh_disease_ontology_set(
          conn = conn,
          disease_ontology_set_update = update_rows,
          auto_fixes = auto_fixes
        ),
        "Data too long|too long|1406"
      )

      remaining <- DBI::dbGetQuery(
        conn,
        paste(
          "SELECT disease_ontology_id_version",
          "FROM disease_ontology_set",
          "WHERE disease_ontology_id_version IN (?, ?)",
          "ORDER BY disease_ontology_id_version"
        ),
        params = unname(list(old_version, keep_version))
      )
      expect_equal(remaining$disease_ontology_id_version, sort(c(old_version, keep_version)))

      fk_checks <- DBI::dbGetQuery(conn, "SELECT @@FOREIGN_KEY_CHECKS AS fk_checks")
      expect_equal(as.integer(fk_checks$fk_checks[[1]]), 1L)
    })
  })
})
```

- [ ] **Step 2: Create the static metadata TRUNCATE guard**

Create `api/tests/testthat/test-unit-metadata-refresh-patterns.R`:

```r
library(testthat)

metadata_refresh_runtime_files <- c(
  "endpoints/admin_endpoints.R",
  "functions/async-job-handlers.R"
)

find_executable_metadata_truncates <- function(relative_path) {
  path <- file.path(get_api_dir(), relative_path)
  lines <- readLines(path, warn = FALSE)
  hits <- grep(
    "\\bTRUNCATE\\s+TABLE\\s+`?(disease_ontology_set|non_alt_loci_set)\\b`?",
    lines,
    ignore.case = TRUE
  )
  hits <- hits[!grepl("^\\s*#", lines[hits])]

  if (length(hits) == 0) {
    return(character(0))
  }

  sprintf("%s:%d: %s", relative_path, hits, trimws(lines[hits]))
}

test_that("metadata refresh runtime code does not use TRUNCATE", {
  violations <- unlist(
    lapply(metadata_refresh_runtime_files, find_executable_metadata_truncates),
    use.names = FALSE
  )

  if (length(violations) > 0) {
    fail(paste(
      "Found rollback-unsafe metadata TRUNCATE statements:",
      paste(violations, collapse = "\n"),
      sep = "\n"
    ))
  }

  expect_length(violations, 0)
})

test_that("admin ontology job submissions do not keep dead inline executors", {
  admin_path <- file.path(get_api_dir(), "endpoints", "admin_endpoints.R")
  admin_body <- paste(readLines(admin_path, warn = FALSE), collapse = "\n")

  expect_false(
    grepl(
      "operation\\s*=\\s*\"omim_update\"[\\s\\S]{0,8000}executor_fn\\s*=\\s*function",
      admin_body,
      perl = TRUE
    )
  )
  expect_false(
    grepl(
      "operation\\s*=\\s*\"force_apply_ontology\"[\\s\\S]{0,8000}executor_fn\\s*=\\s*function",
      admin_body,
      perl = TRUE
    )
  )
})
```

- [ ] **Step 3: Create durable async-handler structural tests**

Create `api/tests/testthat/test-unit-async-job-handlers.R`:

```r
library(testthat)

source_api_file("functions/async-job-handlers.R", local = FALSE)

handler_body <- function(fn) {
  paste(deparse(body(fn)), collapse = "\n")
}

test_that(".async_job_omim_db_write uses the shared ontology refresh helper", {
  body_txt <- handler_body(.async_job_omim_db_write)

  expect_match(body_txt, "refresh_disease_ontology_set")
  expect_false(grepl("\\bTRUNCATE\\b", body_txt, ignore.case = TRUE))
  expect_false(grepl("DBI::dbBegin|DBI::dbCommit|DBI::dbRollback", body_txt))
})

test_that(".async_job_run_force_apply_ontology uses helper-managed transaction lifecycle", {
  body_txt <- handler_body(.async_job_run_force_apply_ontology)

  expect_match(body_txt, "refresh_disease_ontology_set")
  expect_false(grepl("\\bTRUNCATE\\b", body_txt, ignore.case = TRUE))
  expect_false(grepl("DBI::dbRollback\\(sysndd_db\\)", body_txt))
})
```

- [ ] **Step 4: Run the new tests and verify they fail**

Run:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-metadata-refresh.R')"
```

Expected before implementation: FAIL with an error that `functions/metadata-refresh.R` is missing or `metadata_with_foreign_key_checks_disabled()` is not found.

Run:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-metadata-refresh-patterns.R')"
```

Expected before implementation: FAIL and list the active `TRUNCATE TABLE disease_ontology_set` and `TRUNCATE TABLE non_alt_loci_set` statements in `admin_endpoints.R` and `async-job-handlers.R`; the inline-executor expectations should also fail while the dead admin executor bodies remain.

Run:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-async-job-handlers.R')"
```

Expected before implementation: FAIL because the durable ontology handlers still
use manual transaction code and `.async_job_run_force_apply_ontology()` still
has an outer `DBI::dbRollback(sysndd_db)` error-handler call.

- [ ] **Step 5: Checkpoint the failing tests if the repo is clean**

Run:

```bash
git status --short
```

Expected: only the three new test files are shown as untracked.

Then commit:

```bash
git add api/tests/testthat/test-unit-metadata-refresh.R api/tests/testthat/test-unit-metadata-refresh-patterns.R api/tests/testthat/test-unit-async-job-handlers.R
git commit -m "test: cover rollback-safe metadata refreshes"
```

Expected: commit succeeds. If `git status --short` shows unrelated user files, skip this checkpoint and keep the tests uncommitted for the next task.

---

### Task 2: Add The Shared Metadata Refresh Helper

**Files:**
- Create: `api/functions/metadata-refresh.R`
- Modify: `api/bootstrap/load_modules.R`
- Modify: `api/bootstrap/setup_workers.R`
- Test: `api/tests/testthat/test-unit-metadata-refresh.R`

- [ ] **Step 1: Add the helper module**

Create `api/functions/metadata-refresh.R`:

```r
# api/functions/metadata-refresh.R
#
# Transaction-safe helpers for metadata table refreshes. MySQL TRUNCATE is DDL
# and auto-commits, so refresh paths must use DELETE plus insert inside a real
# transaction when rollback semantics matter.

metadata_with_foreign_key_checks_disabled <- function(conn, work) {
  if (!is.function(work)) {
    stop("work must be a function", call. = FALSE)
  }

  fk_restored <- FALSE
  primary_error_active <- TRUE
  DBI::dbExecute(conn, "SET FOREIGN_KEY_CHECKS = 0")
  on.exit({
    if (!isTRUE(fk_restored)) {
      tryCatch(
        metadata_restore_foreign_key_checks(conn, "metadata refresh cleanup"),
        error = function(e) {
          if (isTRUE(primary_error_active)) {
            metadata_log_foreign_key_restore_failure(conditionMessage(e))
          } else {
            stop(conditionMessage(e), call. = FALSE)
          }
        }
      )
    }
  }, add = TRUE)

  result <- work()
  primary_error_active <- FALSE

  metadata_restore_foreign_key_checks(conn, "metadata refresh")
  fk_restored <- TRUE

  result
}

metadata_log_foreign_key_restore_failure <- function(message) {
  if (exists("log_warn", mode = "function")) {
    tryCatch(
      get("log_warn", mode = "function")(message),
      error = function(e) warning(message, call. = FALSE)
    )
  } else {
    warning(message, call. = FALSE)
  }

  invisible(NULL)
}

metadata_restore_foreign_key_checks <- function(conn, context) {
  tryCatch(
    {
      DBI::dbExecute(conn, "SET FOREIGN_KEY_CHECKS = 1")
      invisible(TRUE)
    },
    error = function(e) {
      message <- sprintf(
        "Failed to restore FOREIGN_KEY_CHECKS after %s: %s",
        context,
        conditionMessage(e)
      )
      metadata_log_foreign_key_restore_failure(message)
      stop(message, call. = FALSE)
    }
  )
}

metadata_apply_ontology_auto_fixes <- function(conn, auto_fixes) {
  if (is.null(auto_fixes) || nrow(auto_fixes) == 0) {
    return(0L)
  }

  auto_fixes_applied <- 0L
  for (i in seq_len(nrow(auto_fixes))) {
    fix <- auto_fixes[i, ]
    DBI::dbExecute(
      conn,
      "UPDATE ndd_entity SET disease_ontology_id_version = ? WHERE disease_ontology_id_version = ?",
      params = unname(list(fix$new_version, fix$old_version))
    )
    auto_fixes_applied <- auto_fixes_applied + 1L
  }

  auto_fixes_applied
}

refresh_disease_ontology_set <- function(conn,
                                         disease_ontology_set_update,
                                         auto_fixes = tibble::tibble(
                                           old_version = character(0),
                                           new_version = character(0)
                                         ),
                                         compatibility_rows = tibble::tibble()) {
  metadata_with_foreign_key_checks_disabled(conn, function() {
    DBI::dbWithTransaction(conn, {
      DBI::dbExecute(conn, "DELETE FROM disease_ontology_set")

      if (nrow(disease_ontology_set_update) > 0) {
        DBI::dbAppendTable(conn, "disease_ontology_set", disease_ontology_set_update)
      }

      compat_count <- 0L
      if (nrow(compatibility_rows) > 0) {
        DBI::dbAppendTable(conn, "disease_ontology_set", compatibility_rows)
        compat_count <- nrow(compatibility_rows)
      }

      auto_fixes_applied <- metadata_apply_ontology_auto_fixes(conn, auto_fixes)

      list(
        auto_fixes_applied = auto_fixes_applied,
        compatibility_rows = compat_count
      )
    })
  })
}
```

- [ ] **Step 2: Source the helper in the API bootstrap**

In `api/bootstrap/load_modules.R`, add the helper immediately after
`functions/db-helpers.R`:

```r
    "functions/db-helpers.R",
    "functions/metadata-refresh.R",
    "functions/async-job-repository.R",
```

- [ ] **Step 3: Source the helper in mirai daemon setup**

In `api/bootstrap/setup_workers.R`, add the helper immediately after
`db-helpers.R` is sourced:

```r
    # Source metadata refresh helpers for rollback-safe table replacement
    source("/app/functions/metadata-refresh.R", local = FALSE)
```

The surrounding block should become:

```r
    # Source db-helpers for parameterized queries
    source("/app/functions/db-helpers.R", local = FALSE)
    # Source metadata refresh helpers for rollback-safe table replacement
    source("/app/functions/metadata-refresh.R", local = FALSE)
    # Source durable async-job repository for worker-side lease/progress operations
    source("/app/functions/async-job-repository.R", local = FALSE)
```

- [ ] **Step 4: Run helper tests and verify the helper behavior passes**

Run:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-metadata-refresh.R')"
```

Expected after this task: PASS. If the real-DB rollback test fails only because
RMariaDB rejects `DBI::dbWithTransaction()` inside `with_test_db_transaction()`,
keep the test but document the exception in that test file and run it on a
separate test connection with explicit cleanup, because the assertion must cover
the production transaction boundary. The static pattern test is still expected
to fail until call sites stop using `TRUNCATE`.

- [ ] **Step 5: Checkpoint the helper if the repo is clean**

Run:

```bash
git status --short
```

Expected: the helper, bootstrap source files, and tests from Task 1 are the only changed files.

Then commit:

```bash
git add api/functions/metadata-refresh.R api/bootstrap/load_modules.R api/bootstrap/setup_workers.R api/tests/testthat/test-unit-metadata-refresh.R
git commit -m "feat: add rollback-safe metadata refresh helper"
```

Expected: commit succeeds. If unrelated user changes are present, skip the checkpoint and report the dirty files.

---

### Task 3: Remove Dead Inline Ontology Writers And Update Live Handlers

**Files:**
- Modify: `api/endpoints/admin_endpoints.R`
- Modify: `api/functions/async-job-handlers.R`
- Test: `api/tests/testthat/test-unit-metadata-refresh-patterns.R`
- Test: `api/tests/testthat/test-unit-metadata-refresh.R`
- Test: `api/tests/testthat/test-unit-async-job-handlers.R`

- [ ] **Step 1: Delete the dead inline OMIM executor body**

In `api/endpoints/admin_endpoints.R`, remove the `executor_fn = function(params) { ... }`
argument from the `create_job()` call for `operation = "omim_update"`. The
current durable `create_job()` facade ignores `executor_fn`, and the durable
worker registry owns this job type.

The resulting call should have this shape:

```r
  result <- create_job(
    operation = "omim_update",
    params = list(
      mode_of_inheritance_list = mode_of_inheritance_list,
      non_alt_loci_set = non_alt_loci_set,
      ndd_entity_view = ndd_entity_view,
      disease_ontology_set_current = disease_ontology_set_current,
      ndd_entity = ndd_entity,
      db_config = list(
        dbname = dw$dbname,
        user = dw$user,
        password = dw$password,
        server = dw$server,
        host = dw$host,
        port = dw$port
      )
    )
  )
```

Do not change duplicate-job checks, payload fields, response status, or the
route decorator.

- [ ] **Step 2: Delete the dead inline force-apply executor body**

In `api/endpoints/admin_endpoints.R`, remove the `executor_fn = function(params) { ... }`
argument from the `create_job()` call for `operation = "force_apply_ontology"`.
The resulting call should have this shape:

```r
  result <- create_job(
    operation = "force_apply_ontology",
    params = list(
      csv_path = csv_path,
      auto_fixes_raw = auto_fixes_raw,
      critical_entities_raw = critical_entities_raw,
      disease_ontology_set_current = disease_ontology_set_current,
      ndd_entity_view = ndd_entity_view,
      requesting_user_id = requesting_user_id,
      db_config = list(
        dbname = dw$dbname,
        user = dw$user,
        password = dw$password,
        server = dw$server,
        host = dw$host,
        port = dw$port
      )
    )
  )
```

Do not change blocked-job validation, stale CSV validation, duplicate-job
checks, payload fields, response status, or route decorator.

- [ ] **Step 3: Update `.async_job_omim_db_write()`**

In `api/functions/async-job-handlers.R`, replace the full manual
`DBI::dbBegin()`/`tryCatch()` block in `.async_job_omim_db_write()` with:

```r
  refresh_result <- refresh_disease_ontology_set(
    conn = sysndd_db,
    disease_ontology_set_update = disease_ontology_set_update,
    auto_fixes = safeguard$auto_fixes
  )

  refresh_result$auto_fixes_applied
```

Keep the connection setup and disconnect cleanup. Do not wrap the helper in a
no-op `tryCatch()` that strips condition context; let helper errors propagate to
the durable worker.

- [ ] **Step 4: Update `.async_job_run_force_apply_ontology()`**

Inside `.async_job_run_force_apply_ontology()`, replace the manual transaction
block through `DBI::dbCommit(sysndd_db)` with:

```r
      refresh_result <- refresh_disease_ontology_set(
        conn = sysndd_db,
        disease_ontology_set_update = disease_ontology_set_update,
        auto_fixes = auto_fixes,
        compatibility_rows = compatibility_rows
      )

      auto_fixes_applied <- refresh_result$auto_fixes_applied
      compat_count <- refresh_result$compatibility_rows
```

Keep the existing outer `tryCatch()` so the user-facing error still starts with
`Force-apply failed:`. Remove the `DBI::dbRollback(sysndd_db)` call from that
outer error handler because `refresh_disease_ontology_set()` owns the
transaction lifecycle. The handler should end with:

```r
    error = function(e) {
      stop(paste("Force-apply failed:", conditionMessage(e)), call. = FALSE)
    }
```

Do not move re-review batch creation into the metadata refresh transaction.

- [ ] **Step 5: Run tests after ontology changes**

Run:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-metadata-refresh.R')"
```

Expected: PASS.

Run:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-async-job-handlers.R')"
```

Expected: PASS.

Run:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-metadata-refresh-patterns.R')"
```

Expected at this point: FAIL only if the synchronous HGNC endpoint still has
`TRUNCATE TABLE non_alt_loci_set`. There should be no remaining executable
`TRUNCATE TABLE disease_ontology_set` hits, and no dead inline admin executor
body hits.

- [ ] **Step 6: Checkpoint ontology refresh changes if the repo is clean**

Run:

```bash
git status --short
```

Expected: ontology-related source files and tests are the only changed files.

Then commit:

```bash
git add api/endpoints/admin_endpoints.R api/functions/async-job-handlers.R api/tests/testthat/test-unit-metadata-refresh.R api/tests/testthat/test-unit-metadata-refresh-patterns.R api/tests/testthat/test-unit-async-job-handlers.R
git commit -m "fix: make ontology metadata refresh rollback-safe"
```

Expected: commit succeeds. If unrelated user changes are present, skip the checkpoint and report the dirty files.

---

### Task 4: Replace The Synchronous HGNC TRUNCATE Path

**Files:**
- Modify: `api/endpoints/admin_endpoints.R`
- Test: `api/tests/testthat/test-unit-metadata-refresh-patterns.R`
- Test: `api/tests/testthat/test-endpoint-admin.R`

- [ ] **Step 1: Wrap the HGNC delete and insert work in FK cleanup**

In `api/endpoints/admin_endpoints.R`, replace the body of the
`db_with_transaction(function(txn_conn) { ... })` block in
`PUT update_hgnc_data` with:

```r
        metadata_with_foreign_key_checks_disabled(txn_conn, function() {
          db_execute_statement("DELETE FROM non_alt_loci_set", conn = txn_conn)

          # Insert hgnc_data rows using dynamic column names
          if (nrow(hgnc_data) > 0) {
            cols <- names(hgnc_data)
            # Quote column names with backticks for MySQL (handles special chars like hyphens)
            quoted_cols <- paste0("`", cols, "`")
            bind_marks <- paste(rep("?", length(cols)), collapse = ", ")
            sql <- sprintf(
              "INSERT INTO non_alt_loci_set (%s) VALUES (%s)",
              paste(quoted_cols, collapse = ", "), bind_marks
            )
            for (i in seq_len(nrow(hgnc_data))) {
              # Convert row to unnamed list for anonymous SQL markers
              row_values <- unname(as.list(hgnc_data[i, ]))
              db_execute_statement(sql, row_values, conn = txn_conn)
            }
          }
        })
```

This preserves the existing dynamic insert behavior and endpoint response while
making the table replacement transactional.

- [ ] **Step 2: Run the static guard**

Run:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-metadata-refresh-patterns.R')"
```

Expected after this task: PASS with no executable metadata `TRUNCATE`
violations.

- [ ] **Step 3: Run admin endpoint structural tests**

Run:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-async-job-handlers.R')"
```

Expected: PASS.

Run:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-endpoint-admin.R')"
```

Expected: PASS.

- [ ] **Step 4: Checkpoint HGNC refresh changes if the repo is clean**

Run:

```bash
git status --short
```

Expected: `api/endpoints/admin_endpoints.R` and metadata refresh tests are the
only uncommitted files from this task.

Then commit:

```bash
git add api/endpoints/admin_endpoints.R api/tests/testthat/test-unit-metadata-refresh-patterns.R
git commit -m "fix: make synchronous HGNC refresh rollback-safe"
```

Expected: commit succeeds. If unrelated user changes are present, skip the checkpoint and report the dirty files.

---

### Task 5: Documentation And Final Verification

**Files:**
- Modify: `AGENTS.md`
- Test: targeted R tests, code-quality audit, whitespace checks, local CI gates when available.

- [ ] **Step 1: Add persistent repository guidance**

In `AGENTS.md`, add this bullet under `Stack-Specific Gotchas` near the DBI and
transaction guidance:

```markdown
- Metadata refreshes that need rollback semantics must not use MySQL `TRUNCATE`
  inside transaction code because `TRUNCATE` is DDL and auto-commits. Use
  `refresh_disease_ontology_set()` or
  `metadata_with_foreign_key_checks_disabled()` from
  `api/functions/metadata-refresh.R`; both restore `FOREIGN_KEY_CHECKS` with
  immediate cleanup. The static guard
  `api/tests/testthat/test-unit-metadata-refresh-patterns.R` enforces this for
  `disease_ontology_set` and `non_alt_loci_set`; extend it when adding new
  metadata tables.
```

- [ ] **Step 2: Run targeted tests for affected refresh paths**

Run:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-metadata-refresh.R')"
```

Expected: PASS.

Run:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-metadata-refresh-patterns.R')"
```

Expected: PASS.

Run:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-async-job-handlers.R')"
```

Expected: PASS.

Run:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-endpoint-admin.R')"
```

Expected: PASS.

Run:

```bash
cd api && Rscript --no-init-file -e "testthat::test_file('tests/testthat/test-unit-gnomad-enrichment-fallback.R')"
```

Expected: PASS.

- [ ] **Step 3: Run code-quality and whitespace checks**

Run:

```bash
make code-quality-audit
```

Expected: PASS.

Run:

```bash
git diff --check
```

Expected: no output and exit code 0.

- [ ] **Step 4: Run pre-commit if the environment permits**

Run:

```bash
make pre-commit
```

Expected when host R, Node, Docker, and the local test DB prerequisites are
available: PASS.

If this cannot run, record the exact blocker in the handoff, for example:

```text
make pre-commit not run: Docker daemon unavailable at unix:///var/run/docker.sock.
```

- [ ] **Step 5: Run local CI if the environment permits**

Run:

```bash
make ci-local
```

Expected when the full local CI environment is available: PASS.

If this cannot run, record the exact blocker in the handoff, for example:

```text
make ci-local not run: RMariaDB cannot load libmariadb on this host; HOST_R_LD_LIBRARY_PATH needs configuration.
```

- [ ] **Step 6: Review the diff for quality risks**

Run:

```bash
git diff --stat
```

Expected: changes are limited to the files in this plan.

Run:

```bash
git diff -- api/functions/metadata-refresh.R api/endpoints/admin_endpoints.R api/functions/async-job-handlers.R AGENTS.md
```

Review expectations:

- No executable `TRUNCATE TABLE disease_ontology_set`.
- No executable `TRUNCATE TABLE non_alt_loci_set`.
- No dead inline `executor_fn = function(...)` bodies remain for
  `omim_update` or `force_apply_ontology` in `api/endpoints/admin_endpoints.R`.
- `.async_job_run_force_apply_ontology()` no longer calls
  `DBI::dbRollback(sysndd_db)` from its outer error handler.
- FK checks are restored by `metadata_with_foreign_key_checks_disabled()`.
- The oversized files `api/endpoints/admin_endpoints.R` and
  `api/functions/async-job-handlers.R` do not grow from copied helper logic.
- Service/helper function names do not collide with repository function names.
- API response field names and job result field names are unchanged.

- [ ] **Step 7: Final checkpoint commit if the repo is clean**

Run:

```bash
git status --short
```

Expected: only documentation or verification-era files remain uncommitted.

Then commit:

```bash
git add AGENTS.md
git commit -m "docs: document rollback-safe metadata refreshes"
```

Expected: commit succeeds. If prior checkpoints were skipped because the repo
was dirty, make one final scoped commit only if it contains exclusively the
implementation files from this plan and no unrelated user changes.

---

## Handoff Notes For Implementers

- The current durable `create_job()` facade ignores inline `executor_fn` bodies,
  so this plan deletes the two flagged dead inline ontology executor blocks
  instead of hardening unreachable code.
- The durable worker sources worker-executed code once at startup. Restart the
  worker container before manually validating changed async handler behavior.
- If implementation pauses between Task 1 and Task 4, the static guard test is
  expected to fail. Do not push an intermediate state with expected failing
  tests to a CI-protected branch.
- Do not change public API contracts or frontend behavior in this phase.
- Do not expand into the other second-wave review items listed in the design
  non-goals.
