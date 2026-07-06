# Security & Bug-Scan Remediation — Design

- **Date:** 2026-07-06
- **Author:** security bug-scan follow-up (`sysndd-security-bug-scan` skill)
- **Status:** approved design → implementation planning
- **Scope:** API (`api/`) only. No frontend changes required except where a
  server contract that the frontend already consumes is tightened (none change
  the wire shape in a breaking way).

## 1. Context

A full-surface security + correctness review (six parallel dimension passes:
authorization, injection, MCP/public data exposure, DoS/external calls,
secrets/error-leakage, R/Plumber correctness footguns) found three HIGH, four
MEDIUM, and eight LOW defects. Every HIGH/MEDIUM was verified against live code.

The unifying root cause is the skill's core insight: **almost every finding is
"a hand-rolled path bypassed a safe helper that already exists in the repo."**
The RCE and the two SQL-injections bypass the `validate_query_column` /
allowlist discipline used everywhere else; the data-exposure bug is
`review_approved = 1` predicate drift versus the MCP repo / SEO service /
snapshot builder; the DoS bypasses `external_proxy_budget`; the LOW items bypass
`errorHandler`, `sanitize_request`, `base::get`, and `URLencode`.

Design principle for every fix: **reuse the existing in-repo helper/pattern;
validate-before-use; fail loud (classed error), not silent.**

## 2. Delivery structure

Two branches / PRs (user-selected: split hotfix first).

| PR | Branch | Findings | Rationale |
|----|--------|----------|-----------|
| **PR 1 — hotfix** | `security/hotfix-rce-sqli-exposure` | #1 RCE, #2 re-review SQLi, #3 public data exposure | A live authenticated RCE must leave `master` fast; small diff → rigorous Codex review. |
| **PR 2 — hardening** | `security/hardening-medium-low` | #4 user_update SQLi, #5 Curator→Admin demotion, #6 PubTator DoS, #7 unvalidated LLM summaries, + 8 LOW items | Lower urgency; larger surface; reviewed as a set. |

Each finding is one atomic commit with its guard test. Release/version bump per
repo convention (`app/package.json`, `api/version_spec.json`, `CHANGELOG.md`)
handled at PR close, not per commit.

## 3. PR 1 — HIGH fixes

### 3.1 #1 — Authenticated RCE via the hash endpoint

- **Where:** `api/functions/data-helpers.R` `post_db_hash()` (lines ~220–253),
  reached from `api/endpoints/hash_endpoints.R:34` (`POST /api/hash/create`).
- **Mechanism:** `arrange(!!!rlang::parse_exprs((json_tibble %>% colnames())[1]))`
  parses the **first key of the attacker JSON body** as an R expression and
  evaluates it via dplyr data-masking in the process environment. The
  `hash_validate_columns()` allowlist runs at line 253 — *after* the eval, and
  after the no-DB early-return (238–250). Payload
  `{"json_data":{"system('…')":[1]}}` → arbitrary shell as the API user.
- **Reachability:** not in `AUTH_ALLOWLIST` (needs a Bearer token) but the
  handler has **no `require_role`** → any authenticated user (Viewer+).
- **Fix (two independent barriers):**
  1. **Validate first.** Move `hash_validate_columns(colnames(json_tibble), allowed_col_list)`
     to immediately after `as_tibble(json_data)`, *before* the `arrange` and the
     no-DB branch, so an unexpected column name is rejected (400, classed error)
     before anything evaluates it.
  2. **Remove the eval entirely.** Replace the `parse_exprs` sort with a
     non-eval column reference:
     `arrange(dplyr::across(dplyr::all_of(colnames(json_tibble)[1])))`.
     A column token can never again be interpreted as code, even if the
     allowlist is ever loosened.
- **Not doing:** adding a role gate. The hash-create utility legitimately backs
  shareable filtered-list links for any authenticated user; input hardening
  fully closes the RCE without a behavior change. (Reachability re-confirmed in
  the plan.)
- **Guard test:** a malicious column name (`system('id')`) is rejected with a
  400 and never evaluated; a valid `symbol`/`hgnc_id`/`entity_id` payload still
  hashes. New file `test-unit-hash-endpoint-injection.R`.

### 3.2 #2 — SQL injection (+ mass-assignment) via re-review submit

- **Where:** `api/endpoints/re_review_endpoints.R:33–44` (`PUT /api/re_review/submit`,
  `require_role("Reviewer")`).
