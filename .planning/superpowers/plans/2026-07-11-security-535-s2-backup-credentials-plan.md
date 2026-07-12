# S2 — DB Secrets Out of Backup Jobs (argv / shell / payload) — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop the database password from being persisted into `async_jobs.request_payload_json`, from appearing in `mysqldump`/`mysql` process argv, and from being interpolated into a `system()` shell string — for the durable **backup create/restore** job family (audit finding P1-1) — by having the worker resolve credentials from its own runtime config and by passing them to the MySQL CLIs through a mode-0600 option file.

**Architecture:** The submit site already reads `password = dw$password` and serializes it into the durable job payload; the durable worker (`start_async_worker.R:28`) holds the **identical** `dw` global. So we introduce one reusable resolver, `async_job_worker_db_config()`, that the durable backup handlers call at run time — the payload no longer carries any credential. `execute_mysqldump()`/`execute_restore()` write the password into a `tempfile` `[client]` option file created mode-0600 and invoke the CLIs with `--defaults-extra-file=…` (no `-p`), removing the secret from argv and from the restore shell string. Historical payload rows are redacted by an idempotent scrub (best-effort API-startup hook + operator script). This is a **pure security change with zero behavioral change**: the worker's `dw` is the same object the API read `dw$password` from.

**Tech Stack:** R / Plumber / testthat; MySQL CLI option files (`--defaults-extra-file`); native `async_jobs.request_payload_json` JSON column (MySQL `JSON_SET`/`JSON_EXTRACT`).

## Global Constraints

- Keep every touched file **< 600 lines** (`make code-quality-audit`). Extract cohesive helpers rather than growing files.
- **`config::get` masks `base::get`** in the loaded API/worker env (no `mode` arg; signature `get(value, config, file, use_parent)`). NEVER call bare `get("dw", envir=…)` — it raises `unused argument (envir=…)`. Reference `dw` as a **bare symbol** (lexical global) or use `base::get` explicitly. (`exists()` is *not* masked.)
- **Namespace `dplyr`/`DBI` verbs** explicitly; several loaded packages mask them.
- The `api/tests/` dir is **not** bind-mounted into the container. Run a test file via:
  `docker cp <file> sysndd-api-1:/app/tests/testthat/ && docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/<file>')"`.
- **Worker-executed code is sourced at worker start** — after changing handler/resolver code, **restart the worker container** before a live check reflects it.
- **No numbered DB migration.** The scrub is data-cleanup on an existing column, deliberately not a schema migration, to avoid colliding with the unmerged `043_add_user_session_epoch.sql` on PR #538. Latest migration on `master` is `042`.
- **Credential rotation is operator work** (§ Task 6 runbook), NOT executed by this change. The code fix stops *new* leakage and scrubs *old* payloads; because the password may already exist in prior backups/logs, the operator must rotate it after deploy.

---

## Scope boundary (S2 now vs S2b follow-up)

This PR fixes the **backup** family only — the finding the audit cites at file/line, and the only family that *also* leaks via argv + a `system()` shell string. The **same** credential-in-payload pattern exists in ~6 other durable families (publication refresh/backfill, hgnc/ontology/comparisons, omim apply, provider handlers, pubtator, llm-batch). Those are payload-JSON-only (lower severity) and are migrated to the identical `async_job_worker_db_config()` resolver in follow-up **S2b**. To make that ratchet enforceable, Task 5 adds a guard that scans **all** submit services and asserts none inject a raw password, with an explicit, documented allowlist of the not-yet-migrated S2b families; S2b removes the allowlist entries as it migrates each.

---

### Task 1: Credential-free `mysqldump` / `mysql` invocation (argv + shell) in `backup-functions.R`

**Files:**
- Modify: `api/functions/backup-functions.R` (`execute_mysqldump` `:189-360`, `execute_restore` `:393-457`)
- Test: `api/tests/testthat/test-unit-backup-credential-safety.R` (new)

**Interfaces:**
- Produces:
  - `.backup_option_file_content(db_config)` → character scalar: a MySQL `[client]` option-file body containing `password=…` (quoted/escaped), no other secret.
  - `.backup_write_option_file(db_config)` → character path to a freshly-created **mode-0600** tempfile containing that body.
  - `.backup_mysqldump_args(db_config, option_file)` → character vector for `system2("mysqldump", …)`: `--defaults-extra-file=<file>` **first**, then `-h/-P/-u`, dump flags, and `dbname`; **no `-p`**.
  - `.backup_restore_command(db_config, option_file, restore_file, is_gzipped)` → character scalar shell command using `mysql --defaults-extra-file=<file>`; **no `-p`**; file paths `shQuote`d.

- [ ] **Step 1: Write the failing test (pure builders never expose the password)**

Create `api/tests/testthat/test-unit-backup-credential-safety.R`:

```r
# Verifies the backup CLI invocation never carries the DB password in argv or a
# shell string, and that the password only ever lands in a mode-0600 option file.
source_api_file("functions/backup-functions.R", local = FALSE)

cfg <- list(dbname = "sysndd_db", host = "db", user = "root",
            password = "s3cr#t \"pw\\x", port = 3306L)

test_that("mysqldump args carry --defaults-extra-file and never the password", {
  opt <- "/tmp/opt.cnf"
  args <- .backup_mysqldump_args(cfg, opt)
  expect_equal(args[[1]], paste0("--defaults-extra-file=", opt))
  expect_false(any(grepl(cfg$password, args, fixed = TRUE)))
  expect_false(any(grepl("^-p", args)))
  expect_true("sysndd_db" %in% args)
})

test_that("restore command carries --defaults-extra-file and never the password", {
  opt <- "/tmp/opt.cnf"
  cmd_gz <- .backup_restore_command(cfg, opt, "/backup/x.sql.gz", TRUE)
  cmd_sql <- .backup_restore_command(cfg, opt, "/backup/x.sql", FALSE)
  for (cmd in list(cmd_gz, cmd_sql)) {
    expect_true(grepl("--defaults-extra-file=", cmd, fixed = TRUE))
    expect_false(grepl(cfg$password, cmd, fixed = TRUE))
    expect_false(grepl("-p'", cmd, fixed = TRUE))
  }
  expect_true(grepl("gunzip -c", cmd_gz, fixed = TRUE))
})

test_that("option file contains the password and is written mode 0600", {
  body <- .backup_option_file_content(cfg)
  expect_true(grepl("[client]", body, fixed = TRUE))
  expect_true(grepl(cfg$password, body, fixed = TRUE))

  path <- .backup_write_option_file(cfg)
  on.exit(unlink(path), add = TRUE)
  expect_true(file.exists(path))
  # Mode 0600: owner rw, no group/other bits.
  mode <- file.info(path)$mode
  expect_equal(as.integer(mode), as.integer(as.octmode("600")))
  expect_true(any(grepl(cfg$password, readLines(path), fixed = TRUE)))
})
```

- [ ] **Step 2: Run to verify it FAILS** (builders undefined)

`docker cp api/tests/testthat/test-unit-backup-credential-safety.R sysndd-api-1:/app/tests/testthat/ && docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-unit-backup-credential-safety.R')"`
Expected: FAIL — `.backup_mysqldump_args` not found.

- [ ] **Step 3: Add the pure builders** to `backup-functions.R` (place directly above `execute_mysqldump`)

```r
#' Escape a value for a MySQL option-file quoted string.
.backup_optfile_escape <- function(x) {
  gsub('(["\\\\])', "\\\\\\1", as.character(x))  # backslash-escape " and \
}

#' MySQL [client] option-file body carrying ONLY the password (host/user/port
#' stay on the non-secret CLI). Password is double-quoted + escaped so values
#' with '#', spaces, or quotes are handled (MySQL option-file quoting rules).
.backup_option_file_content <- function(db_config) {
  paste0("[client]\n", 'password="', .backup_optfile_escape(db_config$password), '"\n')
}

#' Write the option-file body to a mode-0600 tempfile. Creates the file empty
#' with 0600 BEFORE writing the secret so it never briefly exists world-readable.
#' Caller is responsible for unlink() (use on.exit).
.backup_write_option_file <- function(db_config) {
  path <- tempfile(pattern = "mysql_opt_", fileext = ".cnf")
  file.create(path)
  Sys.chmod(path, mode = "0600", use_umask = FALSE)
  writeLines(.backup_option_file_content(db_config), path)
  path
}

#' mysqldump args using an option file; --defaults-extra-file MUST be first.
.backup_mysqldump_args <- function(db_config, option_file) {
  c(
    paste0("--defaults-extra-file=", option_file),
    "-h", db_config$host,
    "-P", as.character(db_config$port),
    "-u", db_config$user,
    "--single-transaction", "--routines", "--triggers", "--quick",
    db_config$dbname
  )
}

#' Restore shell command using an option file; no password on the CLI.
.backup_restore_command <- function(db_config, option_file, restore_file, is_gzipped) {
  base <- sprintf(
    "mysql --defaults-extra-file=%s -h %s -P %s -u %s %s",
    shQuote(option_file), db_config$host, as.character(db_config$port),
    db_config$user, db_config$dbname
  )
  if (is_gzipped) {
    sprintf("gunzip -c %s | %s", shQuote(restore_file), base)
  } else {
    sprintf("%s < %s", base, shQuote(restore_file))
  }
}
```

- [ ] **Step 4: Rewrite `execute_mysqldump` arg construction to use the option file**

Replace the `args <- c("-h", …, paste0("-p", db_config$password), …)` block (`:206-217`) with:

```r
  # Password is passed via a mode-0600 option file, never argv (#535 P1-1).
  option_file <- .backup_write_option_file(db_config)
  on.exit(unlink(option_file), add = TRUE)
  args <- .backup_mysqldump_args(db_config, option_file)
```

(Leave the `system2("mysqldump", args = args, …)` call and everything after unchanged.)

- [ ] **Step 5: Rewrite `execute_restore` command construction to use the option file**

Replace the `if (is_gzipped) { restore_cmd <- sprintf("… -p'%s' …") } else { … }` block (`:419-442`) with:

```r
  # Password is passed via a mode-0600 option file, never the shell command (#535 P1-1).
  option_file <- .backup_write_option_file(db_config)
  on.exit(unlink(option_file), add = TRUE)
  restore_cmd <- .backup_restore_command(db_config, option_file, restore_file, is_gzipped)
```

(Leave the `system(restore_cmd, …)` call and everything after unchanged.)

- [ ] **Step 6: Run the test to verify PASS**

`docker cp … && docker exec … test_file(… 'test-unit-backup-credential-safety.R')` → all PASS.

- [ ] **Step 7: Commit**

```bash
git add api/functions/backup-functions.R api/tests/testthat/test-unit-backup-credential-safety.R
git commit -m "fix(security): pass DB password to mysqldump/mysql via mode-0600 option file, not argv/shell (#535 P1-1)"
```

---

### Task 2: Reusable runtime credential resolver `async_job_worker_db_config()`

**Files:**
- Create: `api/functions/async-job-db-config.R`
- Modify: `api/bootstrap/load_modules.R` (source the new file **before** `functions/async-job-maintenance-handlers.R`)
- Test: `api/tests/testthat/test-unit-async-job-db-config.R` (new)

**Interfaces:**
- Produces: `async_job_worker_db_config(runtime_config = NULL)` → `list(dbname, host, user, password, port)`. With `runtime_config = NULL` it reads the worker global `dw` (bare symbol; errors clearly if `dw` is absent). The `runtime_config` param exists for injection in tests.

- [ ] **Step 1: Write the failing test**

Create `api/tests/testthat/test-unit-async-job-db-config.R`:

```r
source_api_file("functions/async-job-db-config.R", local = FALSE)

test_that("resolver returns the five connection fields from injected config", {
  cfg <- list(dbname = "d", host = "h", user = "u", password = "p", port = 3306L, extra = "x")
  out <- async_job_worker_db_config(runtime_config = cfg)
  expect_equal(out, list(dbname = "d", host = "h", user = "u", password = "p", port = 3306L))
})

test_that("resolver errors clearly when no runtime config is available", {
  # No 'dw' in this test scope and none injected.
  if (exists("dw", inherits = TRUE)) skip("dw present in test env")
  expect_error(async_job_worker_db_config(), "runtime config", ignore.case = TRUE)
})
```

- [ ] **Step 2: Run to verify FAIL** (file/function missing).

- [ ] **Step 3: Implement the resolver**

Create `api/functions/async-job-db-config.R`:

```r
# api/functions/async-job-db-config.R
#
# Single source of truth for how a durable async job handler obtains the
# database credentials it needs. The worker holds the same `dw` runtime config
# object the API read `dw$password` from at submit time, so handlers resolve
# credentials HERE at run time instead of receiving them through the job
# payload (which persists in async_jobs.request_payload_json). Introduced for
# #535 P1-1; extended to all durable families in S2b.
#
# NOTE: `config::get` masks `base::get` in the loaded env, so we reference `dw`
# as a bare symbol (lexical global), never `get("dw", ...)`.

#' Resolve DB connection config for a durable worker handler.
#'
#' @param runtime_config Optional injected config (for tests). When NULL, reads
#'   the worker global `dw`.
#' @return list(dbname, host, user, password, port)
#' @export
async_job_worker_db_config <- function(runtime_config = NULL) {
  cfg <- runtime_config
  if (is.null(cfg)) {
    if (!exists("dw", inherits = TRUE)) {
      stop("async_job_worker_db_config(): 'dw' runtime config unavailable in this process",
           call. = FALSE)
    }
    cfg <- dw
  }
  list(
    dbname   = cfg$dbname,
    host     = cfg$host,
    user     = cfg$user,
    password = cfg$password,
    port     = cfg$port
  )
}
```

- [ ] **Step 4: Register in the module loader**

In `api/bootstrap/load_modules.R`, add `"functions/async-job-db-config.R"` to the sourced list **before** `"functions/async-job-maintenance-handlers.R"` (so the resolver exists when handlers are defined/called). Verify with:
`grep -n "async-job-db-config\|async-job-maintenance-handlers" api/bootstrap/load_modules.R` — the db-config line must appear first.

- [ ] **Step 5: Run the test to verify PASS.**

- [ ] **Step 6: Commit**

```bash
git add api/functions/async-job-db-config.R api/bootstrap/load_modules.R api/tests/testthat/test-unit-async-job-db-config.R
git commit -m "feat(api): add async_job_worker_db_config() runtime credential resolver (#535 P1-1)"
```

---

### Task 3: Backup handlers resolve at run time; backup submit stops carrying the credential

**Files:**
- Modify: `api/functions/async-job-maintenance-handlers.R` (`.async_job_run_backup_create` `:14`, `.async_job_run_backup_restore` `:38`)
- Modify: `api/services/backup-endpoint-service.R` (`.svc_backup_db_config` `:20`, `svc_backup_create` `:133`, `svc_backup_restore` `:193`)
- Test: `api/tests/testthat/test-unit-backup-endpoint-service.R` (rewrite the executor-closure section), `api/tests/testthat/test-unit-async-job-maintenance-handlers.R` (add handler tests; create if absent)

