# S1 — Session-Epoch Role-Current, Revocable Refresh (#535 P0-2) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make JWT refresh reflect current account state — a demoted/deactivated user (or any user whose session epoch was bumped) cannot refresh stale privileges, and a refreshed token carries the role loaded from the database.

**Architecture:** Add a `session_epoch` integer to the `user` table. Tokens carry the epoch as a `sepoch` claim. `auth_refresh()` stops trusting the presented token: it loads the current user by id from the DB pool, requires `approved == 1`, requires the token's `sepoch` to equal the user's current `session_epoch`, and mints the new token with role + fields taken from the DB row. Any admin action that changes privilege or account state (`user_role`/`approved` via `user_update`, password via `user_update_password`, plus bulk paths and delete) increments `session_epoch`, immediately invalidating outstanding refresh capability. Backend + one additive migration only — no frontend change (the SPA keeps its single-token model; `/api/auth/refresh` still takes the token from the `Authorization` header and returns a bare token string).

**Tech Stack:** R / Plumber, MySQL, testthat. `jose` JWT. `dplyr`/`dbplyr` DB access. Migration runner applies `db/migrations/*.sql` at startup with a manifest guard.

## Global Constraints

- Keep every touched file **< 600 lines** (`make code-quality-audit`). `auth-service.R` (224 lines) and `user-repository.R` have headroom.
- Additive migration only; **no** change to existing tables/columns. Idempotent DDL (restore-drift safe, matching migrations 039/042).
- After the migration, bump BOTH `EXPECTED_LATEST_MIGRATION` and `EXPECTED_MIGRATION_COUNT` in `api/functions/migration-manifest.R:5-6` and the two guard tests that assert the latest migration name (`test-unit-analysis-snapshot-migration.R:8`, `test-unit-core-views-manifest.R:13`). A stale manifest is a **fatal startup error** by design — do not weaken it.
- Worker parity: no worker-executed code changes here, but `auth-service.R` is sourced by the API at startup — an API restart picks it up (bind-mounted).
- Auth secrets stay out of query strings (CLAUDE.md). `/api/auth/refresh` already reads the token from the `Authorization` header — keep it there; do **not** move the token to a query param.
- Tests that load a user run against the test DB in-container: `docker cp` the test file into `sysndd-api-1:/app/tests/testthat/` then `docker exec sysndd-api-1 Rscript -e "testthat::test_file(...)"`, or `make test-api-fast`. `with_test_db_transaction()` auto-rolls-back and `skip_if_no_test_db()` skips on DB-less hosts.

---

### Task 1: Migration — add `user.session_epoch` and bump the manifest

**Files:**
- Create: `db/migrations/043_add_user_session_epoch.sql`
- Modify: `api/functions/migration-manifest.R:5-6`
- Modify: `api/tests/testthat/test-unit-analysis-snapshot-migration.R:8`, `api/tests/testthat/test-unit-core-views-manifest.R:13`

**Interfaces:**
- Produces: a `session_epoch INT NOT NULL DEFAULT 0` column on `user`, and a manifest whose latest migration is `043_add_user_session_epoch.sql` (count 41).

- [ ] **Step 1: Update the manifest guard tests to expect 043 (write the failing expectation first)**

In `api/tests/testthat/test-unit-analysis-snapshot-migration.R:8` and
`api/tests/testthat/test-unit-core-views-manifest.R:13`, change the expected string:

```r
expect_equal(EXPECTED_LATEST_MIGRATION, "043_add_user_session_epoch.sql")
```

- [ ] **Step 2: Run one guard test to verify it FAILS**

Run: `docker cp api/tests/testthat/test-unit-core-views-manifest.R sysndd-api-1:/app/tests/testthat/ && docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-unit-core-views-manifest.R')"`
Expected: FAIL — manifest still says `042_...`.

- [ ] **Step 3: Write the migration**

Create `db/migrations/043_add_user_session_epoch.sql`:

```sql
-- Migration 043: add user.session_epoch for revocable, role-current token refresh (#535 P0-2)
--
-- Every issued JWT carries the user's session_epoch as a `sepoch` claim. auth_refresh()
-- rejects a token whose sepoch != the user's current session_epoch, so bumping the epoch
-- (on demotion, deactivation, admin edit, password change, delete) immediately revokes
-- outstanding refresh capability. Additive, idempotent (restore-drift safe).

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

- [ ] **Step 4: Bump the manifest constants**

`api/functions/migration-manifest.R:5-6`:

```r
EXPECTED_LATEST_MIGRATION <- "043_add_user_session_epoch.sql"
EXPECTED_MIGRATION_COUNT <- 41L
```

- [ ] **Step 5: Apply the migration and verify the column + guard tests pass**

Run: `docker exec sysndd-api-1 Rscript -e "source('/app/start_sysndd_api.R')"` is heavy; instead restart the API container so the startup runner applies 043, then verify:
```bash
docker compose restart api
docker exec sysndd-api-1 Rscript -e "library(DBI); con <- DBI::dbConnect(RMariaDB::MariaDB(), group='sysndd_db'); print(DBI::dbGetQuery(con, \"SHOW COLUMNS FROM user LIKE 'session_epoch'\"))"
docker cp api/tests/testthat/test-unit-core-views-manifest.R sysndd-api-1:/app/tests/testthat/ && docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-unit-core-views-manifest.R')"
```
Expected: the column exists; the manifest guard test PASSES. (If the container's DB group differs, use the repo's documented connect recipe.)

- [ ] **Step 6: Commit**

```bash
git add db/migrations/043_add_user_session_epoch.sql api/functions/migration-manifest.R api/tests/testthat/test-unit-analysis-snapshot-migration.R api/tests/testthat/test-unit-core-views-manifest.R
git commit -m "feat(db): add user.session_epoch for revocable token refresh (#535 P0-2)"
```

---

### Task 2: Repository — `user_bump_session_epoch()` and wire it into privilege mutations

**Files:**
- Modify: `api/functions/user-repository.R` (add helper; call inside `user_update()` and `user_update_password()`)
- Modify: `api/services/user-bulk-endpoint-service.R` (bulk role/approve/delete paths that bypass `user_update`)
- Test: `api/tests/testthat/test-unit-user-session-epoch.R` (new)

**Interfaces:**
- Produces: `user_bump_session_epoch(user_id)` → integer affected rows; increments `session_epoch` by 1 for one user. Called automatically by `user_update()` when the update touches `user_role` or `approved`, and by `user_update_password()`.

- [ ] **Step 1: Write the failing test for the helper and the auto-bump**

Create `api/tests/testthat/test-unit-user-session-epoch.R`:

```r
library(testthat)

test_that("user_bump_session_epoch increments the user's epoch by 1", {
  with_test_db_transaction({
    # insert a throwaway user; user_create signature per user-repository.R
    uid <- user_create(list(user_name = "epoch_tester", user_email = "epoch@test.local",
                            user_password_hash = "x", user_role = "Viewer"))
    before <- pool %>% tbl("user") %>% filter(user_id == !!uid) %>% collect()
    user_bump_session_epoch(uid)
    after <- pool %>% tbl("user") %>% filter(user_id == !!uid) %>% collect()
    expect_equal(as.numeric(after$session_epoch[1]) - as.numeric(before$session_epoch[1]), 1)
  })
})

test_that("user_update on user_role auto-bumps the epoch", {
  with_test_db_transaction({
    uid <- user_create(list(user_name = "epoch_role", user_email = "role@test.local",
                            user_password_hash = "x", user_role = "Reviewer"))
    before <- pool %>% tbl("user") %>% filter(user_id == !!uid) %>% collect()
    user_update(uid, list(user_role = "Viewer"))
    after <- pool %>% tbl("user") %>% filter(user_id == !!uid) %>% collect()
    expect_gt(as.numeric(after$session_epoch[1]), as.numeric(before$session_epoch[1]))
  })
})