- **Mechanism:** `fields_to_update <- names(submit_data)[…]` — the JSON **keys**
  are interpolated raw as SQL identifiers into `UPDATE re_review_entity_connect
  SET <keys> = ?`. Values are bound; identifiers are not. A crafted key
  (`re_review_submitted = IF((SELECT …),SLEEP(5),0), dummy`) yields valid,
  placeholder-balanced SQL → time-based blind exfiltration by any Reviewer.
- **Secondary defect (bonus hardening):** even without injection, an arbitrary
  key set is a **mass-assignment / self-approval** hole — a Reviewer can set
  `re_review_approved = 1` or `approving_user_id` (approval is meant to be a
  separate Curator action).
- **Table columns:** `re_review_entity_id`(PK), `entity_id`, `re_review_batch`,
  `re_review_review_saved`, `re_review_status_saved`, `re_review_submitted`,
  `re_review_approved`, `approving_user_id`, `status_id`, `review_id`.
- **Fix:** intersect `fields_to_update` with an **allowlist of the columns the
  submit workflow legitimately writes** (a subset of the table's non-identity
  columns — the exact set confirmed in the plan against the frontend re-review
  submit payload + `services/re-review-service.R`; approval/identity columns
  `re_review_approved`/`approving_user_id`/`re_review_entity_id`/`entity_id`
  excluded). Reject any key outside the allowlist with `stop_for_bad_request`
  (fail loud). Run each surviving key through `validate_query_column` as a
  bare-identifier backstop. This closes injection **and** the self-approval
  mass-assignment. Values remain `unname()`-bound (already correct).
- **Guard test:** an injection key and an out-of-allowlist key (`re_review_approved`)
  are both rejected 400; a legitimate submit still updates. Extend/new
  `test-unit-re-review-submit-allowlist.R`.

### 3.3 #3 — Public endpoints leak unapproved curation

- **Where (all public, unauthenticated GET — `require_auth` forwards tokenless
  GETs, `core/middleware.R:94`):** `api/endpoints/entity_endpoints.R`
  entity-list review join (line ~89) and `/phenotypes` (~590), `/variation`
  (~659), `/review` (~716), `/publications` (~808).
- **Mechanism:** these filter `ndd_entity_review` on `is_primary` **only**,
  omitting `review_approved == 1`. `review_update()`
  (`functions/review-repository.R:227–232`) resets `review_approved = 0` but
  leaves `is_primary` untouched, so a `PUT /api/review/update` in-place edit of
  the current primary review (without `direct_approval`) produces
  `is_primary = 1, review_approved = 0` with **new, unapproved** content — then
  served to anonymous visitors. The MCP repo, `seo-service.R:211`, and the
  snapshot builder all correctly gate on `is_primary = 1 AND review_approved = 1`.
- **Fix (shared helper — drift-proof, Fork A / recommended):**
  1. Add a helper `primary_approved_reviews(pool)` (in
     `functions/review-repository.R` or `functions/entity-helpers.R`) returning
     the lazy `ndd_entity_review` tbl filtered
     `is_primary == 1 & review_approved == 1`. All five sites consume it instead
     of hand-writing `filter(is_primary)`. One predicate, one place, cannot
     drift again.
  2. Restore `is_active == 1` on the phenotype/variation connect reads in
     `current_review` mode (to match the MCP repo).
  3. Add `status_approved == 1` to `/api/entity/<id>/status`
     (entity_endpoints.R ~764) — defense-in-depth consistency (the
     `is_active=1, status_approved=0` state is only reachable by an explicit
     `is_active=1` status update, hence lower risk, but the invariant should
     hold uniformly).
- **Behavior note:** the entity-list join is a `left_join`; adding the predicate
  means an unapproved primary review simply does not join (synopsis → NA), so
  the entity still lists but without leaking the unapproved synopsis — correct,
  and dbplyr-translatable so the fast-path SQL pushdown is unaffected.
- **Guard test:** seed an entity whose primary review is `review_approved = 0`;
  assert the public list + the four sub-endpoints exclude its review-derived
  content. New `test-integration-public-approved-only.R` (or extend an existing
  entity endpoint test); a unit test on `primary_approved_reviews()` asserts
  both predicates are present.

## 4. PR 2 — MEDIUM + LOW fixes

### 4.1 #4 — SQL injection via user_update SET clause (MEDIUM)

