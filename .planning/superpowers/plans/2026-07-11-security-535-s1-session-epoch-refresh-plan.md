# S1 — Session-Epoch Role-Current, Revocable Refresh (#535 P0-2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make JWT refresh reflect current account state — a demoted/deactivated/epoch-bumped user cannot refresh stale privileges; a refresh either mints a token whose role/claims come from the DB, or is rejected (forcing re-login).

**Architecture:** Add a `session_epoch` integer to the `user` table. Every issued JWT carries the epoch as a `sepoch` claim. `auth_refresh()` stops trusting the presented token: it loads the current user by id from the DB, requires `approved == 1`, requires `sepoch == user.session_epoch`, and mints the new token from the DB row. Any privilege/state mutation increments `session_epoch` **in the same SQL statement and transaction** as the mutation (atomic — no separate bump), so a concurrent refresh reads either the whole old row (old epoch, still refreshable) or the whole new row (new epoch, old token rejected). The refresh DB read is the linearization point.

**Design choice (make explicit):** on a privilege/state change the epoch increments, so an outstanding token's `sepoch` no longer matches → **refresh is REJECTED and the user must re-login** (not silently downgraded). This is stronger than "mint the new role on refresh" and fully satisfies the acceptance criterion ("Demoted/deactivated users cannot refresh stale privileges"). Minting role/claims from the DB is defense-in-depth for any hypothetical mutation path that does not bump the epoch. Backend + one additive migration only — **no frontend change** (the SPA keeps its single-token model; `/api/auth/refresh` still reads the token from the `Authorization` header and returns a bare token string).

**Tech Stack:** R / Plumber, MySQL, testthat. `jose` JWT. dplyr/dbplyr DB access (namespace verbs — masking hazard). Migration runner with a manifest guard.

## Global Constraints

- Keep every touched file **< 600 lines** (`make code-quality-audit`).
- Additive migration only; **no** change to existing tables/columns. Idempotent DDL (restore-drift safe).
- Bump `EXPECTED_LATEST_MIGRATION` **and** `EXPECTED_MIGRATION_COUNT` (`migration-manifest.R:5-6`) **and all four stale guard assertions** (Codex MEDIUM-9): `test-unit-core-views-manifest.R` name `:13`, count `:14`, `res$latest` `:21`; `test-unit-analysis-snapshot-migration.R` name `:8`, count `:9`. A stale manifest is a **fatal startup error** by design — do not weaken it.
- **Namespace all dplyr/dbplyr verbs** in `auth_refresh` (`dplyr::tbl`, `dplyr::filter(.data$user_id == !!uid)`, `dplyr::rename`, `dplyr::collect`) — the loaded env masks dplyr verbs (biomaRt/STRINGdb). `%||%`, `stop_for_bad_request`, `stop_for_unauthorized` are already in `auth-service.R` scope.
- Auth token stays in the `Authorization` header (never a query string). `/api/auth/refresh` already does this — keep it.
- Tests run against the test DB in-container. `with_test_db_transaction` exposes the txn connection via `getOption(".test_db_con")`; pass **that connection as the `pool` argument** to `auth_refresh`/`auth_generate_token` so insert + read + refresh share one rolled-back connection. Seed users with **parameterized SQL using real columns** (`email`, not `user_email` — `user_create()` is broken, Codex BLOCKER-3). Build a test config `cfg <- list(secret = get_test_config("secret"), token_expiry = 3600)`.

---

### Task 1: Migration — add `user.session_epoch` and bump ALL manifest assertions

**Files:**
- Create: `db/migrations/043_add_user_session_epoch.sql`
- Modify: `api/functions/migration-manifest.R:5-6`
- Modify: `api/tests/testthat/test-unit-core-views-manifest.R` (`:13,:14,:21`), `api/tests/testthat/test-unit-analysis-snapshot-migration.R` (`:8,:9`)