test_that("user_update on a non-privilege field does NOT bump the epoch", {
  with_test_db_transaction({
    uid <- user_create(list(user_name = "epoch_name", user_email = "name@test.local",
                            user_password_hash = "x", user_role = "Viewer"))
    before <- pool %>% tbl("user") %>% filter(user_id == !!uid) %>% collect()
    user_update(uid, list(abbreviation = "EN"))
    after <- pool %>% tbl("user") %>% filter(user_id == !!uid) %>% collect()
    expect_equal(as.numeric(after$session_epoch[1]), as.numeric(before$session_epoch[1]))
  })
})
```

Note: if `user_create`'s exact field names differ, grep `api/functions/user-repository.R` for the `user_create` signature (Task 2 reads it) and match it — do not invent fields.

- [ ] **Step 2: Run to verify FAIL**

Run: `docker cp api/tests/testthat/test-unit-user-session-epoch.R sysndd-api-1:/app/tests/testthat/ && docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-unit-user-session-epoch.R')"`
Expected: FAIL — `user_bump_session_epoch` undefined; `user_update` does not bump.

- [ ] **Step 3: Add the helper to `user-repository.R`**

Add near `user_update` in `api/functions/user-repository.R`:

```r
#' Increment a user's session epoch (revokes outstanding refresh capability).
#'
#' Every issued JWT carries the user's session_epoch as a `sepoch` claim; a
#' refresh whose sepoch != the current epoch is rejected (see auth_refresh).
#' Call this whenever a privilege- or account-state change must invalidate a
#' user's outstanding sessions.
#'
#' @param user_id Integer user ID.
#' @return Integer affected-row count.
user_bump_session_epoch <- function(user_id) {
  db_execute_statement(
    "UPDATE user SET session_epoch = session_epoch + 1 WHERE user_id = ?",
    list(user_id)
  )
}
```

- [ ] **Step 4: Auto-bump inside `user_update()` and `user_update_password()`**

In `user_update()`, immediately before the final `db_execute_statement(sql, as.list(params))` return,
capture the result and bump when a privilege/state field changed:

```r
  affected <- db_execute_statement(sql, as.list(params))
  if (any(c("user_role", "approved") %in% field_names)) {
    user_bump_session_epoch(user_id)
  }
  affected
}
```

In `user_update_password()`, after its `UPDATE user SET password = ...` executes, add:

```r
  user_bump_session_epoch(user_id)
```
(place it after the password `db_execute_statement(...)` call, before returning its result).

- [ ] **Step 5: Cover bulk paths that bypass `user_update`**

Run: `grep -nE 'user_bulk_assign_role|user_bulk_approve|UPDATE .*user|user_update\(|user_delete' api/services/user-bulk-endpoint-service.R api/functions/user-repository.R`
For any bulk role-change / approve / delete path that issues its own `UPDATE user`/delete **without**
going through `user_update`, add a `user_bump_session_epoch(<uid>)` for each affected user id
(vectorize with `lapply(user_ids, user_bump_session_epoch)`). If bulk paths route through
`user_update`, no extra call is needed (the auto-bump covers them) — document which case held in the
commit message.

- [ ] **Step 6: Run the epoch tests to verify PASS**

Run: `docker cp api/tests/testthat/test-unit-user-session-epoch.R sysndd-api-1:/app/tests/testthat/ && docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-unit-user-session-epoch.R')"`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add api/functions/user-repository.R api/services/user-bulk-endpoint-service.R api/tests/testthat/test-unit-user-session-epoch.R
git commit -m "feat(auth): bump user.session_epoch on privilege/state changes (#535 P0-2)"
```

---

### Task 3: Auth service — carry `sepoch` in tokens and make `auth_refresh` DB-backed and role-current

**Files:**
- Modify: `api/services/auth-service.R` (`auth_generate_token` `:175-199`, `auth_refresh` `:140-164`)
- Test: `api/tests/testthat/test-unit-auth-refresh-epoch.R` (new)

**Interfaces:**
- Consumes: `user_bump_session_epoch()` (Task 2), `auth_validate_token()`, `auth_generate_token()`, `pool`, `dw` (config).
- Produces: `auth_generate_token(user, config)` tokens include `sepoch = user$session_epoch %||% 0`; `auth_refresh(refresh_token, pool, config)` loads the current user, enforces `approved == 1` and `sepoch` match, and mints role/fields from the DB row.

- [ ] **Step 1: Write the failing integration tests**

Create `api/tests/testthat/test-unit-auth-refresh-epoch.R`:

```r
library(testthat)