- **Where:** `api/functions/user-repository.R:206–209`, reached from
  `PUT /api/user/update` (`user_endpoints.R:888`, `require_role("Administrator")`).
- **Fix:** in `user_update()`, intersect `field_names` with the updatable `user`
  columns — `user_name, email, orcid, abbreviation, first_name, family_name,
  user_role, comment, terms_agreed, approved, rereview_request,
  password_reset_date` (PK `user_id`, `password`/`user_password_hash`,
  `created_at` excluded). Reject unknown keys (classed error). Mirrors the
  already-in-repo allowlist in `ontology_endpoints.R:272–289`.
- **Guard test:** injection/unknown key rejected; legitimate multi-field update
  still works.

### 4.2 #5 — Curator can demote Administrators (MEDIUM)

- **Where:** `endpoints/user_endpoints.R:313–322` (`change_role`),
  `services/user-service.R` `user_update_role` (~196–223) and
  `user_bulk_assign_role` (~515–533).
- **Mechanism:** all three block *assigning* the Administrator role but never
  check the **target's current** role → a Curator can demote any/all
  Administrators to Viewer. Inconsistent with `user_bulk_delete`, which rejects
  selections containing admins (`user-service.R:457–461`).
- **Fix:** add an admin-target guard — when the requesting role is not
  `Administrator` and any target user's **current** `user_role` is
  `Administrator`, reject (403, classed `stop_for_unauthorized`). Apply in all
  three role-mutation paths so they stay consistent; factor the check into one
  helper to avoid a third copy of the rule.
- **Guard test:** a Curator demoting an Administrator (single + bulk) → 403;
  a Curator changing a Viewer→Reviewer still works; an Administrator can still
  do anything.

### 4.3 #6 — Public synchronous PubTator calls bypass budget/ceiling/cache (MEDIUM)