**Interfaces:**
- Consumes: `async_job_worker_db_config()` (Task 2), `execute_mysqldump`/`execute_restore` (Task 1).
- Produces: backup submit params `list(backup_dir, backup_filename)` / `list(restore_file, backup_dir)` — **no `db_config`**. Backup handlers build `db_config <- async_job_worker_db_config()`.

- [ ] **Step 1: Invert the stale endpoint-test assertions (write failing expectations)**

In `api/tests/testthat/test-unit-backup-endpoint-service.R`:
- The executor-closure capture tests (`capture_restore_executor` and its users, ~`:308-369`) test **dead code** — `create_job()` ignores `executor_fn` — and assert `db_config` is *passed through* (`:352`). Replace that whole block with a params-shape assertion:

```r
test_that("svc_backup_create/restore submit NO credential in job params (#535 P1-1)", {
  env <- backup_test_env()  # existing helper that sources the service with stubs
  captured <- new.env()
  env$check_duplicate_job <- function(operation, params) list(duplicate = FALSE)
  env$create_job <- function(operation, params, executor_fn = NULL, timeout_ms = NULL) {
    captured$params <- params; list(job_id = "j1")
  }
  env$file.exists <- function(...) TRUE
  env$is_valid_backup_filename <- function(...) TRUE
  res <- list(status = 200L, setHeader = function(...) invisible(NULL))

  env$svc_backup_create(req = list(), res = res)
  expect_false("db_config" %in% names(captured$params))
  expect_false(any(grepl("password", unlist(captured$params), fixed = TRUE)))

  env$svc_backup_restore(req = list(argsBody = list(filename = "b.sql.gz")), res = res)
  expect_false("db_config" %in% names(captured$params))
})
```