- [ ] **Step 1: Update ALL four guard assertions to expect 043 / count 41 (write failing expectations first)**

`test-unit-core-views-manifest.R`:
```r
  expect_equal(EXPECTED_LATEST_MIGRATION, "043_add_user_session_epoch.sql")   # :13
  expect_equal(EXPECTED_MIGRATION_COUNT, 41L)                                 # :14
  ...
  expect_identical(res$latest, "043_add_user_session_epoch.sql")              # :21
```
`test-unit-analysis-snapshot-migration.R`:
```r
  expect_equal(EXPECTED_LATEST_MIGRATION, "043_add_user_session_epoch.sql")   # :8
  expect_equal(EXPECTED_MIGRATION_COUNT, 41L)                                 # :9
```

- [ ] **Step 2: Run to verify FAIL**

Run: `docker cp api/tests/testthat/test-unit-core-views-manifest.R sysndd-api-1:/app/tests/testthat/ && docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-unit-core-views-manifest.R')"`
Expected: FAIL (manifest still 042/40).

- [ ] **Step 3: Write the migration**

Create `db/migrations/043_add_user_session_epoch.sql`:
```sql
-- Migration 043: add user.session_epoch for revocable, role-current token refresh (#535 P0-2)
--
-- Every issued JWT carries the user's session_epoch as a `sepoch` claim. auth_refresh() rejects a
-- token whose sepoch != the user's current session_epoch. Privilege/state mutations increment the
-- epoch in the same statement, so demotion/deactivation/password-change/role-change immediately
-- revoke outstanding refresh capability. Additive, idempotent (restore-drift safe).
SET @col_exists := (
  SELECT COUNT(*) FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'user' AND COLUMN_NAME = 'session_epoch'
);
SET @ddl := IF(@col_exists = 0,
  'ALTER TABLE `user` ADD COLUMN `session_epoch` INT NOT NULL DEFAULT 0',
  'SELECT 1');
PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
```
(Default `0`; existing sessions keep working until first bump — see §Compatibility. Do NOT initialize existing users to 1 unless the operator wants a forced logout of all pre-deploy sessions.)

- [ ] **Step 4: Bump the manifest constants**

`api/functions/migration-manifest.R:5-6`:
```r
EXPECTED_LATEST_MIGRATION <- "043_add_user_session_epoch.sql"
EXPECTED_MIGRATION_COUNT <- 41L
```

- [ ] **Step 5: Apply + verify column and guard tests**

```bash
docker compose restart api   # startup runner applies 043
docker exec sysndd-api-1 Rscript -e "library(DBI); con <- DBI::dbConnect(RMariaDB::MariaDB(), group='sysndd_db'); print(DBI::dbGetQuery(con, \"SHOW COLUMNS FROM user LIKE 'session_epoch'\"))"
docker cp api/tests/testthat/test-unit-core-views-manifest.R sysndd-api-1:/app/tests/testthat/ && docker cp api/tests/testthat/test-unit-analysis-snapshot-migration.R sysndd-api-1:/app/tests/testthat/ && docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-unit-core-views-manifest.R'); testthat::test_file('/app/tests/testthat/test-unit-analysis-snapshot-migration.R')"
```
Expected: column present; both guard files PASS.

- [ ] **Step 6: Commit**

```bash
git add db/migrations/043_add_user_session_epoch.sql api/functions/migration-manifest.R api/tests/testthat/test-unit-core-views-manifest.R api/tests/testthat/test-unit-analysis-snapshot-migration.R
git commit -m "feat(db): add user.session_epoch for revocable token refresh (#535 P0-2)"
```

---

### Task 2: Increment `session_epoch` atomically inside every privilege/state mutation

**Files:**
- Modify: `api/functions/user-repository.R` (`user_update()` `:194`, `user_update_password()` `:252`)
- Modify: `api/services/user-service.R` (bulk role UPDATE `~:576`, bulk approval UPDATE `~:400`)
- Test: `api/tests/testthat/test-unit-user-session-epoch.R` (new)