- **Where:** `endpoints/publication_endpoints.R:134–136` (`GET /pubtator/search`)
  and `:687` (`GET /pubtator/cache-status`); both call raw `jsonlite::fromJSON`
  fetchers in `functions/pubtator-client.R` (no budget, no memoise, bypassing
  the #344 per-request external-time ceiling).
- **Fix (Fork B / recommended):**
  - `/pubtator/search` (fixed internal query): route the two live calls through
    `external_proxy_budget("pubtator")`-derived timeout **and** the per-request
    ceiling wrapper (`external_proxy_with_timing("pubtator", …)`), and memoise
    the fixed-query result with `memoise_external_success_only(source="pubtator")`
    so repeat hits are free and a slow upstream can't pin a worker.
  - `/pubtator/cache-status` (user-supplied `query`, operational): **gate to
    `require_role("Curator")`** and budget-wrap the live `total_pages` probe.
    This removes the unauthenticated, cache-defeating attack surface.
- **Note:** the PubTator client stays raw for its worker/batch callers (it has
  its own pacing and is intentionally outside the budget-guard scan set); only
  the **public request path** is wrapped. Add a `test-unit`/route guard that the
  public pubtator GET path does not make an unbounded external call.
- **Guard test:** extend `test-unit-cheap-route-isolation.R`-style coverage for
  these public routes (budget-wrapped / gated).

### 4.4 #7 — Public serves un-judge-validated LLM summaries (MEDIUM)

- **Where:** `functions/llm-endpoint-helpers.R:52` — public `get_cluster_summary()`
  calls `get_cached_summary(raw_hash, require_validated = FALSE)` and falls
  through to serve `pending` rows.
- **Fix:** pass `require_validated = TRUE` on the public/cache-hit path so only
  `validated` rows are served; a `pending` row reads as "being prepared" (same
  as a miss / 404-style being-prepared response); keep the explicit `rejected`
  card. The Curator+ on-demand generation branch is unchanged (it returns freshly
  generated `pending` to the privileged caller only). Matches the MCP default
  and the file's own comment at :66.
- **Guard test:** a `pending` cache row is not served on the public path; a
  `validated` row is; a `rejected` row still yields the rejected card.

### 4.5 LOW items (one commit + guard each where a guard is meaningful)

1. **`functions/job-manager.R:375`** `can_read_full_job_result` — scope
   maintenance/admin job types (backup/nddscore/omim/hgnc/comparisons/…) to
   `Administrator`; keep the public `PUBLIC_FULL_RESULT_JOB_TYPES` fast-path and
   Reviewer/Curator access only for review/curation job types.
2. **Raw exception echo** (`about_endpoints.R:131,219`, `logging_endpoints.R:272`,
   `publication_endpoints.R:1088`, `user_endpoints.R:903`) — replace
   `return(list(error = e$message))` (`res$status <- 500`) with a classed
   `stop_for_internal(<static message>)` and an internal `log_error(e$message)`;
   let `errorHandler` render the client response so DB/driver detail never
   crosses the boundary.
3. **`core/logging_sanitizer.R`** — F1: redact/parse `QUERY_STRING` in
   `sanitize_request()` (currently retained raw). F2: match `SENSITIVE_FIELDS`
   by substring/pattern (`grepl("pass|token|secret|jwt|api_key|authorization|hash", …)`)
   so `access_token`/`refresh_token`/`password_hash` compounds are redacted.
   Extend the sanitizer's existing unit test.
4. **`core/security.R:93`** — legacy plaintext compare uses `==`; replace with a
   constant-time comparison (digest-based fixed-time compare) on the legacy path.
5. **`functions/hgnc-functions.R:17,45,79,171` + `functions/oxo-functions.R:24`**
   — wrap external URL path/query segments in `utils::URLencode(x, reserved = TRUE)`
   (as `hpo-functions.R` / `ols-functions.R` already do).
6. **`functions/mondo-functions.R:74–77`** `download_mondo_sssom` — add
   `req_timeout` + `req_retry(max_seconds=…)` derived from
   `external_proxy_budget("mondo")`, mirroring `download_mondo_sssom_full`.
7. **`functions/metadata-refresh.R:38`** — `get("log_warn", mode="function")`
   hits the `config::get` mask (always errors → degrades to `warning()`); use
   `base::get("log_warn", mode = "function")`.

## 5. Codex high-effort review gate (Fork C)

After each PR's diff is implemented and the local gates pass, run **Codex at
high reasoning effort** as an adversarial security reviewer via the `codex`
rescue path: *"Here is the diff for finding X — can the fix be bypassed? Is the
allowlist/predicate/gate complete? Any regression?"* Address Codex findings
before merge. Optionally pressure-test this spec/plan with Codex first. Codex
review is advisory on top of — not a replacement for — the repo's own guard
tests.

## 6. Testing & verification

- Every finding ships a guard test (named above). Guard-test philosophy matches
  the repo: a static/unit guard that fails if the fix regresses.
- Per-PR gate: `make lint-api` + `make test-api-fast` + the touched guard files,
  then `make test-api` before merge if scope warrants.
- Container boundary: `api/tests/` is **not** bind-mounted; run new tests via
  `docker exec … Rscript -e "testthat::test_file('/app/tests/testthat/…')"` after
  `docker cp`, or on the host where the test does not need the DB.
- All PR-1 and most PR-2 fixes are API-path (endpoints/repositories/core) → live
  on API container restart (bind mount). Worker-executed touches (#6 batch side
  is untouched; `mondo-functions.R`, `metadata-refresh.R`) require a **worker
  restart** to go live — noted in the plan.

## 7. Non-goals / out of scope

- No broad refactor of the entity endpoints beyond the shared review helper.
- No change to the public hash-create authorization model (input hardening only).
- No new DB migration (all fixes are code-level; allowlists are derived from
  existing schema).
- Frontend changes are out of scope; no server response wire shape changes in a
  breaking way (the LLM `pending` path already had a "being prepared" UX; the
  entity endpoints still return the same fields, just approved-only).
- Deferred/tracked separately: true heavy/light worker-pool isolation (#154),
  broader typed-client frontend migration.

## 8. Risks & mitigations

| Risk | Mitigation |
|------|------------|
| #2/#4 allowlist too narrow → breaks a legitimate submit/update | Derive the writable set from the actual frontend payload + service in the plan; guard test exercises a real legitimate call. |
| #3 predicate change hides a review that *should* be public | Only rows with `review_approved = 0` are hidden — that is the definition of "not approved"; matches every other public surface. |
| #6 memoise serves a stale pubtator page | `memoise_external_success_only` caches successes only with the repo's standard TTL; the query is fixed for `/search`. |
| RCE fix + no-eval `arrange` changes sort output | Sort semantics preserved (`across(all_of(col))` sorts by the same single column); guard test asserts identical hash for a valid payload. |
| Worker code changed but not restarted → fix not live | Plan's verification step restarts the worker for `mondo`/`metadata-refresh` touches. |