(Adapt `backup_test_env()`/stub names to the file's existing harness — reuse whatever `env` builder the current tests use at `:76`/`:315`.)

- [ ] **Step 2: Run to verify FAIL** (params still contain `db_config`).

- [ ] **Step 3: Drop the credential from the backup submit sites**

In `api/services/backup-endpoint-service.R`:
- Delete the `.svc_backup_db_config` helper (`:19-22`) — now unused.
- In `svc_backup_create`: delete `db_config <- .svc_backup_db_config()` (`:144`); change the `create_job(...)` call to:

```r
  result <- create_job(
    operation = "backup_create",
    params = list(
      backup_dir = "/backup",
      backup_filename = backup_filename
    ),
    executor_fn = NULL  # execution is the durable .async_job_run_backup_create handler
  )
```

(Removing the dead inline `executor_fn` closure also removes its now-dangling `params$db_config` reads. `create_job()` requires the `executor_fn` arg but ignores it, so pass `NULL`; `timeout_ms` has a default and is likewise ignored — omit it.)

- In `svc_backup_restore`: delete `db_config <- .svc_backup_db_config()` (`:232`); change the `create_job(...)` call to:

```r
  result <- create_job(
    operation = "backup_restore",
    params = list(
      restore_file = backup_path,
      backup_dir = "/backup"
    ),
    executor_fn = NULL  # execution is the durable .async_job_run_backup_restore handler
  )
```

- [ ] **Step 4: Backup handlers resolve credentials at run time**

In `api/functions/async-job-maintenance-handlers.R`:
- `.async_job_run_backup_create`: add `db_config <- async_job_worker_db_config()` as the first statement after `progress <- …`; change `execute_mysqldump(payload$db_config, …)` → `execute_mysqldump(db_config, …)`.
- `.async_job_run_backup_restore`: add `db_config <- async_job_worker_db_config()` after `progress <- …`; change both `execute_mysqldump(payload$db_config, …)` (pre-restore) and `execute_restore(payload$db_config, …)` → use `db_config`.

- [ ] **Step 5: Add durable-handler tests (the live path)**

Create/extend `api/tests/testthat/test-unit-async-job-maintenance-handlers.R`:

```r
source_api_file("functions/async-job-db-config.R", local = FALSE)
source_api_file("functions/async-job-maintenance-handlers.R", local = FALSE)

test_that("backup_create handler resolves db_config from runtime, not payload", {
  seen <- new.env()
  local_mocked_bindings(
    async_job_worker_db_config = function(...) list(dbname="d",host="h",user="u",password="RUNTIME",port=3306L),
    execute_mysqldump = function(db_config, output_file, ...) { seen$pw <- db_config$password; list(success = TRUE, file = output_file, size_bytes = 10, compressed = TRUE) },
    .package = NULL
  )
  job <- list(job_id = "j1")
  payload <- list(backup_dir = "/backup", backup_filename = "m.sql")  # NOTE: no db_config
  out <- .async_job_run_backup_create(job, payload, state = NULL, worker_config = NULL)
  expect_equal(out$status, "completed")
  expect_equal(seen$pw, "RUNTIME")  # came from resolver, not payload
})
```

(If `testthat::local_mocked_bindings` is unavailable in the container's testthat, fall back to the repo's established sandbox pattern: source into an `env`, assign stub `execute_mysqldump`/`async_job_worker_db_config` into that env, and call the handler from it. Match whatever `test-unit-async-job-handlers.R` already uses.)

- [ ] **Step 6: Run both test files to verify PASS.**

- [ ] **Step 7: Commit**

```bash
git add api/functions/async-job-maintenance-handlers.R api/services/backup-endpoint-service.R api/tests/testthat/test-unit-backup-endpoint-service.R api/tests/testthat/test-unit-async-job-maintenance-handlers.R
git commit -m "fix(security): backup jobs resolve DB creds at run time; payload no longer carries password (#535 P1-1)"
```

---

### Task 4: Redact credentials from historical `async_jobs.request_payload_json`

**Files:**
- Create: `api/functions/async-job-payload-scrub.R` (pure SQL builder + runner)
- Create: `api/scripts/scrub-job-payload-credentials.R` (operator entrypoint)
- Modify: `api/bootstrap/load_modules.R` (source the new function file), `api/start_sysndd_api.R` (best-effort startup hook after migrations)
- Test: `api/tests/testthat/test-unit-async-job-payload-scrub.R` (new)

**Interfaces:**
- Produces:
  - `async_job_payload_scrub_statements()` → character vector of idempotent `UPDATE async_jobs … JSON_SET(…, '$.db_config.password', '***REDACTED***')` statements (one per known secret JSON path: `$.db_config.password`, `$.db_config.db_password`, `$.db_password`), each guarded so already-redacted rows are untouched.
  - `async_job_scrub_payload_credentials(conn = NULL)` → integer count of rows redacted; best-effort.
  - `async_job_scrub_payload_credentials_on_startup()` → wraps the above in `tryCatch`, gated by env `ASYNC_JOB_PAYLOAD_SCRUB_ON_STARTUP` (default `"true"`), never throws.

- [ ] **Step 1: Write the failing test (statements are idempotent + target the secret paths)**

```r
source_api_file("functions/async-job-payload-scrub.R", local = FALSE)

test_that("scrub statements target every known secret path and skip redacted rows", {
  stmts <- async_job_payload_scrub_statements()
  blob <- paste(stmts, collapse = "\n")
  expect_true(grepl("$.db_config.password", blob, fixed = TRUE))
  expect_true(grepl("$.db_config.db_password", blob, fixed = TRUE))
  expect_true(grepl("$.db_password", blob, fixed = TRUE))
  expect_true(all(grepl("REDACTED", stmts)))
  # Idempotency guard: each UPDATE must exclude already-redacted rows.
  expect_true(all(grepl("<> '\\*\\*\\*REDACTED\\*\\*\\*'|<> \"\\*\\*\\*REDACTED\\*\\*\\*\"", stmts) |
                    grepl("REDACTED", stmts)))
})
```

- [ ] **Step 2: Run to verify FAIL.**

- [ ] **Step 3: Implement the scrub module**

Create `api/functions/async-job-payload-scrub.R`:

```r
# api/functions/async-job-payload-scrub.R
#
# Redacts DB credentials that older code persisted into
# async_jobs.request_payload_json (native JSON column). Idempotent: only rows
# whose secret path exists AND is not already the sentinel are touched. Runs
# best-effort at API startup and via api/scripts/scrub-job-payload-credentials.R.

ASYNC_JOB_PAYLOAD_SCRUB_SENTINEL <- "***REDACTED***"

.async_job_payload_scrub_paths <- c("$.db_config.password", "$.db_config.db_password", "$.db_password")

#' Idempotent UPDATE statements, one per known secret JSON path.
#' @export
async_job_payload_scrub_statements <- function(paths = .async_job_payload_scrub_paths,
                                               sentinel = ASYNC_JOB_PAYLOAD_SCRUB_SENTINEL) {
  vapply(paths, function(p) {
    sprintf(
      paste0(
        "UPDATE async_jobs SET request_payload_json = JSON_SET(request_payload_json, '%s', '%s') ",
        "WHERE JSON_EXTRACT(request_payload_json, '%s') IS NOT NULL ",
        "AND JSON_UNQUOTE(JSON_EXTRACT(request_payload_json, '%s')) <> '%s'"
      ),
      p, sentinel, p, p, sentinel
    )
  }, character(1), USE.NAMES = FALSE)
}

#' Execute the scrub. Returns total rows affected. Best-effort caller supplies conn.
#' @export
async_job_scrub_payload_credentials <- function(conn = NULL) {
  stmts <- async_job_payload_scrub_statements()
  total <- 0L
  for (s in stmts) {
    total <- total + as.integer(db_execute_statement(s, list(), conn = conn) %||% 0L)
  }
  total
}

#' Best-effort startup hook (never throws, env-gated).
#' @export
async_job_scrub_payload_credentials_on_startup <- function() {
  if (!identical(tolower(Sys.getenv("ASYNC_JOB_PAYLOAD_SCRUB_ON_STARTUP", "true")), "true")) {
    return(invisible(FALSE))
  }
  tryCatch({
    n <- async_job_scrub_payload_credentials()
    if (n > 0) logger::log_info("Scrubbed credentials from {n} async_jobs payload row(s)")
    invisible(TRUE)
  }, error = function(e) {
    logger::log_warn("async_jobs payload credential scrub skipped: {conditionMessage(e)}")
    invisible(FALSE)
  })
}
```

Create `api/scripts/scrub-job-payload-credentials.R`:

```r
#!/usr/bin/env Rscript
# Operator entrypoint: redact DB credentials from historical async_jobs payloads.
# Idempotent. Run inside the API/worker container after deploy.
suppressWarnings(source("/app/bootstrap/load_modules.R"))
bootstrap_load_modules()
n <- async_job_scrub_payload_credentials()
cat(sprintf("Redacted credentials from %d async_jobs payload row(s).\n", n))
```

- [ ] **Step 4: Wire the startup hook**

In `api/bootstrap/load_modules.R`: source `"functions/async-job-payload-scrub.R"` (any position after `db-helpers.R`).
In `api/start_sysndd_api.R`: after the migration runner block (near the other `_on_startup()` bootstraps), add `async_job_scrub_payload_credentials_on_startup()`. Confirm placement with `grep -n "on_startup\|run_migrations" api/start_sysndd_api.R`.

- [ ] **Step 5: Run the unit test to verify PASS.**

- [ ] **Step 6: Live idempotency check (container)** — insert a fake payload row, run the operator script twice, assert first run redacts and second run affects 0 rows:

```bash
docker exec sysndd-api-1 Rscript -e '
  source("/app/bootstrap/load_modules.R"); bootstrap_load_modules();
  db_execute_statement("INSERT INTO async_jobs (job_id, job_type, status, request_payload_json, created_at) VALUES (\"scrub-test\",\"backup_create\",\"completed\",\"{\\\"db_config\\\":{\\\"password\\\":\\\"leaky\\\"}}\", NOW())", list());
  cat("run1:", async_job_scrub_payload_credentials(), "\n");
  cat("run2:", async_job_scrub_payload_credentials(), "\n");
  cat(db_get_query("SELECT request_payload_json FROM async_jobs WHERE job_id=\"scrub-test\"")$request_payload_json, "\n");
  db_execute_statement("DELETE FROM async_jobs WHERE job_id=\"scrub-test\"", list())'
```
Expected: `run1: 1`, `run2: 0`, payload shows `***REDACTED***`. (Adjust `db_get_query` to the repo's actual read helper name.)

- [ ] **Step 7: Commit**

```bash
git add api/functions/async-job-payload-scrub.R api/scripts/scrub-job-payload-credentials.R api/bootstrap/load_modules.R api/start_sysndd_api.R api/tests/testthat/test-unit-async-job-payload-scrub.R
git commit -m "fix(security): scrub DB credentials from historical async_jobs payloads (idempotent, startup + operator script) (#535 P1-1)"
```

---

### Task 5: Regression guard + documentation

**Files:**
- Create: `api/tests/testthat/test-unit-job-payload-credential-guard.R`
- Modify: `documentation/09-deployment.qmd` (operator runbook: option-file mechanism, mandatory credential rotation, scrub)
- Modify: `AGENTS.md` (Background jobs section: credentials resolved at run time via `async_job_worker_db_config()`, never in payload/argv)

**Interfaces:**
- Produces: a static guard asserting backup submit services carry no credential, and a broad scan of all `api/services/*submission*.R` + `backup-endpoint-service.R` for raw `password = dw$password` inside a `params`/`request_payload` list, with an explicit allowlist of the S2b-pending families.

- [ ] **Step 1: Write the guard test**

```r
# Ensures the backup family never reintroduces a credential into a durable job
# payload, and that no NEW submit site does (S2b migrates the allowlisted ones).
test_that("backup submit services carry no DB credential", {
  src <- paste(readLines("../../services/backup-endpoint-service.R"), collapse = "\n")
  expect_false(grepl("db_config\\s*=", src), info = "backup submit must not put db_config in params")
  expect_false(grepl("\\.svc_backup_db_config", src), info = "dead credential helper must be gone")
})

test_that("no unexpected submit site injects a raw DB password into a job payload", {
  # Families still carrying db_config in payload, tracked for S2b removal.
  allow <- c("job-maintenance-submission-service.R", "admin-ontology-endpoint-service.R",
             "admin-publication-refresh-endpoint-service.R", "publication-admin-endpoint-service.R")
  files <- list.files("../../services", pattern = "\\.R$", full.names = TRUE)
  offenders <- Filter(function(f) {
    if (basename(f) %in% allow) return(FALSE)
    src <- paste(readLines(f), collapse = "\n")
    grepl("password\\s*=\\s*dw\\$password", src)
  }, files)
  expect_equal(length(offenders), 0L, info = paste("credential in payload:", paste(basename(offenders), collapse = ", ")))
})
```

(Verify the relative path prefix `../../services` matches how other `test-unit-*` files read `api/services` in this repo; adjust to the established helper if one exists.)

- [ ] **Step 2: Run to verify PASS** (backup already fixed in Task 3; allowlist covers the rest).

- [ ] **Step 3: Document** in `documentation/09-deployment.qmd` under a new "Backup credential handling (#535)" note:
  - The MySQL CLIs receive the password through a per-invocation **mode-0600 `--defaults-extra-file`**, never argv/shell.
  - Durable job payloads **no longer contain** DB credentials; the worker resolves them from its runtime `dw` config via `async_job_worker_db_config()`.
  - **Mandatory operator step after deploy:** because prior payloads/backups/logs may have contained the password, **rotate the DB password** and update the deployed `.env`/secret; then restart api + worker + worker-maintenance. Run `Rscript /app/scripts/scrub-job-payload-credentials.R` (also runs best-effort at API startup) to redact historical payload rows.
  - **S2b follow-up:** the remaining durable families (publication/hgnc/ontology/comparisons/omim/provider/pubtator/llm-batch) still carry `db_config` in payload and will be migrated to the same resolver.

- [ ] **Step 4: Update `AGENTS.md`** Background jobs section with one paragraph: durable handlers resolve DB credentials at run time via `async_job_worker_db_config()` (worker `dw`), never from the payload; the MySQL CLIs use a mode-0600 option file; a static guard (`test-unit-job-payload-credential-guard.R`) prevents regressions and allowlists the S2b-pending families.

- [ ] **Step 5: Commit**

```bash
git add api/tests/testthat/test-unit-job-payload-credential-guard.R documentation/09-deployment.qmd AGENTS.md
git commit -m "test+docs(security): guard against DB credentials in job payloads; document backup credential handling + rotation (#535 P1-1)"
```

---

### Task 6: Verify, self-review, and open PR

- [ ] **Step 1: File-size ratchet** — `make code-quality-audit`. All touched files < 600 lines (backup-endpoint-service.R shrinks; new files are small).
- [ ] **Step 2: Targeted API tests in the container** — run the four new/edited test files plus the pre-existing `test-unit-backup-endpoint-service.R` and `test-unit-async-job-handlers.R` to confirm no regression.
- [ ] **Step 3: Fast PR gate** — `make test-api-fast`.
- [ ] **Step 4: Live worker smoke (where feasible)** — restart the worker container; submit a `backup_create` via the API; confirm the job completes and that `SELECT request_payload_json FROM async_jobs WHERE job_type='backup_create' ORDER BY created_at DESC LIMIT 1` contains **no** password key. Confirm `ps` during a dump shows no `-p<pw>` (option-file path only).
- [ ] **Step 5: Self-review vs the audit finding** — the password no longer appears in (a) `request_payload_json`, (b) `mysqldump` argv, (c) the restore `system()` shell string; historical rows are redacted; a guard prevents regression; rotation is documented as operator work.
- [ ] **Step 6: Push branch, open PR** referencing #535 P1-1, list the S2b follow-up scope, and mark **do not auto-merge** (security-critical; awaits human sign-off + Codex diff review).

---

## Codex adversarial review — corrections folded (2026-07-11)

Full review saved at `.planning/reviews/2026-07-11-security-535-s2-plan-codex-review.md`. Codex confirmed
the core mechanism (option-file ordering, `create_job` ignoring `executor_fn`, durable dispatch, JSON
idempotency, no new migration, file sizes < 600). These corrections **override** the task steps above where
they conflict:

**Blockers**
- **B1 + B2 — scrub is backup-scoped AND terminal-only; acceptance wording narrowed.** Every scrub UPDATE is
  restricted to `job_type IN ('backup_create','backup_restore') AND status IN ('completed','failed','cancelled')`,
  single JSON path `$.db_config.password`. This prevents redacting a *queued/retryable* job of the not-yet-migrated
  S2b families (whose handlers still read `payload$db_config$password`) and keeps the generated `active_request_hash`
  column (NULL for terminal rows) + its unique index untouched. **This PR closes P1-1 for the backup family
  (payload) plus the argv/shell leak that is unique to backup**; the umbrella criterion "DB credentials never
  appear in *any* job JSON" is completed by **S2 + S2b together** — Task 5 docs and the self-review below say
  backup-family-scoped, NOT repository-wide.

**HIGH**
- **H1 — `.backup_write_option_file` is fail-closed.** Wrap in `old <- Sys.umask("0077"); on.exit(Sys.umask(old))`;
  `if (!file.create(path)) stop(...)`; `Sys.chmod(path, "0600", use_umask = FALSE)`; verify
  `bitwAnd(as.integer(file.info(path)$mode), as.integer(as.octmode("077"))) == 0L` else `unlink(path); stop(...)`;
  only then `writeLines`. Never write the secret to a file whose mode isn't proven 0600.
- **H2 — option-file tests assert the EXACT escaped body** (`password="s3cr#t \"pw\\x"`), and the "password
  present" check uses the escaped form. Add a **skip-guarded real-client integration test**: create a temp DB
  user whose password contains `#`, space, `"`, `\`, then run `mysql --defaults-extra-file=<file> -e 'SELECT 1'`;
  `skip()` if the test principal lacks `CREATE USER`.
- **H3 — preserve the restore safety contract.** Handler tests against `.async_job_run_backup_restore` must prove
  (a) the pre-restore `execute_mysqldump` runs **before** `execute_restore`, and (b) when the pre-backup fails
  (`execute_mysqldump` returns `success = FALSE`) the handler aborts and `execute_restore` is **never called**.
  Stub `.async_job_progress_reporter` (else the handler dies on its first statement), the resolver, `execute_mysqldump`,
  and `execute_restore`.
- **H4 — guard is a repository-wide exact offender-set.** Scan `api/functions`, `api/services`, `api/endpoints`
  for the credential-in-payload pattern and assert the offender set **equals** a frozen, documented list of the
  S2b-pending sites (backup **absent**). A new leak anywhere — even inside an already-listed file — changes the
  set and fails. (Replaces the whole-file allowlist.)
- **H5 — post-restore scrub.** `.async_job_run_backup_restore` calls the backup-scoped scrub **immediately after a
  successful restore, before reporting completion** — an old dump re-imports credential-bearing `async_jobs` rows.
- **H6 — scrub recomputes `request_hash`.** `request_hash = SHA2(CONCAT(job_type, ':', <redacted-payload-expr>), 256)`
  in the same UPDATE (the hash `digest::digest(paste0(job_type, ":", payload_json), "sha256")` otherwise remains a
  password-derived verifier permitting offline guessing). Terminal-only scope keeps `active_request_hash` untouched.
  Operator **credential rotation remains the primary mitigation** (documented in Task 5).

The Task 4 scrub statement becomes a **single** UPDATE:

```sql
UPDATE async_jobs
SET request_hash = SHA2(CONCAT(job_type, ':', JSON_SET(request_payload_json, '$.db_config.password', '***REDACTED***')), 256),
    request_payload_json = JSON_SET(request_payload_json, '$.db_config.password', '***REDACTED***')
WHERE job_type IN ('backup_create','backup_restore')
  AND status IN ('completed','failed','cancelled')
  AND JSON_EXTRACT(request_payload_json, '$.db_config.password') IS NOT NULL
  AND JSON_UNQUOTE(JSON_EXTRACT(request_payload_json, '$.db_config.password')) <> '***REDACTED***';
```

`async_job_payload_scrub_statements()` returns this one statement (constant sentinel `***REDACTED***`);
`async_job_scrub_payload_credentials()` runs it and returns the (now truly distinct) affected-row count.

**MEDIUM**
- **M1 — resolver sourced for durable + mirai parity.** Add `functions/async-job-db-config.R` to
  `bootstrap/load_modules.R` **and** the `bootstrap/setup_workers.R` mirai `everywhere({...})` block. The resolver
  uses `base::exists("dw", envir = .GlobalEnv)` / `base::get("dw", envir = .GlobalEnv)` (NOT bare `get`, which
  `config::get` masks). Correction to Task 2 text: the maintenance handler is sourced via the worker entrypoint,
  not a literal line in `load_modules.R`; sourcing the resolver in the loader is sufficient because R resolves the
  symbol at **call** time.
- **M2 — `.backup_restore_command` `shQuote()`s host/user/dbname too**, and coerces port with `as.integer`.
- **M3 — scrub idempotency test** asserts the exact `WHERE` predicate and adds a transaction-isolated DB test:
  run1 redacts exactly one seeded terminal backup row, run2 affects zero.
- **M4 — DB test fixtures use real columns.** Insert with `request_hash` + `submitted_at` (NOT `created_at`),
  status `'completed'`, inside `with_test_db_transaction()`; or submit via `async_job_service_submit()`.
- **M5 — single UPDATE** (folded into H6 above) → accurate distinct-row count; log "backup payload row(s) redacted".

**LOW**
- **L1 — stale option-file cleanup.** Best-effort `unlink(Sys.glob(file.path(tempdir(), "mysql_opt_*.cnf")))` at
  worker start (add a tiny `async_job_backup_cleanup_stale_option_files()` called from the worker bootstrap).
- **L2 — resolver validates** the five scalar fields are non-empty and `port` coerces to a finite positive integer,
  WITHOUT echoing any credential value in the error.
- **L3 — symlink restore/download surface** (`latest.*`): **out of S2 secrets scope** (not a credential leak);
  recorded as an S3/S8 follow-up.

## Self-Review (writing-plans)

- **Spec coverage (issue P1-1) — scoped to the BACKUP family (not repo-wide; see B1/B2):** payload JSON for backup → Task 3 (submit drops db_config) + Task 4 (terminal backup-row scrub); argv → Task 1 (`--defaults-extra-file`, no `-p`); shell string → Task 1 (restore command); "workers resolve secrets from runtime configuration" → Task 2; "mode-0600 defaults file" → Task 1 (fail-closed); "scrub retained payloads" → Task 4 (backup-scoped) + post-restore (H5); "rotate the credential" → Task 6 runbook (operator, primary mitigation for H6); "retention and regression guards" → Task 5 (repo-wide exact offender-set). **The other ~6 durable families still carry `db_config` in payload and are migrated to the same resolver in S2b; this PR does NOT claim repository-wide durable-job credential compliance — S2 + S2b together satisfy the umbrella acceptance criterion.**
- **Placeholder scan:** none — every step carries concrete code/commands. Test-harness stubs are flagged to match the file's existing pattern where the exact helper name must be confirmed at implementation time.
- **Type consistency:** `async_job_worker_db_config()` returns the same 5-field list the payload used to carry; `.backup_*` builders take `(db_config, option_file[, …])` consistently; scrub sentinel `***REDACTED***` is one constant reused across statements and the idempotency guard.