**Interfaces:**
- Produces: every SQL statement that changes `user_role`, `approved`, or `password` also sets `session_epoch = session_epoch + 1` in the **same statement** (atomic; no separate helper). Bulk delete needs no bump (a missing user is rejected by `auth_refresh`). `user_update`/`user_update_password` gain an optional trailing `conn = NULL` forwarded to `db_execute_statement(..., conn = conn)` so tests can drive them on the rolled-back test transaction (backward compatible — existing callers pass args positionally, and `db_execute_statement` already accepts `conn`).

**Connection reality (verified):** `db_execute_statement(sql, params, conn = NULL)` uses the **global app pool** when `conn` is NULL; `with_test_db_transaction`'s connection (`getOption(".test_db_con")`) is NOT consulted. So the tests here pass `conn = con` explicitly; `auth_refresh` (Task 3) already takes `pool` as an argument, so the same `con` is passed there.

- [ ] **Step 1: Write the failing tests (parameterized SQL fixtures — real `email` column)**

Create `api/tests/testthat/test-unit-user-session-epoch.R`:
```r
library(testthat)

.seed_user <- function(con, role = "Viewer", approved = 0L) {
  DBI::dbExecute(con,
    "INSERT INTO user (user_name, email, password, user_role, approved, session_epoch) VALUES (?,?,?,?,?,0)",
    params = list(paste0("epoch_", as.integer(runif(1, 1, 1e8))), paste0("e", as.integer(runif(1,1,1e8)), "@t.local"), "x", role, approved))
  DBI::dbGetQuery(con, "SELECT LAST_INSERT_ID() AS id")$id[1]
}
.epoch <- function(con, uid) DBI::dbGetQuery(con, "SELECT session_epoch FROM user WHERE user_id = ?", params = list(uid))$session_epoch[1]

test_that("user_update on user_role bumps epoch atomically (single statement)", {
  with_test_db_transaction({
    con <- getOption(".test_db_con")
    uid <- .seed_user(con, role = "Reviewer")
    before <- .epoch(con, uid)
    user_update(uid, list(user_role = "Viewer"), conn = con)   # conn = the rolled-back txn
    expect_equal(.epoch(con, uid) - before, 1)
  })
})

test_that("user_update on approved bumps epoch", {
  with_test_db_transaction({
    con <- getOption(".test_db_con")
    uid <- .seed_user(con, approved = 1L)
    before <- .epoch(con, uid)
    user_update(uid, list(approved = 0), conn = con)
    expect_equal(.epoch(con, uid) - before, 1)
  })
})

test_that("user_update on a non-privilege field does NOT bump epoch", {
  with_test_db_transaction({
    con <- getOption(".test_db_con")
    uid <- .seed_user(con)
    before <- .epoch(con, uid)
    user_update(uid, list(abbreviation = "EN"), conn = con)
    expect_equal(.epoch(con, uid), before)
  })
})

test_that("user_update_password bumps epoch", {
  with_test_db_transaction({
    con <- getOption(".test_db_con")
    uid <- .seed_user(con)
    before <- .epoch(con, uid)
    user_update_password(uid, "newhash", conn = con)
    expect_equal(.epoch(con, uid) - before, 1)
  })
})
```
These pass `conn = con` so the seed, mutation, and assertion all run on the single rolled-back transaction connection (Step 3/4 add the `conn` parameter). `db_execute_query`/`db_execute_statement` in `.seed_user`/`.epoch` also accept `conn` — call them as `db_execute_query(sql, params, conn = con)` if you route the fixture through the repo helpers instead of raw `DBI::dbExecute(con, ...)`.

- [ ] **Step 2: Run to verify FAIL**

Run: `docker cp api/tests/testthat/test-unit-user-session-epoch.R sysndd-api-1:/app/tests/testthat/ && docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-unit-user-session-epoch.R')"`
Expected: FAIL — mutations do not yet bump.