# Uses the fully-loaded API env (auth-service.R sourced). Runs against the test DB.
test_that("auth_refresh rejects a token whose sepoch is stale (revoked session)", {
  with_test_db_transaction({
    uid <- user_create(list(user_name = "refresh_epoch", user_email = "re@test.local",
                            user_password_hash = "x", user_role = "Curator"))
    user_update(uid, list(approved = 1))  # bumps epoch to >=1
    user <- pool %>% tbl("user") %>% filter(user_id == !!uid) %>%
      dplyr::rename(user_created = created_at) %>% collect()
    user <- user[1, ]
    token <- auth_generate_token(user, dw)$access_token
    # Simulate a privilege change AFTER the token was minted:
    user_bump_session_epoch(uid)
    expect_error(auth_refresh(token, pool, dw), regexp = "revoked|not active|Invalid|unauthor",
                 ignore.case = TRUE)
  })
})

test_that("auth_refresh rejects a deactivated user", {
  with_test_db_transaction({
    uid <- user_create(list(user_name = "refresh_deact", user_email = "de@test.local",
                            user_password_hash = "x", user_role = "Reviewer"))
    user_update(uid, list(approved = 1))
    user <- pool %>% tbl("user") %>% filter(user_id == !!uid) %>%
      dplyr::rename(user_created = created_at) %>% collect()
    token <- auth_generate_token(user[1, ], dw)$access_token
    user_update(uid, list(approved = 0))  # deactivate (also bumps epoch)
    expect_error(auth_refresh(token, pool, dw), regexp = "not active|revoked|unauthor",
                 ignore.case = TRUE)
  })
})

test_that("auth_refresh mints the CURRENT role from the DB (role-current)", {
  with_test_db_transaction({
    uid <- user_create(list(user_name = "refresh_role", user_email = "rr@test.local",
                            user_password_hash = "x", user_role = "Administrator"))
    user_update(uid, list(approved = 1))
    user <- pool %>% tbl("user") %>% filter(user_id == !!uid) %>%
      dplyr::rename(user_created = created_at) %>% collect()
    token <- auth_generate_token(user[1, ], dw)$access_token
    new_token <- auth_refresh(token, pool, dw)
    claims <- auth_validate_token(new_token, dw)
    expect_equal(claims$user_role, "Administrator")
    expect_equal(as.numeric(claims$sepoch),
                 as.numeric((pool %>% tbl("user") %>% filter(user_id == !!uid) %>% collect())$session_epoch[1]))
  })
})
```

- [ ] **Step 2: Run to verify FAIL**

Run: `docker cp api/tests/testthat/test-unit-auth-refresh-epoch.R sysndd-api-1:/app/tests/testthat/ && docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-unit-auth-refresh-epoch.R')"`
Expected: FAIL — `sepoch` not in claims; `auth_refresh` does not load the DB / check epoch.

- [ ] **Step 3: Add the `sepoch` claim to `auth_generate_token`**

In `api/services/auth-service.R`, inside `jose::jwt_claim(...)` (`:179`), add:

```r
    orcid = user$orcid,
    sepoch = user$session_epoch %||% 0,
    iat = as.numeric(Sys.time()),
```

