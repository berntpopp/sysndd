# S0 — Endpoint Authorization (#535 P0-1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop anonymous callers from reading **draft/unapproved** curation rows and **curator identities** (names, roles, comments, workflow state) through `/api/review` and `/api/status` by gating every draft-exposing GET route at Reviewer+. (Scope note: whether *approved* review/status `comment` text exposed through the separate, approval-gated `/api/entity/*` routes is public-editorial or private-workflow is a distinct product decision tracked as a program follow-up — see §Scope boundary — and is NOT part of S0.)

**Architecture:** These two families are curation surfaces whose only consumers are the authenticated approval queues (`ApproveReview.vue`, `ApproveStatus.vue`) which call through the Bearer-authenticated `apiClient` singleton (`apiClient.raw`) and are router-gated to **Curator+**. Add `require_role(req, res, "Reviewer")` (admits Reviewer/Curator/Administrator) to each draft-exposing GET handler — the established pattern used by the write/approve routes here and by the whole `re_review` family. The four review detail/subresource handlers and the status detail handler are currently `function(<id>)` with **no `req, res`**; each signature must first be widened to `function(req, res, <id>)`. Public approved curation data continues through the already approval-gated `/api/entity/*` family, untouched.

**Tech Stack:** R / Plumber REST API, testthat. `require_role` from `api/core/middleware.R` (Viewer<Reviewer<Curator<Administrator, hierarchy-aware). Tests extract the handler function literal into a sandbox with a stubbed `require_role`.

## Global Constraints

- Keep every touched file **< 600 lines** (`make code-quality-audit`). Both endpoint files are well under.
- `require_role(req, res, min_role)` raises `error_forbidden` (403). Anonymous GETs reach the handler with `req$user_role == NULL` (middleware forwards them), so `require_role` computes `user_level = 0 < required` → **403**. Errors map to RFC 9457 problem+json via `mount_endpoint()`.
- Gate at **`"Reviewer"`** — matches the approval-queue consumers (Curator+ ⊂ Reviewer+) and lets Reviewers see the draft queue they approve.
- The `api/tests/` dir is **not** bind-mounted into the container. Run tests via: `docker cp <file> sysndd-api-1:/app/tests/testthat/` then `docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/<file>')"`. The dev stack (incl. `sysndd_mysql_test`) is up, so `with_test_db_transaction` blocks RUN (do not assume skip).

## Scope boundary (Codex review, HIGH-5)

`GET /api/entity/<id>/review` and `.../status` (`entity_endpoints.R:284,299`) are anonymous but **approval-gated** (`primary_approved_reviews()`), and they return the approved primary review/status `comment` (`entity-read-endpoint-service.R:333,354`). They do **not** leak drafts or identities. Whether an *approved* `comment` is public editorial content or private workflow metadata is a product decision. **S0 does not change these** — it is recorded as program item **S8-follow-up: "classify approved review/status comment visibility"**. The spec's earlier "entity family wholly untouched/safe" wording is narrowed accordingly.

---

### Task 1: Gate the review list + detail + subresource GET routes at Reviewer+ (and fix ALL obsolete assertions)

**Files:**
- Modify: `api/endpoints/review_endpoints.R` (list `:34`; detail `:385`; `/phenotypes` `:439`; `/variation` `:481`; `/publications` `:523`)
- Test: `api/tests/testthat/test-endpoint-review.R`

**Interfaces:**
- Produces: five review GET handlers whose first statement is `require_role(req, res, "Reviewer")`; the four detail/subresource handlers now take `function(req, res, review_id_requested)`.

- [ ] **Step 1: Invert every obsolete permission AND signature assertion (write the failing expectations first)**

In `api/tests/testthat/test-endpoint-review.R`:

(a) **Permission blocks** — the `"...: permission — public read (no require_role)"` blocks for all five GET routes (list `:200`, `/<review_id>` `:626`, `/phenotypes` `:671`, `/variation` `:711`, `/publications` `:750`) each assert `expect_false(grepl("require_role\\(", body_blob))`. For each: rename the title `— public read (no require_role)` → `— requires Reviewer+`, and change the assertion to:

```r
    expect_true(
      grepl("require_role\\(\\s*req\\s*,\\s*res\\s*,\\s*\"Reviewer\"", body_blob),
      info = "This GET route must gate at Reviewer+ (draft/curator-identity exposure)."
    )
```

(b) **Signature blocks** — the "happy path — decorator surface present" blocks at `:612`, `:652`, `:695`, `:735` assert `expect_match(sig_line, "^function\\(review_id_requested\\)")`. Change each to:

```r
    expect_match(sig_line, "^function\\(req, res, review_id_requested\\)")
```

- [ ] **Step 2: Run to verify FAIL**

Run: `docker cp api/tests/testthat/test-endpoint-review.R sysndd-api-1:/app/tests/testthat/ && docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-endpoint-review.R')"`
Expected: FAIL — handlers still lack the gate and still use the old signature.

- [ ] **Step 3: Add the gate to the list handler (`:34`)**

```r
#* @get /
function(req, res, filter_review_approved = FALSE) {
  require_role(req, res, "Reviewer")

  # Ensure logical
  filter_review_approved <- as.logical(filter_review_approved)
```

- [ ] **Step 4: Widen the four detail/subresource signatures and add the gate**

For `:385`, `:439`, `:481`, `:523`, change `function(review_id_requested) {` to `function(req, res, review_id_requested) {` and insert `require_role(req, res, "Reviewer")` as the first statement. Example (`:385`):

```r
#* @get /<review_id_requested>
function(req, res, review_id_requested) {
  require_role(req, res, "Reviewer")

  review_id_requested <- URLdecode(review_id_requested) %>%
```

- [ ] **Step 5: Run to verify PASS**

Run: `docker cp api/tests/testthat/test-endpoint-review.R sysndd-api-1:/app/tests/testthat/ && docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-endpoint-review.R')"`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add api/endpoints/review_endpoints.R api/tests/testthat/test-endpoint-review.R
git commit -m "fix(security): gate /api/review draft-exposing GET routes at Reviewer+ (#535 P0-1)"
```

---

### Task 2: Gate the status list + detail GET routes at Reviewer+ (keep `_list` public)

**Files:**
- Modify: `api/endpoints/status_endpoints.R` (list `:27`; detail `:168`; `_list` `:228` stays public)
- Test: `api/tests/testthat/test-endpoint-status.R`

**Interfaces:**
- Produces: status list + detail handlers gated at Reviewer+; detail handler takes `function(req, res, status_id_requested)`.

- [ ] **Step 1: Verify `_list` exposes only vocabulary**

Run: `sed -n '228,268p' api/endpoints/status_endpoints.R`
Expected: `_list` reads only `ndd_entity_status_categories_list` (no `user` join, no drafts, no `approving_user`/`comment`). Keep it public. (Codex confirmed this is the only intentionally-public status GET.)

- [ ] **Step 2: Invert the status list + detail permission and signature assertions; LEAVE `_list` public**

In `api/tests/testthat/test-endpoint-status.R`:
- Permission blocks: invert list `:156` and detail `:197` (rename title, `expect_false(...)` → `expect_true(grepl("require_role\\(\\s*req\\s*,\\s*res\\s*,\\s*\"Reviewer\"", body_blob), info=...)`). **Leave the `_list` block `:245` as `expect_false`** (stays public).
- Signature block: the detail "happy path" block at `:183` asserts `expect_match(sig_line, "^function\\(status_id_requested\\)")`; change to `expect_match(sig_line, "^function\\(req, res, status_id_requested\\)")`.

- [ ] **Step 3: Run to verify FAIL**

Run: `docker cp api/tests/testthat/test-endpoint-status.R sysndd-api-1:/app/tests/testthat/ && docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-endpoint-status.R')"`
Expected: FAIL.