- [ ] **Step 3: Add `conn` forwarding + fold the increment into `user_update()`'s SET clause**

In `api/functions/user-repository.R`, change the `user_update` signature to accept an optional connection:
```r
user_update <- function(user_id, updates, conn = NULL) {
```
After `set_clause` is built, before the `sql <- paste0(...)`:
```r
  set_clause <- paste(paste0(field_names, " = ?"), collapse = ", ")
  # #535 P0-2: privilege/state change atomically revokes outstanding sessions.
  if (any(c("user_role", "approved") %in% field_names)) {
    set_clause <- paste0(set_clause, ", session_epoch = session_epoch + 1")
  }
  sql <- paste0("UPDATE user SET ", set_clause, " WHERE user_id = ?")
```
And forward the connection in the final call:
```r
  db_execute_statement(sql, as.list(params), conn = conn)
```
(`session_epoch = session_epoch + 1` is a fixed literal — no new `?` placeholder, `params` unchanged, and not caller-supplied, so it bypasses the field allowlist safely. `conn` defaults `NULL` → the existing global-pool behavior, so no caller changes.)

- [ ] **Step 4: Add `conn` forwarding + fold the increment into `user_update_password()`**

Change the signature to `user_update_password <- function(user_id, password_hash, conn = NULL) {`, the statement to:
```r
  sql <- "UPDATE user SET password = ?, session_epoch = session_epoch + 1 WHERE user_id = ?"
```
and forward: `db_execute_statement(sql, list(password_hash, user_id), conn = conn)` (match the existing param order/shape).

- [ ] **Step 5: Fold the increment into the bulk mutations in `user-service.R`**

