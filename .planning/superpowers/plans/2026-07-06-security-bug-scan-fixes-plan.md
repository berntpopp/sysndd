# Security & Bug-Scan Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the three HIGH (hash-endpoint RCE, re-review SQLi, public unapproved-curation exposure), four MEDIUM, and eight LOW defects from the `sysndd-security-bug-scan` review, each by reusing an existing in-repo helper.

**Architecture:** Two PRs. PR 1 (`security/hotfix-rce-sqli-exposure`, current branch) lands the three HIGH fixes fast. PR 2 (`security/hardening-medium-low`, branched from `master` after PR 1 merges) lands MEDIUM + LOW. Every fix is one atomic commit with a guard test; Codex high-effort adversarial review gates each PR.

**Tech Stack:** R 4.x, Plumber, dplyr/dbplyr, DBI/RMariaDB, rlang, httr2, jsonlite, testthat. Design doc: `.planning/superpowers/specs/2026-07-06-security-bug-scan-fixes-design.md`.

## Global Constraints

- **Reuse in-repo helpers; never hand-roll.** Validation → `validate_query_column()` / column allowlists. Errors → classed `stop_for_bad_request()` / `stop_for_unauthorized()` / `stop_for_internal()` (from `core/errors.R`), never bare `stop()` or `return(list(error=e$message))`. External calls → `external_proxy_budget()` / `external_proxy_with_timing()` / `memoise_external_success_only()`. URL segments → `utils::URLencode(x, reserved = TRUE)`.
- **Namespace masked verbs explicitly:** `dplyr::select` / `dplyr::filter`; `base::get` (never bare `get(..., mode=)` — `config::get` masks it).
- **Tests are NOT bind-mounted** (`api/tests/`). Run new tests on the host where they don't need the live DB (static/unit guards), or `docker cp` into `sysndd-api-1` and `docker exec … Rscript -e "testthat::test_file('/app/tests/testthat/<file>')"`.
- **Static guard tests are idiomatic here** (see `test-unit-external-budget-guard.R`, `test-unit-cheap-route-isolation.R`) — prefer a static/source-scan guard when a behavioral test would need a live DB.
- **Per-PR gate:** `make lint-api` + `make test-api-fast` + the touched guard files; `make test-api` before merge.
- **Worker restart rule:** worker-executed code (`functions/mondo-functions.R`, `functions/metadata-refresh.R`) is sourced at worker start — restart `worker` / `worker-maintenance` after those changes. API-path fixes (endpoints/repositories/core) are live on API container restart via bind mount.
- **No new DB migration.** Allowlists derive from the existing schema.
- **Commit trailer:** end each commit message with `Claude-Session: https://claude.ai/code/session_01Nxo1e69TNWFWXxroYEuWNX`.

---

## File Structure