- [ ] **Step 4: Add the gate to the status list handler (`:27`)**

```r
#* @get /
function(req, res, filter_status_approved = FALSE) {
  require_role(req, res, "Reviewer")

  filter_status_approved <- as.logical(filter_status_approved)
```

- [ ] **Step 5: Widen the detail signature and gate (`:168`); document `_list` stays public (`:228`)**

```r
#* @get /<status_id_requested>
function(req, res, status_id_requested) {
  require_role(req, res, "Reviewer")

  status_id_requested <- URLdecode(status_id_requested) %>%
```
Add above `:228`:
```r
#* Public: returns only the status-category vocabulary (ndd_entity_status_categories_list);
#* no draft rows, curator identities, or approval state. Consumed by public entity-create option loaders.
#* @get _list
```

- [ ] **Step 6: Run to verify PASS**

Run: `docker cp api/tests/testthat/test-endpoint-status.R sysndd-api-1:/app/tests/testthat/ && docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-endpoint-status.R')"`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add api/endpoints/status_endpoints.R api/tests/testthat/test-endpoint-status.R
git commit -m "fix(security): gate /api/status draft-exposing GET routes at Reviewer+ (#535 P0-1)"
```

---

### Task 3: Behavioral denial tests for ALL seven gated GET routes (deny-before-query + body non-disclosure)

**Files:**
- Test: `api/tests/testthat/test-endpoint-review.R`, `api/tests/testthat/test-endpoint-status.R`

**Interfaces:**
- Consumes: `extract_review_handler(decorator_regex, envir)` / `extract_status_handler(...)` (grep the status file for its actual extractor name and use it — do not invent one).
- Produces: a behavioral 403 test per gated route proving the gate fires **before** any DB access (a sentinel `pool` that errors if queried), for all 5 review routes + 2 status routes (list + detail).

- [ ] **Step 1: Add a query-sentinel behavioral denial test per review route**

Append to `api/tests/testthat/test-endpoint-review.R`. The sentinel `pool` is an object whose use as a dbplyr source errors, proving the handler stops at `require_role` before touching data:

```r
test_that("review GET routes: anonymous/insufficient role is denied BEFORE any DB access (403)", {
  with_test_db_transaction({
    deny <- function(req, res, min_role) { res$status <- 403L; stop("forbidden") }
    # decorator -> (id-arg?) for each gated GET route
    routes <- list(
      list(dec = "^#\\*\\s+@get\\s+/\\s*$",                                  args = list()),
      list(dec = "^#\\*\\s+@get\\s+/<review_id_requested>\\s*$",             args = list(review_id_requested = "1")),
      list(dec = "^#\\*\\s+@get\\s+/<review_id_requested>/phenotypes\\s*$",  args = list(review_id_requested = "1")),
      list(dec = "^#\\*\\s+@get\\s+/<review_id_requested>/variation\\s*$",   args = list(review_id_requested = "1")),
      list(dec = "^#\\*\\s+@get\\s+/<review_id_requested>/publications\\s*$",args = list(review_id_requested = "1"))
    )
    for (r in routes) {
      env <- new.env(parent = globalenv())
      env$require_role <- deny
      # sentinel: any dbplyr use errors, so a green test proves deny-before-query
      env$pool <- structure(list(), class = "SENTINEL_DB")
      handler <- extract_review_handler(r$dec, env)
      res <- new.env(); res$status <- 200L
      call_args <- c(list(req = list(), res = res), r$args)
      expect_error(do.call(handler, call_args), "forbidden", info = r$dec)
      expect_equal(res$status, 403L)
    }
  })
})
```

- [ ] **Step 2: Add the analogous status behavioral test (list + detail; NOT `_list`)**

Append to `api/tests/testthat/test-endpoint-status.R` using its extractor, for routes
`"^#\\*\\s+@get\\s+/\\s*$"` (list, no id arg) and `"^#\\*\\s+@get\\s+/<status_id_requested>\\s*$"`
(`status_id_requested = "1"`). Do **not** include `_list` (it is public by design).

- [ ] **Step 3: Run both files to verify PASS**

Run: `docker cp api/tests/testthat/test-endpoint-review.R sysndd-api-1:/app/tests/testthat/ && docker cp api/tests/testthat/test-endpoint-status.R sysndd-api-1:/app/tests/testthat/ && docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-endpoint-review.R'); testthat::test_file('/app/tests/testthat/test-endpoint-status.R')"`
Expected: PASS. If the extractor evaluates the whole body eagerly and the deny stub's `stop()` is reached first, the sentinel `pool` is never touched (proving deny-before-query). If a route's handler references helpers not stubbed in `env`, add minimal stubs to `env` (mirror the existing `make_review_sandbox` stub set) — but the deny path must still short-circuit first.