- [ ] **Step 4: Rewrite `auth_refresh` to be DB-backed, role-current, and epoch-checked**

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

  # Load CURRENT account state — never trust the presented token's claims.
  uid <- as.integer(claims$user_id)
  user <- pool %>%
    tbl("user") %>%
    filter(user_id == !!uid) %>%
    dplyr::rename(user_created = created_at) %>%
    collect()
  if (nrow(user) == 0) {
    stop_for_unauthorized("User no longer exists")
  }
  user <- user[1, ]
  if (is.null(user$approved) || user$approved != 1) {
    stop_for_unauthorized("Account is not active")
  }

  # Revocation gate: the token's epoch must match the user's current epoch.
  token_epoch <- as.numeric(claims$sepoch %||% 0)
  current_epoch <- as.numeric(user$session_epoch %||% 0)
  if (token_epoch != current_epoch) {
    stop_for_unauthorized("Session has been revoked. Please sign in again.")
  }

  # Mint a fresh token with role + claim fields taken from the DB row.
  token <- auth_generate_token(user, config)
  logger::log_info("Token refreshed", user_id = user$user_id)
  token$access_token
}
```

Verify `stop_for_bad_request`/`stop_for_unauthorized` and `%||%` are already used in this file (they are — `auth_signin` uses them). Keep `filter`/`tbl`/`collect` unqualified to match `auth_signin`'s style in the same file.

- [ ] **Step 5: Run the refresh tests to verify PASS**

Run: `docker compose restart api && docker cp api/tests/testthat/test-unit-auth-refresh-epoch.R sysndd-api-1:/app/tests/testthat/ && docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-unit-auth-refresh-epoch.R')"`
Expected: PASS. (Restart so the API sources the new `auth-service.R`.)

- [ ] **Step 6: Commit**

```bash
git add api/services/auth-service.R api/tests/testthat/test-unit-auth-refresh-epoch.R
git commit -m "fix(security): make token refresh DB-backed, role-current, epoch-revocable (#535 P0-2)"
```

---

### Task 4: Regression sweep, live verification, and gate

**Files:** none (verification); update docs if refresh semantics are documented.

- [ ] **Step 1: Ensure no existing auth test asserts the OLD stale-claims behavior**

Run: `grep -rnE 'auth_refresh|does not use the DB|refresh' api/tests/testthat/test-endpoint-auth.R api/tests/testthat/*auth* 2>/dev/null`
If any test asserts that `auth_refresh` ignores the pool / reissues old claims, update it to the new contract (a comment in the old code said it "explicitly does not use the DB pool"; any test encoding that must be inverted).

- [ ] **Step 2: File-size + full API gate**

Run: `make code-quality-audit && make test-api-fast`
Expected: PASS; the three new test files run (not skipped) against the dev DB, migration 043 applied, manifest guard green.

- [ ] **Step 3: Live end-to-end refresh check (fully-loaded env)**

With the dev stack up and a Curator/Admin account:
- Sign in (`POST /api/auth/authenticate`), capture the token.
- `GET /api/auth/refresh` with `Authorization: Bearer <token>` → **200**, a new token whose decoded `user_role` matches the DB and `sepoch` matches the user's current epoch.
- As an admin, demote that user (`PUT /api/user/change_role`), then retry refresh with the OLD token → **401** ("Session has been revoked").
- Deactivate a user (`PUT /api/user/approval` unapprove), retry refresh → **401**.

- [ ] **Step 4: Docs**

If `documentation/08-development.qmd` or `09-deployment.qmd` documents the refresh flow or token lifetime, note: refresh now loads current account state and enforces `session_epoch`; demotion/deactivation/password-change immediately revoke refresh. Note the residual (§S1 residual risk): the current access token remains valid until `config$token_expiry` (3600s); immediate access-token revocation (epoch check in `require_auth`) and distinct rotating tokens are the deferred S1b follow-up.

## Self-Review

- **Spec coverage (S1 §5):** epoch column (Task 1), tokens carry epoch (Task 3.3), refresh loads current user + role + approved + epoch (Task 3.4), revoke-on-change via bump (Task 2), no frontend change (verified — header-carried token, bare-string response), tests for demotion/deactivation/role-current/normal (Task 3) + bump coverage (Task 2). Residual documented (Task 4.4).
- **Placeholder scan:** none — migration, helper, and auth_refresh bodies are complete. The two adaptive steps (2.1 `user_create` fields, 2.5 bulk paths) include explicit grep-and-match instructions, not vague TODOs.
- **Type/name consistency:** `user_bump_session_epoch(user_id)` used identically in repository + tests; `sepoch` claim name consistent across `auth_generate_token`/`auth_refresh`/tests; `session_epoch` column name consistent across migration/repository/auth-service.
- **Compat:** legacy tokens (no `sepoch`) → `%||% 0`; refresh works while user epoch is 0, correctly rejects once epoch > 0. Additive migration; manifest bumped with guard tests.