- Bulk role change UPDATE (`~:576`): `UPDATE user SET user_role = ?, session_epoch = session_epoch + 1 WHERE user_id = ?` (still inside `db_with_transaction(txn_conn)` — atomic).
- Bulk approval UPDATE (`~:400`): append `, session_epoch = session_epoch + 1` to the existing `UPDATE user SET ...` statement. **Caveat (Codex BLOCKER-2):** that statement writes `account_status`/`approving_user_id`, which the base schema does not have (`approved` is the real column). Run `grep -rn account_status db/migrations/*.sql` first: if a migration added `account_status`, add the epoch clause to that statement as-is; if not, the statement is a **pre-existing bug** independent of S1 — add the epoch clause anyway (harmless), and record a follow-up item "fix bulk-approval account_status→approved schema mismatch". Do NOT expand this P0 PR to rewrite bulk approval.
- Bulk delete: no change (a deleted user's refresh is rejected because the row is gone).

- [ ] **Step 6: Run epoch tests + bulk verification to PASS**

Run: `docker cp api/tests/testthat/test-unit-user-session-epoch.R sysndd-api-1:/app/tests/testthat/ && docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-unit-user-session-epoch.R')"`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add api/functions/user-repository.R api/services/user-service.R api/tests/testthat/test-unit-user-session-epoch.R
git commit -m "feat(auth): atomically bump user.session_epoch on privilege/state mutations (#535 P0-2)"
```

---

### Task 3: Carry `sepoch` in tokens; make `auth_refresh` DB-backed, role-current, epoch-revocable

**Files:**
- Modify: `api/services/auth-service.R` (`auth_generate_token` `:175`, `auth_refresh` `:140`)
- Test: `api/tests/testthat/test-unit-auth-refresh-epoch.R` (new)

**Interfaces:**
- Consumes: `auth_validate_token()`, `auth_generate_token()`, a `pool`/connection and `config` with `$secret`.
- Produces: tokens include `sepoch = user$session_epoch %||% 0`; `auth_refresh(refresh_token, pool, config)` (signature UNCHANGED — the existing `test-unit-auth-service.R:217` signature test stays green) loads the current user, enforces `approved == 1` + `sepoch` match, mints from the DB row.

- [ ] **Step 1: Write failing integration tests (con-as-pool pattern; real fixtures)**

Create `api/tests/testthat/test-unit-auth-refresh-epoch.R`:
```r
library(testthat)

.cfg <- function() list(secret = get_test_config("secret"), token_expiry = 3600L)
.seed <- function(con, role = "Curator", approved = 1L) {
  DBI::dbExecute(con,
    "INSERT INTO user (user_name, email, password, user_role, approved, session_epoch) VALUES (?,?,?,?,?,0)",
    params = list(paste0("ar_", as.integer(runif(1,1,1e8))), paste0("ar", as.integer(runif(1,1,1e8)), "@t.local"), "x", role, approved))
  DBI::dbGetQuery(con, "SELECT LAST_INSERT_ID() AS id")$id[1]
}
.mint <- function(con, uid, cfg) {
  u <- con %>% dplyr::tbl("user") %>% dplyr::filter(.data$user_id == !!uid) %>%
    dplyr::rename(user_created = created_at) %>% dplyr::collect()
  auth_generate_token(u[1, ], cfg)$access_token
}

test_that("token carries sepoch and normal refresh succeeds with DB-derived claims", {
  with_test_db_transaction({
    con <- getOption(".test_db_con"); cfg <- .cfg()
    uid <- .seed(con, role = "Curator")
    tok <- .mint(con, uid, cfg)
    claims0 <- auth_validate_token(tok, cfg); expect_equal(as.numeric(claims0$sepoch), 0)
    newtok <- auth_refresh(tok, con, cfg)
    claims <- auth_validate_token(newtok, cfg)
    expect_equal(claims$user_role, "Curator")
    expect_equal(as.numeric(claims$sepoch), .epoch <- DBI::dbGetQuery(con, "SELECT session_epoch FROM user WHERE user_id=?", params=list(uid))$session_epoch[1])
  })
})

test_that("refresh mints the CURRENT DB role (role-current) — isolate by changing role WITHOUT bumping epoch", {
  with_test_db_transaction({
    con <- getOption(".test_db_con"); cfg <- .cfg()
    uid <- .seed(con, role = "Administrator")
    tok <- .mint(con, uid, cfg)              # token role = Administrator, sepoch = 0
    # raw update: change role but keep epoch 0 so the token still validates
    DBI::dbExecute(con, "UPDATE user SET user_role = 'Viewer' WHERE user_id = ?", params = list(uid))
    newtok <- auth_refresh(tok, con, cfg)
    expect_equal(auth_validate_token(newtok, cfg)$user_role, "Viewer")  # minted from DB, not the token
  })
})

test_that("refresh REJECTED after a real demotion (epoch bump via user_update)", {
  with_test_db_transaction({
    con <- getOption(".test_db_con"); cfg <- .cfg()
    uid <- .seed(con, role = "Curator")
    tok <- .mint(con, uid, cfg)
    user_update(uid, list(user_role = "Viewer"), conn = con)   # bumps epoch atomically
    expect_error(auth_refresh(tok, con, cfg), regexp = "revoked|unauthor", ignore.case = TRUE)
  })
})

test_that("refresh REJECTED for a deactivated user", {
  with_test_db_transaction({
    con <- getOption(".test_db_con"); cfg <- .cfg()
    uid <- .seed(con, role = "Reviewer", approved = 1L)
    tok <- .mint(con, uid, cfg)
    user_update(uid, list(approved = 0), conn = con)
    expect_error(auth_refresh(tok, con, cfg), regexp = "not active|revoked|unauthor", ignore.case = TRUE)
  })
})

test_that("refresh REJECTED after a password change (epoch bump)", {
  with_test_db_transaction({
    con <- getOption(".test_db_con"); cfg <- .cfg()
    uid <- .seed(con); tok <- .mint(con, uid, cfg)
    user_update_password(uid, "newhash", conn = con)
    expect_error(auth_refresh(tok, con, cfg), regexp = "revoked|unauthor", ignore.case = TRUE)
  })
})

test_that("refresh REJECTED for a deleted user", {
  with_test_db_transaction({
    con <- getOption(".test_db_con"); cfg <- .cfg()
    uid <- .seed(con); tok <- .mint(con, uid, cfg)
    DBI::dbExecute(con, "DELETE FROM user WHERE user_id = ?", params = list(uid))
    expect_error(auth_refresh(tok, con, cfg), regexp = "no longer exists|unauthor", ignore.case = TRUE)
  })
})
```
(These pass `conn = con` (Task 2 added the parameter), so the mutation and `auth_refresh`'s DB read share the one rolled-back connection. Equivalent fallback if needed: mutate directly with `DBI::dbExecute(con, "UPDATE user SET user_role='Viewer', session_epoch = session_epoch + 1 WHERE user_id=?", params=list(uid))` — the point of these tests is `auth_refresh`'s reaction to a bumped epoch, not re-testing Task 2.)

- [ ] **Step 2: Run to verify FAIL**

Run: `docker cp api/tests/testthat/test-unit-auth-refresh-epoch.R sysndd-api-1:/app/tests/testthat/ && docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-unit-auth-refresh-epoch.R')"`
Expected: FAIL — no `sepoch` claim; `auth_refresh` doesn't load DB / check epoch.

- [ ] **Step 3: Add the `sepoch` claim to `auth_generate_token`**

In `jose::jwt_claim(...)` (`:179`), add after `orcid = user$orcid,`:
```r
    sepoch = user$session_epoch %||% 0,
```

- [ ] **Step 4: Rewrite `auth_refresh` (DB-backed, role-current, epoch-checked; namespaced dplyr)**

Replace the body of `auth_refresh` (`:140-164`) with:
```r
auth_refresh <- function(refresh_token, pool, config) {
  if (missing(refresh_token) || is.null(refresh_token) || nchar(refresh_token) == 0) {
    stop_for_bad_request("refresh_token is required")
  }

  claims <- auth_validate_token(refresh_token, config)
  if (is.null(claims)) {
    stop_for_unauthorized("Invalid refresh token")
  }
  if (is.null(claims$exp) || claims$exp < as.numeric(Sys.time())) {
    stop_for_unauthorized("Refresh token has expired")
  }

  # Validate the subject id before querying.
  uid <- suppressWarnings(as.integer(claims$user_id))
  if (length(uid) != 1L || is.na(uid) || uid <= 0L) {
    stop_for_unauthorized("Invalid refresh token")
  }

  # Load CURRENT account state — never trust the presented token's claims.
  # Namespace dplyr verbs: the loaded runtime masks them (biomaRt/STRINGdb).
  user <- pool %>%
    dplyr::tbl("user") %>%
    dplyr::filter(.data$user_id == !!uid) %>%
    dplyr::rename(user_created = created_at) %>%
    dplyr::collect()
  if (nrow(user) == 0) {
    stop_for_unauthorized("User no longer exists")
  }
  user <- user[1, ]
  if (is.null(user$approved) || user$approved != 1) {
    stop_for_unauthorized("Account is not active")
  }

  # Revocation gate: token epoch must match the user's current epoch.
  token_epoch <- as.numeric(claims$sepoch %||% 0)
  current_epoch <- as.numeric(user$session_epoch %||% 0)
  if (token_epoch != current_epoch) {
    stop_for_unauthorized("Session has been revoked. Please sign in again.")
  }

  token <- auth_generate_token(user, config)
  logger::log_info("Token refreshed", user_id = user$user_id)
  token$access_token
}
```

- [ ] **Step 5: Run refresh tests to PASS**

Run: `docker compose restart api && docker cp api/tests/testthat/test-unit-auth-refresh-epoch.R sysndd-api-1:/app/tests/testthat/ && docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-unit-auth-refresh-epoch.R')"`
Expected: PASS. Also re-run the existing suite: `docker cp api/tests/testthat/test-unit-auth-service.R sysndd-api-1:/app/tests/testthat/ && docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-unit-auth-service.R')"` — the `sepoch` claim is additive, and the `auth_refresh`/`auth_generate_token` signatures are unchanged, so it stays green (fix any assertion that encoded the old "does not use the DB" behavior).

- [ ] **Step 6: Commit**

```bash
git add api/services/auth-service.R api/tests/testthat/test-unit-auth-refresh-epoch.R
git commit -m "fix(security): make token refresh DB-backed, role-current, epoch-revocable (#535 P0-2)"
```

---

### Task 4: Regression sweep, live verification, docs, gate

- [ ] **Step 1: Ensure no existing test asserts the old stale-claims refresh behavior**

Run: `grep -rnE 'auth_refresh|does not use the DB|reissue|same.*token|refresh' api/tests/testthat/test-unit-auth-service.R api/tests/testthat/test-endpoint-auth.R api/tests/testthat/test-integration-auth.R`
Fix any assertion that requires `auth_refresh` to ignore the pool / reuse old claims. Confirm the `auth_refresh has correct signature` test (`test-unit-auth-service.R:217`) still passes (signature unchanged).

- [ ] **Step 2: File-size + full API gate**

Run: `make code-quality-audit && make test-api-fast`
Expected: PASS; migration 043 applied, all guard + new tests run.

- [ ] **Step 3: Live end-to-end refresh check (fully-loaded env)**

With the dev stack up and a Curator/Admin account:
- Sign in (`POST /api/auth/authenticate`), capture the token; `GET /api/auth/refresh` with `Authorization: Bearer <token>` → **200**, decoded token `user_role` matches the DB, `sepoch` matches the user's epoch.
- Admin demote that user (`PUT /api/user/change_role`), retry refresh with the OLD token → **401** ("Session has been revoked").
- Deactivate (`PUT /api/user/approval` unapprove), retry → **401**.

- [ ] **Step 4: Docs**

In `documentation/09-deployment.qmd` (and `08-development.qmd` if it documents auth): refresh now loads current account state and enforces `session_epoch`; demotion/deactivation/password-change/role-change immediately revoke refresh (force re-login). Document the residuals: (a) the current **access** token remains valid until `config$token_expiry` (3600s) — immediate access revocation (epoch check in `require_auth`) is deferred; (b) a **legacy pre-deploy token** (no `sepoch`, epoch 0) is refreshable until its own expiry unless the operator initializes existing users to epoch 1 at deploy; (c) distinct rotating refresh tokens (theft resistance) are the deferred **S1b** follow-up.

## Self-Review

- **Spec coverage (S1 §5):** epoch column + full manifest bump (Task 1, Codex MEDIUM-9), atomic in-statement epoch increment on role/approved/password + bulk (Task 2, Codex BLOCKER-2/HIGH-4), DB-backed role-current epoch-checked refresh with namespaced dplyr + id validation (Task 3, Codex MEDIUM-8), tests for normal/role-current-isolated/demotion/deactivation/password/deleted-user (Task 3, Codex HIGH-7) with working fixtures (Codex BLOCKER-3), residuals documented (Task 4, Codex LOW-11).
- **Design choice documented:** privilege change → reject refresh (force re-login); mint-from-DB is defense-in-depth; role-current isolated by a raw non-epoch-bumping DB update.
- **Placeholder scan:** none — migration, mutation edits, and `auth_refresh` body are complete. The two adaptive points (db_execute_statement connection source; bulk-approval `account_status`) have explicit grep-and-decide instructions.
- **Type/name consistency:** `session_epoch` / `sepoch` used identically across migration, mutations, `auth_generate_token`, `auth_refresh`, and tests. `auth_refresh(refresh_token, pool, config)` signature unchanged (keeps `test-unit-auth-service.R:217` green).