- [ ] **Step 4: Commit**

```bash
git add api/tests/testthat/test-endpoint-review.R api/tests/testthat/test-endpoint-status.R
git commit -m "test(security): deny-before-query 403 coverage for all gated review/status GET routes (#535 P0-1)"
```

---

### Task 4: Live verification (Reviewer positive control + anonymous body non-disclosure) + gate

**Files:** none (verification only)

- [ ] **Step 1: File-size ratchet**

Run: `make code-quality-audit`
Expected: PASS.

- [ ] **Step 2: Restart API so the endpoint edits are live, then anonymous denial + body inspection**

The container bind-mounts `api/endpoints`, so edits are live after a restart:
```bash
docker compose restart api
# Anonymous → 403 with a problem+json body that contains NO draft rows / identities:
for p in /api/review/ /api/status/ /api/review/1 /api/review/1/phenotypes /api/review/1/variation /api/review/1/publications /api/status/1; do
  echo -n "$p -> "; curl -s -o /tmp/body.$$ -w "%{http_code}" "http://localhost$p"; echo " body: $(head -c 200 /tmp/body.$$)"; done
# Public vocab still 200:
curl -s -o /dev/null -w "/api/status/_list -> %{http_code}\n" http://localhost/api/status/_list
```
Expected: all seven gated routes → **403**, body is problem+json (`application/problem+json`, `title`/`detail` about privileges), **no** `synopsis`/`comment`/`review_user_name`/`approving_user_name`. `_list` → **200**.

- [ ] **Step 3: Reviewer positive control**

Mint a Reviewer JWT (repo recipe: `config::get("sysndd_db")` secret coerced + `auth_generate_token`), then:
```bash
for p in /api/review/ /api/review/1 /api/status/; do
  echo -n "$p -> "; curl -s -o /dev/null -w "%{http_code}\n" -H "Authorization: Bearer $REVIEWER_JWT" "http://localhost$p"; done
```
Expected: **200** (data returned). This proves the gate admits Reviewer+ and does not over-block the approval queues.

- [ ] **Step 4: Fast API PR gate**

Run: `make test-api-fast`
Expected: PASS; the inverted/new blocks run (not skipped) against the dev DB.

## Self-Review

- **Spec coverage (S0 §4):** drafts/identities no longer anonymous (gated, Task 1–2), all obsolete permission+signature assertions inverted (Codex BLOCKER-1, Task 1–2), behavioral deny-before-query for all seven routes + Reviewer positive control + body non-disclosure (Codex HIGH-6, Task 3–4), `_list` kept public with justification.
- **Scope boundary:** approved-comment exposure via entity endpoints explicitly out of S0 and recorded as a follow-up (Codex HIGH-5).
- **Placeholder scan:** none — exact code and commands. The one adaptive point (status extractor helper name) has a grep-and-match instruction.
- **Type/name consistency:** `require_role(req, res, "Reviewer")` and `function(req, res, <id>_requested)` used identically throughout. Router-consumer note corrected to **Curator+** (Codex LOW-10).