**PR 1 (HIGH):**
- `api/functions/data-helpers.R` — reorder validation + drop eval sort (#1).
- `api/endpoints/hash_endpoints.R` — unchanged (handler already delegates).
- `api/services/re-review-service.R` — new `re_review_submit_allowed_fields()` + `re_review_filter_submit_fields()` helpers (#2).
- `api/endpoints/re_review_endpoints.R` — call the allowlist helper (#2).
- `api/functions/review-repository.R` — new `primary_approved_reviews()` helper (#3).
- `api/endpoints/entity_endpoints.R` — 5 sites consume the helper + `status_approved` (#3).
- `api/tests/testthat/test-unit-hash-endpoint-injection.R` — new (#1).
- `api/tests/testthat/test-unit-re-review-submit-allowlist.R` — new (#2).
- `api/tests/testthat/test-unit-public-approved-review-guard.R` — new static guard (#3).

**PR 2 (MEDIUM + LOW):**
- `api/functions/user-repository.R` (#4), `api/services/user-service.R` + `api/endpoints/user_endpoints.R` (#5), `api/functions/job-manager.R` (LOW-1).
- `api/endpoints/publication_endpoints.R` + `api/functions/publication-endpoint-helpers.R` (#6).
- `api/functions/llm-endpoint-helpers.R` (#7).
- `api/endpoints/about_endpoints.R`, `logging_endpoints.R`, `publication_endpoints.R`, `user_endpoints.R` (LOW-2 classed errors).
- `api/core/logging_sanitizer.R` (LOW-3), `api/core/security.R` (LOW-4), `api/functions/hgnc-functions.R` + `oxo-functions.R` (LOW-5), `api/functions/mondo-functions.R` (LOW-6), `api/functions/metadata-refresh.R` (LOW-7).
- Matching `test-unit-*` guards per fix.

---

# PR 1 — HIGH fixes (branch `security/hotfix-rce-sqli-exposure`)

## Task 1: #1 — Close the hash-endpoint RCE (validate-first + drop eval)

**Files:**
- Modify: `api/functions/data-helpers.R` (`post_db_hash`, lines ~205–256)
- Test: `api/tests/testthat/test-unit-hash-endpoint-injection.R` (create)

**Interfaces:**
- Consumes: `hash_validate_columns(cols, allowed)` (existing, `functions/hash-repository.R`), `stop_for_bad_request()` (existing).
- Produces: no signature change to `post_db_hash(json_data, allowed_columns, endpoint)`.

- [ ] **Step 1: Write the failing test**

`api/tests/testthat/test-unit-hash-endpoint-injection.R`:

```r
# Guard: the hash-create path must validate column tokens BEFORE any
# expression evaluation, and must never parse a column name as R code (#1 RCE).
test_that("post_db_hash rejects a non-allowlisted column before any evaluation", {
  src <- readLines("../../functions/data-helpers.R", warn = FALSE)
  body <- paste(src, collapse = "\n")

  # (a) No parse_exprs over a column name inside post_db_hash's arrange.
  expect_false(
    grepl("arrange\\(!!!rlang::parse_exprs\\(", body),
    info = "post_db_hash must not parse a column name as an R expression"
  )

  # (b) hash_validate_columns must appear BEFORE the first arrange() call.
  first_validate <- regexpr("hash_validate_columns\\(colnames", body)
  first_arrange  <- regexpr("arrange\\(", body)
  expect_true(first_validate > 0 && first_arrange > 0)
  expect_lt(first_validate, first_arrange)
})

test_that("post_db_hash raises a bad-request error on an unexpected column and runs no shell", {
  skip_if_not(exists("post_db_hash"), "API not sourced")
  sentinel <- tempfile()
  malicious <- stats::setNames(list(1L), paste0("system('touch ", sentinel, "')"))
  expect_error(
    post_db_hash(malicious, "symbol,hgnc_id,entity_id", "/api/gene")
  )
  expect_false(file.exists(sentinel),
               info = "injected command must NOT have executed")
})
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-hash-endpoint-injection.R')"`
Expected: FAIL — the `parse_exprs` grep matches (current code) and validation is after `arrange`.

- [ ] **Step 3: Apply the fix**

In `api/functions/data-helpers.R`, replace the block (currently lines ~220–253):

```r
  json_tibble <- as_tibble(json_data)
  json_tibble <- json_tibble %>%
    arrange(!!!rlang::parse_exprs((json_tibble %>% colnames())[1]))

  json_sort <- toJSON(json_tibble)
```
…and (further down) `hash_validate_columns(colnames(json_tibble), allowed_col_list)` at line ~253

with:

```r
  json_tibble <- as_tibble(json_data)

  # SECURITY (#1): validate column tokens against the allowlist BEFORE any
  # evaluation, and sort by a column REFERENCE (never parse the name as code).
  # The old arrange(!!!parse_exprs(colnames[1])) evaluated the first JSON key
  # as an R expression via dplyr data-masking -> authenticated RCE.
  hash_validate_columns(colnames(json_tibble), allowed_col_list)

  json_tibble <- json_tibble %>%
    dplyr::arrange(dplyr::across(dplyr::all_of(colnames(json_tibble)[1])))

  json_sort <- toJSON(json_tibble)
```

Then delete the now-redundant later `hash_validate_columns(colnames(json_tibble), allowed_col_list)` call (line ~253) so validation happens exactly once, up front (it must precede the no-DB early-return at ~238–250 too).

- [ ] **Step 4: Run to verify it passes**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-hash-endpoint-injection.R')"`
Expected: PASS (static guard passes; behavioral test needs the API sourced — it skips on host, runs in-container).

- [ ] **Step 5: Verify in-container behavioral path**

Run: `docker cp api/tests/testthat/test-unit-hash-endpoint-injection.R sysndd-api-1:/app/tests/testthat/ && docker restart sysndd-api-1 && sleep 8 && docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-unit-hash-endpoint-injection.R')"`
Expected: PASS, no sentinel file.

- [ ] **Step 6: Commit**

```bash
git add api/functions/data-helpers.R api/tests/testthat/test-unit-hash-endpoint-injection.R
git commit -m "fix(security): close authenticated RCE in hash-create endpoint (#1)

Validate column tokens before evaluation and sort by column reference
(across(all_of(...))) instead of parse_exprs(colname), which evaluated the
first JSON key as R code via dplyr data-masking.

Claude-Session: https://claude.ai/code/session_01Nxo1e69TNWFWXxroYEuWNX"
```

## Task 2: #2 — Allowlist the re-review submit SET clause (SQLi + self-approval)

**Files:**
- Modify: `api/services/re-review-service.R` (add helpers)
- Modify: `api/endpoints/re_review_endpoints.R:29–45`
- Test: `api/tests/testthat/test-unit-re-review-submit-allowlist.R` (create)

**Interfaces:**
- Produces: `re_review_submit_allowed_fields()` → character vector of writable columns; `re_review_filter_submit_fields(field_names)` → validated character vector or `stop_for_bad_request` on any out-of-allowlist / non-identifier token.

- [ ] **Step 1: Confirm the legitimate field set**

Run: `grep -rn "submit_json\|re_review_review_saved\|re_review_status_saved\|re_review_submitted" app/src api/services/re-review-service.R`
Expected: identify exactly which columns the frontend submit sends. The allowlist is the intersection with the table's non-identity, non-approval columns: `re_review_review_saved`, `re_review_status_saved`, `re_review_submitted`, `status_id`, `review_id`, `re_review_batch`. It MUST exclude `re_review_entity_id` (PK/WHERE key), `entity_id`, `re_review_approved`, `approving_user_id` (approval is a Curator-only action — excluding them closes the self-approval mass-assignment). Adjust the vector below to the confirmed frontend set.

- [ ] **Step 2: Write the failing test**

`api/tests/testthat/test-unit-re-review-submit-allowlist.R`:

```r
test_that("re_review_submit_allowed_fields excludes identity + approval columns", {
  skip_if_not(exists("re_review_submit_allowed_fields"))
  allowed <- re_review_submit_allowed_fields()
  expect_false("re_review_entity_id" %in% allowed)
  expect_false("re_review_approved"  %in% allowed)
  expect_false("approving_user_id"   %in% allowed)
  expect_true("re_review_submitted"  %in% allowed)
})

test_that("re_review_filter_submit_fields rejects injection + out-of-allowlist keys", {
  skip_if_not(exists("re_review_filter_submit_fields"))
  expect_error(
    re_review_filter_submit_fields("re_review_submitted = SLEEP(5), x")
  )
  expect_error(re_review_filter_submit_fields("re_review_approved"))
  expect_equal(
    re_review_filter_submit_fields(c("re_review_submitted", "re_review_review_saved")),
    c("re_review_submitted", "re_review_review_saved")
  )
})
```

- [ ] **Step 3: Run to verify it fails**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-re-review-submit-allowlist.R')"`
Expected: FAIL — helpers not defined.

- [ ] **Step 4: Add the helpers to `api/services/re-review-service.R`**

```r
#' Columns the re-review submit endpoint is permitted to write.
#' Excludes identity (PK/FK) and approval columns so a Reviewer cannot inject
#' SQL identifiers or self-approve via mass assignment (#2).
re_review_submit_allowed_fields <- function() {
  c("re_review_review_saved", "re_review_status_saved",
    "re_review_submitted", "re_review_batch", "status_id", "review_id")
}

#' Validate + filter submitted field names to the allowlist. Fails loud.
re_review_filter_submit_fields <- function(field_names) {
  allowed <- re_review_submit_allowed_fields()
  for (f in field_names) {
    validate_query_column(f, allowed) # bare-identifier + allowlist; 400 on fail
  }
  field_names
}
```

- [ ] **Step 5: Wire the endpoint** — `api/endpoints/re_review_endpoints.R`, replace lines 36–38:

```r
  fields_to_update <- names(submit_data)[names(submit_data) != "re_review_entity_id"]
  fields_to_update <- re_review_filter_submit_fields(fields_to_update)   # SECURITY #2
  set_clause <- paste(paste0(fields_to_update, " = ?"), collapse = ", ")
  sql <- paste0("UPDATE re_review_entity_connect SET ", set_clause, " WHERE re_review_entity_id = ?")
```

- [ ] **Step 6: Run to verify it passes**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-re-review-submit-allowlist.R')"`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add api/services/re-review-service.R api/endpoints/re_review_endpoints.R api/tests/testthat/test-unit-re-review-submit-allowlist.R
git commit -m "fix(security): allowlist re-review submit fields (SQLi + self-approval) (#2)

Interpolated JSON keys as SQL identifiers allowed identifier injection and
mass-assignment of re_review_approved/approving_user_id. Restrict to writable
columns via validate_query_column; reject others with 400.

Claude-Session: https://claude.ai/code/session_01Nxo1e69TNWFWXxroYEuWNX"
```

## Task 3: #3 — Public reads must be approved-only (shared helper)

**Files:**
- Modify: `api/functions/review-repository.R` (add `primary_approved_reviews`)
- Modify: `api/endpoints/entity_endpoints.R` (5 review sites + `/status`)
- Test: `api/tests/testthat/test-unit-public-approved-review-guard.R` (create)

**Interfaces:**
- Produces: `primary_approved_reviews(pool, cols = NULL)` → a lazy dbplyr tbl over `ndd_entity_review` filtered `is_primary == 1 & review_approved == 1`, optionally `dplyr::select(all_of(cols))`.

- [ ] **Step 1: Write the failing static guard**

`api/tests/testthat/test-unit-public-approved-review-guard.R`:

```r
# Guard (#3): every public review-derived read must gate on review_approved,
# not is_primary alone. Enforced by a source scan of entity_endpoints.R.
test_that("entity_endpoints.R never filters ndd_entity_review by is_primary alone", {
  src <- paste(readLines("../../endpoints/entity_endpoints.R", warn = FALSE), collapse = "\n")
  # No bare `filter(is_primary)` / `filter(... is_primary)` without review_approved
  bad <- gregexpr("filter\\([^)]*is_primary[^)]*\\)", src)[[1]]
  if (bad[1] != -1) {
    for (i in seq_along(bad)) {
      frag <- substr(src, bad[i], bad[i] + attr(bad, "match.length")[i] - 1)
      expect_true(grepl("review_approved", frag),
                  info = paste("is_primary filter without review_approved:", frag))
    }
  }
  succeed()
})

test_that("primary_approved_reviews carries both predicates", {
  skip_if_not(exists("primary_approved_reviews"))
  body <- paste(deparse(body(primary_approved_reviews)), collapse = " ")
  expect_true(grepl("is_primary", body))
  expect_true(grepl("review_approved", body))
})
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-public-approved-review-guard.R')"`
Expected: FAIL — current sites filter `is_primary` only.

- [ ] **Step 3: Add the helper to `api/functions/review-repository.R`**

```r
#' Lazy tbl of PRIMARY + APPROVED reviews only — the single public-read gate.
#' Every public/anonymous review-derived read MUST source rows through this so
#' the `is_primary = 1 AND review_approved = 1` predicate cannot drift (#3).
#' Mirrors the MCP repo / SEO service / snapshot builder.
primary_approved_reviews <- function(pool, cols = NULL) {
  out <- pool %>%
    dplyr::tbl("ndd_entity_review") %>%
    dplyr::filter(is_primary == 1 & review_approved == 1)
  if (!is.null(cols)) out <- out %>% dplyr::select(dplyr::all_of(cols))
  out
}
```

- [ ] **Step 4: Update entity_endpoints.R site 1 (entity list, ~87–90)**

```r
  ndd_entity_review <- primary_approved_reviews(pool, cols = c("entity_id", "synopsis"))
```

- [ ] **Step 5: Update sites 2–5** (`/phenotypes` ~590, `/variation` ~659, `/review` ~716, `/publications` ~808)

For each, change the primary-review selection from `filter(entity_id == sysndd_id & is_primary)` to source from the helper, e.g.:

```r
  primary_review <- primary_approved_reviews(pool) %>%
    dplyr::filter(entity_id == sysndd_id) %>%
    dplyr::collect()
```

and restore `is_active == 1` on the `ndd_review_phenotype_connect` / `ndd_review_variation_ontology_connect` reads in `current_review` mode. (Read each handler and apply; the review_id used downstream now comes only from approved primary rows.)

- [ ] **Step 6: Add `status_approved == 1` to `/status` (~764)**

```r
  ndd_entity_status <- pool %>% dplyr::tbl("ndd_entity_status") %>%
    dplyr::filter(entity_id == sysndd_id & is_active == 1 & status_approved == 1)
```

- [ ] **Step 7: Run guard + smoke**

Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-public-approved-review-guard.R')"`
Expected: PASS. Then `make lint-api`.

- [ ] **Step 8: Behavioral verification (in-container / dev stack)**

With `make docker-dev-db` + API up: create/approve an entity, edit its primary review WITHOUT direct_approval (→ `review_approved=0`), then `GET /api/entity/<id>/review` and the entity list — confirm the unapproved synopsis is NOT returned. Document the check in the PR.

- [ ] **Step 9: Commit**

```bash
git add api/functions/review-repository.R api/endpoints/entity_endpoints.R api/tests/testthat/test-unit-public-approved-review-guard.R
git commit -m "fix(security): public entity reads approved-only via shared helper (#3)

Public list + /phenotypes,/variation,/review,/publications filtered is_primary
only, leaking unapproved in-place review edits. Route all 5 through
primary_approved_reviews() (is_primary=1 AND review_approved=1); add
status_approved=1 to /status; restore is_active=1 on connect reads.

Claude-Session: https://claude.ai/code/session_01Nxo1e69TNWFWXxroYEuWNX"
```

## Task 4: PR 1 — Codex high-effort review + verification gate

- [ ] **Step 1:** `make lint-api` → clean.
- [ ] **Step 2:** `make test-api-fast` → green (includes the three new guards after `docker cp`/rebuild).
- [ ] **Step 3:** Dispatch Codex at **high** reasoning effort (via the `codex` rescue skill/subagent) with the PR-1 diff and prompt: *"Adversarial security review. For each of the three fixes (hash RCE, re-review SET allowlist, approved-only entity reads): can it still be bypassed? Is any evaluation path or predicate site missed? Any regression?"* Address findings, re-run gates.
- [ ] **Step 4:** Open PR 1; verify the branch has only the intended commits (`git log --oneline master..HEAD`).

---

# PR 2 — MEDIUM + LOW (branch `security/hardening-medium-low` off `master` after PR 1 merges)

> Create the branch: `git checkout master && git pull && git checkout -b security/hardening-medium-low`

## Task 5: #4 — Allowlist user_update SET clause (MEDIUM)

**Files:** Modify `api/functions/user-repository.R:194–215`; Test `api/tests/testthat/test-unit-user-update-allowlist.R` (create).

- [ ] **Step 1: Failing test**

```r
test_that("user_update rejects unknown/injection field names", {
  skip_if_not(exists("user_update"))
  expect_error(user_update(1, list("user_role = 'x', y" = "z")))   # injection key
  expect_error(user_update(1, list(bogus_col = "x")))              # unknown col
})
```

- [ ] **Step 2:** Run → FAIL. `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-user-update-allowlist.R')"`

- [ ] **Step 3: Fix** — in `user_update()`, after stripping password fields, add before building the SET clause:

```r
  allowed_user_cols <- c("user_name", "email", "orcid", "abbreviation",
                         "first_name", "family_name", "user_role", "comment",
                         "terms_agreed", "approved", "rereview_request",
                         "password_reset_date")
  field_names <- names(updates)
  bad <- setdiff(field_names, allowed_user_cols)
  if (length(bad) > 0) {
    stop_for_bad_request(paste("Disallowed user field(s):", paste(bad, collapse = ", ")))
  }
```

(Keep the existing `set_clause`/`params` lines below, now operating on the validated `field_names`.)

- [ ] **Step 4:** Run → PASS. **Step 5:** Commit `fix(security): allowlist user_update fields (SQLi/mass-assignment) (#4)`.

## Task 6: #5 — Block Curator from demoting Administrators (MEDIUM)

**Files:** Modify `api/services/user-service.R` (add guard helper; call in `user_update_role` ~196 and `user_bulk_assign_role` ~515); Modify `api/endpoints/user_endpoints.R:306–323` (`change_role`); Test `api/tests/testthat/test-unit-role-admin-target-guard.R` (create).

- [ ] **Step 1: Failing test** (unit-test the guard helper):

```r
test_that("assert_not_targeting_admin blocks non-admin caller on admin targets", {
  skip_if_not(exists("assert_not_targeting_admin"))
  # current_roles: a lookup of target user_id -> current role
  expect_error(assert_not_targeting_admin(
    requesting_role = "Curator", target_current_roles = c("Administrator")))
  expect_silent(assert_not_targeting_admin(
    requesting_role = "Curator", target_current_roles = c("Viewer", "Reviewer")))
  expect_silent(assert_not_targeting_admin(
    requesting_role = "Administrator", target_current_roles = c("Administrator")))
})
```

- [ ] **Step 2:** Run → FAIL.

- [ ] **Step 3: Add helper to `api/services/user-service.R`:**

```r
#' A non-Administrator caller may not modify a currently-Administrator target
#' (mirrors the user_bulk_delete admin shield). (#5)
assert_not_targeting_admin <- function(requesting_role, target_current_roles) {
  if (requesting_role != "Administrator" &&
        any(target_current_roles == "Administrator")) {
    stop_for_unauthorized("Only an Administrator may modify Administrator accounts.")
  }
  invisible(TRUE)
}
```

Call it in `user_update_role(user_id, new_role, requesting_role, pool)` and `user_bulk_assign_role(user_ids, new_role, requesting_role, pool)` right after input validation — first `SELECT user_id, user_role FROM user WHERE user_id IN (...)` to get `target_current_roles`, then `assert_not_targeting_admin(requesting_role, roles)`.

- [ ] **Step 4: Wire the `change_role` endpoint** (`user_endpoints.R:306`), which currently calls `user_update` directly — route it through `user_update_role(user_id_role, role_assigned, req$user_role, pool)` so the guard applies, OR add an inline lookup + `assert_not_targeting_admin(req$user_role, current_role)` before the `user_update`.

- [ ] **Step 5:** Run → PASS. **Step 6:** Commit `fix(security): block Curator from demoting Administrators (#5)`.

## Task 7: #6 — Bound public PubTator calls (MEDIUM)

**Files:** Modify `api/endpoints/publication_endpoints.R` (`/pubtator/search` ~126–148, `/pubtator/cache-status` ~680–687); optionally add wrappers to `api/functions/publication-endpoint-helpers.R`; Test `api/tests/testthat/test-unit-pubtator-public-route-guard.R` (create).

- [ ] **Step 1: Gate cache-status (simple, high-value).** In `/pubtator/cache-status` handler, add as the first statement:

```r
  require_role(req, res, "Curator")   # SECURITY #6: operational cache probe, not public
```

- [ ] **Step 2: Bound `/pubtator/search`.** Wrap the two live calls so a slow upstream can't pin a worker and repeat hits are free. Add to `api/functions/publication-endpoint-helpers.R` (read `functions/external-proxy-functions.R` for exact `external_proxy_budget` / `external_proxy_with_timing` signatures first):

```r
# Public, budgeted + memoised PubTator search wrappers (#6). The raw
# pubtator-client fetchers stay untouched for the worker/batch callers.
pubtator_public_search <- memoise_external_success_only(function(query, page) {
  budget <- external_proxy_budget("pubtator")
  old <- options(timeout = budget$max_seconds); on.exit(options(old), add = TRUE)
  external_proxy_with_timing("pubtator", function() {
    list(
      pmids = pubtator_v3_pmids_from_request(query, page, 1L),
      total_pages = pubtator_v3_total_pages_from_query(query)
    )
  })
}, source = "pubtator")
```

Then in `/pubtator/search`, replace the two direct calls with `res_pt <- pubtator_public_search(query, current_page)` and read `res_pt$pmids` / `res_pt$total_pages`.

- [ ] **Step 3: Guard test** — assert both public pubtator routes are gated or budget-wrapped:

```r
test_that("public pubtator routes are gated or budgeted", {
  src <- paste(readLines("../../endpoints/publication_endpoints.R", warn=FALSE), collapse="\n")
  # cache-status handler must require_role
  cs <- regmatches(src, regexpr("cache-status[\\s\\S]{0,400}", src))
  expect_true(grepl("require_role", cs))
})
```

- [ ] **Step 4:** `make lint-api`; run guard → PASS. **Step 5:** Commit `fix(security): bound public PubTator calls (budget/cache + gate cache-status) (#6)`.

## Task 8: #7 — Public LLM summaries validated-only (MEDIUM)

**Files:** Modify `api/functions/llm-endpoint-helpers.R:52`; Test `api/tests/testthat/test-unit-llm-public-validated-only.R` (create).

- [ ] **Step 1: Failing static guard**

```r
test_that("public cluster-summary path requires validated summaries", {
  src <- paste(readLines("../../functions/llm-endpoint-helpers.R", warn=FALSE), collapse="\n")
  expect_false(grepl("get_cached_summary\\(raw_hash,\\s*require_validated\\s*=\\s*FALSE\\)", src))
})
```

- [ ] **Step 2:** Run → FAIL.

- [ ] **Step 3: Fix** — line 52, change `require_validated = FALSE` → `require_validated = TRUE`. Because the query now only returns `validated` rows, the `rejected` special-case (67–76) needs its own explicit lookup so the rejected card still shows. Adjust:

```r
  cached <- tryCatch(
    get_cached_summary(raw_hash, require_validated = TRUE),
    error = function(e) { log_error("Cache lookup failed: {e$message}"); NULL })

  if (!is.null(cached) && nrow(cached) > 0) {
    return(format_summary_response(cached, cluster_number))   # validated only
  }

  # A current REJECTED row is terminal (#490): surface the explicit card.
  rejected <- tryCatch(get_cached_summary(raw_hash, require_validated = FALSE,
                                          status = "rejected"),
                       error = function(e) NULL)
  if (!is.null(rejected) && nrow(rejected) > 0) {
    return(list(cluster_type = rejected$cluster_type[1],
                cluster_number = as.integer(cluster_number),
                validation_status = "rejected", summary_available = FALSE,
                reason = llm_summary_rejection_reason(rejected), generated = FALSE))
  }
  # pending / miss -> being-prepared (unchanged 404 / generation branch below)
```

(Read `functions/llm-cache-repository.R:get_cached_summary` to confirm it accepts a `status`/rejected filter; if not, add a minimal `require_validated`-style filter for the rejected lookup.)

- [ ] **Step 4:** Run → PASS. **Step 5:** Commit `fix(security): serve only validated LLM summaries on public path (#7)`.

## Task 9: LOW-1 — Scope full job-result reads for maintenance jobs

**Files:** Modify `api/functions/job-manager.R:375–382`; Test extend/new guard.

- [ ] **Step 1:** Add an admin-only set and tighten the predicate:

```r
ADMIN_ONLY_RESULT_JOB_TYPES <- c("backup_create","backup_restore","nddscore_import",
  "omim_update","hgnc_update","comparisons_update","ontology_update",
  "force_apply_ontology","publication_refresh","pubtator_update",
  "disease_ontology_mapping_refresh")

can_read_full_job_result <- function(job_type, user_role = NULL) {
  is_admin <- identical(user_role, "Administrator")
  if (!is.null(job_type) && job_type %in% ADMIN_ONLY_RESULT_JOB_TYPES) return(is_admin)
  privileged <- !is.null(user_role) && user_role %in% c("Reviewer","Curator","Administrator")
  if (privileged) return(TRUE)
  !is.null(job_type) && job_type %in% PUBLIC_FULL_RESULT_JOB_TYPES
}
```

- [ ] **Step 2:** Unit test: `can_read_full_job_result("backup_create","Reviewer")` is FALSE; `(...,"Administrator")` TRUE; `("clustering", NULL)` TRUE. **Step 3:** Commit `fix(security): restrict maintenance job-result reads to Administrator (LOW)`.

## Task 10: LOW-2 — Replace raw exception echoes with classed errors

**Files:** `api/endpoints/about_endpoints.R:131,219`, `logging_endpoints.R:272`, `publication_endpoints.R:1088`, `user_endpoints.R:903`.

- [ ] **Step 1:** For each site, replace the pattern

```r
    error = function(e) { res$status <- 500; list(error = paste("Failed to ...:", e$message)) }
```

with

```r
    error = function(e) {
      log_error("<context>: {e$message}")
      stop_for_internal("<static client message>")
    }
```

so `errorHandler` renders a generic problem+json 500 and the internal detail only goes to the log. (For `user_endpoints.R:903`, the service returns `result$error`; wrap the `return(list(error=...))` similarly.)

- [ ] **Step 2:** Guard test scanning these files for `list(error = paste(` near `e$message` → expect none. **Step 3:** Commit `fix(security): stop echoing raw exception text to clients (LOW)`.

## Task 11: LOW-3 — Harden the logging sanitizer

**Files:** `api/core/logging_sanitizer.R`; extend its unit test.

- [ ] **Step 1:** Substring-match sensitive fields — change line 42:

```r
      if (grepl("pass|token|secret|jwt|api_key|authorization|hash", tolower(name))) {
```

- [ ] **Step 2:** Redact the query string in `sanitize_request` — change line 82:

```r
    QUERY_STRING = if (is.null(req$QUERY_STRING) || req$QUERY_STRING == "") NA_character_ else "[REDACTED]",
```

- [ ] **Step 3:** Test: `sanitize_object(list(access_token="x"))$access_token == "[REDACTED]"`; `sanitize_request(list(QUERY_STRING="t=secret"))$QUERY_STRING == "[REDACTED]"`. **Step 4:** Commit `fix(security): substring-redact sensitive fields + query string in logs (LOW)`.

## Task 12: LOW-4 — Constant-time legacy password compare

**Files:** `api/core/security.R:93`.

- [ ] **Step 1:** Replace `password_from_db == password_attempt` with a constant-time compare:

```r
    isTRUE(sodium::sha256(charToRaw(as.character(password_from_db))) ==
             sodium::sha256(charToRaw(as.character(password_attempt))))
```

(digest-equality of equal-length hashes; still triggers the existing plaintext→Argon2id upgrade on success.)

- [ ] **Step 2:** Test both-match TRUE / mismatch FALSE. **Step 3:** Commit `fix(security): constant-time legacy password comparison (LOW)`.

## Task 13: LOW-5 — URL-encode external segments (hgnc, oxo)

**Files:** `api/functions/hgnc-functions.R:17,45,79,171`, `api/functions/oxo-functions.R:24`.

- [ ] **Step 1:** Wrap each interpolated segment, e.g. hgnc-functions.R:

```r
  fromJSON(paste0("http://rest.genenames.org/search/prev_symbol/",
                  utils::URLencode(symbol_input, reserved = TRUE)))
```

and oxo-functions.R:24: `..."?fromId=", utils::URLencode(ontology_id, reserved = TRUE)`.

- [ ] **Step 2:** Guard scanning both files: no `paste0("http...", <var>)` without `URLencode`. **Step 3:** Commit `fix(security): URL-encode external URL segments in hgnc/oxo fetchers (LOW)`.

## Task 14: LOW-6 & LOW-7 — mondo timeout + config::get mask

**Files:** `api/functions/mondo-functions.R:72–77`, `api/functions/metadata-refresh.R:38`.

- [ ] **Step 1: mondo** — add a budget-derived timeout to `download_mondo_sssom`, mirroring `download_mondo_sssom_full`:

```r
      budget <- external_proxy_budget("mondo")
      response <- httr2::request(sssom_url) %>%
        httr2::req_timeout(budget$timeout_seconds) %>%
        httr2::req_retry(max_tries = budget$max_tries, max_seconds = budget$max_seconds, backoff = ~2) %>%
        httr2::req_error(is_error = ~FALSE) %>%
        httr2::req_perform()
```

- [ ] **Step 2: metadata-refresh** — line 38, `get(...)` → `base::get("log_warn", mode = "function")(message)`.

- [ ] **Step 3:** Guard: `test-unit-external-budget-guard.R` already scans `mondo-functions.R`; confirm it still passes. Add a one-line assert that `metadata-refresh.R` uses `base::get`. **Step 4:** Commit `fix(correctness): mondo download timeout + base::get in metadata-refresh (LOW)`. **Restart the worker** to make these live.

## Task 15: PR 2 — Codex high-effort review + verification gate

- [ ] **Step 1:** `make lint-api` + `make test-api-fast` + `make test-api` → green.
- [ ] **Step 2:** Dispatch Codex at **high** effort with the PR-2 diff: *"Adversarial review of these 4 MEDIUM + 8 LOW security/correctness fixes — completeness of each allowlist/guard, any bypass, any regression, R masking footguns."* Address findings.
- [ ] **Step 3:** Restart `worker` + `worker-maintenance` (mondo/metadata-refresh are worker-executed). Open PR 2.

---

## Self-Review

**Spec coverage:** #1→T1, #2→T2, #3→T3, PR1 review→T4; #4→T5, #5→T6, #6→T7, #7→T8, LOW-1→T9, LOW-2→T10, LOW-3(F1/F2)→T11, LOW-4(F4)→T12, LOW-5→T13, LOW-6/LOW-7→T14, PR2 review→T15. All spec sections mapped.

**Placeholder scan:** No "TBD/TODO/implement later". Two deliberate read-then-apply steps (T2 confirm frontend field set; T8 confirm `get_cached_summary` rejected filter) carry the concrete before/after and a fallback instruction — bounded, not vague.

**Type consistency:** `primary_approved_reviews(pool, cols)`, `re_review_filter_submit_fields()`, `assert_not_targeting_admin(requesting_role, target_current_roles)`, `can_read_full_job_result(job_type, user_role)`, `pubtator_public_search(query, page)` — names used consistently across their tasks. Commit messages consistent. Guard-test file names match the File Structure map.
