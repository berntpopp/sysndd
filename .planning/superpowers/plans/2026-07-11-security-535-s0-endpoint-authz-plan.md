# S0 — Endpoint Authorization (#535 P0-1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop anonymous callers from reading draft/unapproved curation rows, curator identities, roles, comments, and workflow state through `/api/review` and `/api/status` by gating every draft-exposing GET route at Reviewer+.

**Architecture:** These two endpoint families are curation surfaces whose only consumers are the authenticated approval queues (`ApproveReview.vue`, `ApproveStatus.vue`) which call through the Bearer-authenticated `apiClient` singleton and are router-gated to Administrator/Curator/Reviewer. Add `require_role(req, res, "Reviewer")` to each draft-exposing GET handler (the established pattern already used by write/approve routes and the whole `re_review` family). Detail/subresource handlers must first have `req, res` added to their signatures. Public approved curation data continues to flow through the already approved-gated `/api/entity/*` family, untouched.

**Tech Stack:** R / Plumber REST API, testthat. `require_role` from `api/core/middleware.R` (Viewer<Reviewer<Curator<Administrator, hierarchy-aware). Tests use handler-extraction sandboxes with a stubbed `require_role`.

## Global Constraints

- Keep every touched file **< 600 lines** (`make code-quality-audit` ratchet). `review_endpoints.R` and `status_endpoints.R` are well under; the edits are small.
- Endpoint sub-routers are mounted via `mount_endpoint()`; classed errors (`stop_for_unauthorized`/`error_403` from `require_role`) map to RFC 9457 problem+json. Do not add bare `pr_mount`.
- `require_role(req, res, min_role)` raises `error_forbidden` (403) for insufficient role and, because `require_auth` (`middleware.R:94-97`) forwards anonymous GETs with `req$user_role == NULL`, an anonymous caller hits `user_level = 0 < required` → 403. (Anonymous non-GET already 401s upstream; these are GET routes.)
- Gate at **`"Reviewer"`** (admits Reviewer/Curator/Administrator) — matches the approval-queue router guard and lets Reviewers see the draft queue they must approve.
- Tests run in the API container (the `api/tests/` dir is **not** bind-mounted): `docker cp` the changed test files into `sysndd-api-1:/app/tests/testthat/` then `docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/<file>')"`, or run `make test-api-fast`. Do not assume host `Rscript` has a test DB.

---

### Task 1: Gate the review list + detail + subresource GET routes at Reviewer+

**Files:**
- Modify: `api/endpoints/review_endpoints.R` (list handler at `:34`; detail `:385`; `/phenotypes` `:439`; `/variation` `:481`; `/publications` `:523`)
- Test: `api/tests/testthat/test-endpoint-review.R`

**Interfaces:**
- Consumes: `require_role(req, res, min_role)` (already in scope in the endpoint runtime; stubbed in tests).
- Produces: five review GET handlers that call `require_role(req, res, "Reviewer")` as their first statement; the four detail/subresource handlers now take `function(req, res, review_id_requested)`.

- [ ] **Step 1: Invert the existing "public read" permission test and add detail-route permission assertions**

In `api/tests/testthat/test-endpoint-review.R`, replace the block titled
`"GET / review list: permission — public read (no require_role)"` (around `:200`) with:

```r
test_that("GET / review list: permission — requires Reviewer+ (require_role gate present)", {
  with_test_db_transaction({
    src <- review_source()
    dec_idx <- grep("^#\\*\\s+@get\\s+/\\s*$", src)[[1L]]
    next_decorator <- grep("^#\\*\\s+@(get|post|put|delete)\\b", src)
    next_after <- next_decorator[next_decorator > dec_idx][[1L]]
    body_blob <- paste(src[dec_idx:(next_after - 1L)], collapse = "\n")
    expect_true(
      grepl("require_role\\(\\s*req\\s*,\\s*res\\s*,\\s*\"Reviewer\"", body_blob),
      info = "GET /review must gate at Reviewer+ (draft/curator-identity exposure)."
    )
  })
})

test_that("GET /<review_id> + subresources: permission — each gates at Reviewer+", {
  with_test_db_transaction({
    src <- review_source()
    for (dec in c("^#\\*\\s+@get\\s+/<review_id_requested>\\s*$",
                  "^#\\*\\s+@get\\s+/<review_id_requested>/phenotypes\\s*$",
                  "^#\\*\\s+@get\\s+/<review_id_requested>/variation\\s*$",
                  "^#\\*\\s+@get\\s+/<review_id_requested>/publications\\s*$")) {
      dec_idx <- grep(dec, src)[[1L]]
      nexts <- grep("^#\\*\\s+@(get|post|put|delete)\\b", src)
      after <- nexts[nexts > dec_idx][[1L]]
      body_blob <- paste(src[dec_idx:(after - 1L)], collapse = "\n")
      expect_true(
        grepl("require_role\\(\\s*req\\s*,\\s*res\\s*,\\s*\"Reviewer\"", body_blob),
        info = paste("Missing Reviewer+ gate on", dec)
      )
    }
  })
})
```

- [ ] **Step 2: Run the tests to verify they FAIL**

Run: `docker cp api/tests/testthat/test-endpoint-review.R sysndd-api-1:/app/tests/testthat/ && docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-endpoint-review.R')"`
Expected: FAIL — the handlers do not yet contain `require_role(req, res, "Reviewer")`.

- [ ] **Step 3: Add `require_role` to the list handler**

In `api/endpoints/review_endpoints.R`, the list handler at `:34`:

```r
#* @get /
function(req, res, filter_review_approved = FALSE) {
  require_role(req, res, "Reviewer")

  # Ensure logical
  filter_review_approved <- as.logical(filter_review_approved)
```

- [ ] **Step 4: Widen detail/subresource signatures and add the gate**

For each of the four handlers (`:385`, `:439`, `:481`, `:523`), change the signature from
`function(review_id_requested) {` to add `req, res` and gate. Example for `:385`:

```r
#* @get /<review_id_requested>
function(req, res, review_id_requested) {
  require_role(req, res, "Reviewer")

  review_id_requested <- URLdecode(review_id_requested) %>%
```

Apply the identical two-line change (`req, res` in signature + `require_role(req, res, "Reviewer")` as first statement) to `/phenotypes` (`:439`), `/variation` (`:481`), and `/publications` (`:523`).

- [ ] **Step 5: Run the tests to verify they PASS**

Run: `docker cp api/tests/testthat/test-endpoint-review.R sysndd-api-1:/app/tests/testthat/ && docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-endpoint-review.R')"`
Expected: PASS (all blocks; no new skips beyond the pre-existing DB-gated ones).

- [ ] **Step 6: Commit**

```bash
git add api/endpoints/review_endpoints.R api/tests/testthat/test-endpoint-review.R
git commit -m "fix(security): gate /api/review draft-exposing GET routes at Reviewer+ (#535 P0-1)"
```

---

### Task 2: Gate the status list + detail GET routes at Reviewer+ (keep `_list` category vocab public)

**Files:**
- Modify: `api/endpoints/status_endpoints.R` (list handler at `:27`; detail `:168`; leave `_list` `:228` public with a justifying comment)
- Test: `api/tests/testthat/test-endpoint-status.R`

**Interfaces:**
- Consumes: `require_role(req, res, min_role)`.
- Produces: status list + detail handlers gated at Reviewer+; detail handler takes `function(req, res, status_id_requested)`.

- [ ] **Step 1: Verify `_list` exposes only vocabulary (decide public vs gate)**

Run: `sed -n '228,268p' api/endpoints/status_endpoints.R`
Expected: the `_list` handler reads only `ndd_entity_status_categories_list` (a category lookup, no curation rows, no `user` join, no `approving_user`/`comment`). It is consumed by public entity-create option loaders. **Decision:** keep `_list` public. If this inspection instead shows any draft/identity/`user`-join exposure, gate it at Reviewer+ too and note the deviation in the commit.

- [ ] **Step 2: Invert the existing status "public read" test and add the detail assertion**

In `api/tests/testthat/test-endpoint-status.R`, replace the block titled
`"GET / status list: permission — public read (no require_role)"` (around `:156`) with:

```r
test_that("GET / status list: permission — requires Reviewer+ (require_role gate present)", {
  with_test_db_transaction({
    src <- status_source()
    dec_idx <- grep("^#\\*\\s+@get\\s+/\\s*$", src)[[1L]]
    next_dec <- grep("^#\\*\\s+@(get|post|put|delete)\\b", src)
    after <- next_dec[next_dec > dec_idx][[1L]]
    body_blob <- paste(src[dec_idx:(after - 1L)], collapse = "\n")
    expect_true(
      grepl("require_role\\(\\s*req\\s*,\\s*res\\s*,\\s*\"Reviewer\"", body_blob),
      info = "GET /status must gate at Reviewer+ (draft/curator-identity exposure)."
    )
  })
})

test_that("GET /<status_id>: permission — gates at Reviewer+", {
  with_test_db_transaction({
    src <- status_source()
    dec_idx <- grep("^#\\*\\s+@get\\s+/<status_id_requested>\\s*$", src)[[1L]]
    next_dec <- grep("^#\\*\\s+@(get|post|put|delete)\\b", src)
    after <- next_dec[next_dec > dec_idx][[1L]]
    body_blob <- paste(src[dec_idx:(after - 1L)], collapse = "\n")
    expect_true(
      grepl("require_role\\(\\s*req\\s*,\\s*res\\s*,\\s*\"Reviewer\"", body_blob),
      info = "GET /status/<id> must gate at Reviewer+."
    )
  })
})
```

- [ ] **Step 3: Run tests to verify they FAIL**

Run: `docker cp api/tests/testthat/test-endpoint-status.R sysndd-api-1:/app/tests/testthat/ && docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-endpoint-status.R')"`
Expected: FAIL — handlers lack the gate.

- [ ] **Step 4: Add the gate to the status list handler**

`api/endpoints/status_endpoints.R:27`:

```r
#* @get /
function(req, res, filter_status_approved = FALSE) {
  require_role(req, res, "Reviewer")

  filter_status_approved <- as.logical(filter_status_approved)
```

- [ ] **Step 5: Widen the detail signature and add the gate**

`api/endpoints/status_endpoints.R:168`:

```r
#* @get /<status_id_requested>
function(req, res, status_id_requested) {
  require_role(req, res, "Reviewer")

  status_id_requested <- URLdecode(status_id_requested) %>%
```

Add a one-line comment above the `_list` handler at `:228` documenting why it stays public:

```r
#* Public: returns only the status-category vocabulary (ndd_entity_status_categories_list);
#* no draft rows, curator identities, or approval state. Consumed by public entity-create option loaders.
#* @get _list
```

- [ ] **Step 6: Run tests to verify they PASS**

Run: `docker cp api/tests/testthat/test-endpoint-status.R sysndd-api-1:/app/tests/testthat/ && docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-endpoint-status.R')"`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add api/endpoints/status_endpoints.R api/tests/testthat/test-endpoint-status.R
git commit -m "fix(security): gate /api/status draft-exposing GET routes at Reviewer+ (#535 P0-1)"
```

---

### Task 3: Add behavioral anonymous-denial + Reviewer-allow tests (defense against regression)

**Files:**
- Test: `api/tests/testthat/test-endpoint-review.R`, `api/tests/testthat/test-endpoint-status.R`

**Interfaces:**
- Consumes: `extract_review_handler(decorator_regex, envir)` / `make_review_sandbox(...)` and the analogous status helpers already defined in each test file; a `deny_role` stub that sets `res$status <- 403L` and `stop("forbidden")` (mirroring `require_role`).

- [ ] **Step 1: Add a behavioral permission test for the review detail handler**

Append to `api/tests/testthat/test-endpoint-review.R`. This extracts the real handler, injects a `require_role` stub that denies, and asserts the handler stops with 403 before touching data — proving the gate is the first statement:

```r
test_that("GET /<review_id> behavioral: anonymous/insufficient role blocked with 403", {
  with_test_db_transaction({
    deny <- function(req, res, min_role) { res$status <- 403L; stop("forbidden") }
    env <- new.env(parent = globalenv())
    env$require_role <- deny
    env$pool <- structure(list(), class = "FAIL_IF_QUERIED")  # any DB touch would error
    handler <- extract_review_handler("^#\\*\\s+@get\\s+/<review_id_requested>\\s*$", env)
    res <- new.env(); res$status <- 200L
    expect_error(handler(req = list(), res = res, review_id_requested = "1"), "forbidden")
    expect_equal(res$status, 403L)
  })
})
```

- [ ] **Step 2: Add the analogous behavioral test for the status detail handler**

Append to `api/tests/testthat/test-endpoint-status.R` using its `extract_status_handler` helper (mirror the block above, decorator `"^#\\*\\s+@get\\s+/<status_id_requested>\\s*$"`, param `status_id_requested = "1"`).

- [ ] **Step 3: Run both files to verify PASS**

Run: `docker cp api/tests/testthat/test-endpoint-review.R sysndd-api-1:/app/tests/testthat/ && docker cp api/tests/testthat/test-endpoint-status.R sysndd-api-1:/app/tests/testthat/ && docker exec sysndd-api-1 Rscript -e "testthat::test_file('/app/tests/testthat/test-endpoint-review.R'); testthat::test_file('/app/tests/testthat/test-endpoint-status.R')"`
Expected: PASS. (If `extract_status_handler`/`make_status_sandbox` names differ, grep the status test file for the actual helper names and use those — do not invent new helpers.)

- [ ] **Step 4: Commit**

```bash
git add api/tests/testthat/test-endpoint-review.R api/tests/testthat/test-endpoint-status.R
git commit -m "test(security): behavioral 403 coverage for gated review/status GET routes (#535 P0-1)"
```

---

### Task 4: Live verification + full gate

**Files:** none (verification only)

- [ ] **Step 1: Confirm the file-size ratchet is green**

Run: `make code-quality-audit`
Expected: PASS.

- [ ] **Step 2: Live end-to-end check (fully-loaded API env — catches masking the unit sandbox can't)**

With the dev stack up (`make dev` or the running `sysndd-api-1` + Traefik), verify:
- Anonymous `GET /api/review/` and `GET /api/status/` → **403** problem+json.
- Anonymous `GET /api/review/1`, `/api/review/1/phenotypes`, `GET /api/status/1` → **403**.
- With a Reviewer JWT (mint per the repo recipe: `config::get("sysndd_db")` secret + `auth_generate_token`), the same routes → **200** with data.
- `GET /api/status/_list` (no token) → **200** category vocabulary (unchanged).

```bash
# anonymous (expect 403)
curl -s -o /dev/null -w "%{http_code}\n" http://localhost/api/review/
curl -s -o /dev/null -w "%{http_code}\n" http://localhost/api/status/
curl -s -o /dev/null -w "%{http_code}\n" http://localhost/api/review/1/phenotypes
# public vocab (expect 200)
curl -s -o /dev/null -w "%{http_code}\n" http://localhost/api/status/_list
# reviewer token (expect 200)
curl -s -o /dev/null -w "%{http_code}\n" -H "Authorization: Bearer $REVIEWER_JWT" http://localhost/api/review/
```

- [ ] **Step 3: Run the fast API PR gate**

Run: `make test-api-fast`
Expected: PASS; the two endpoint test files' inverted/new blocks run (not skipped) against the dev DB.

- [ ] **Step 4: Update docs if needed**

If the OpenAPI decorators encode `@response`, ensure the gated routes document `@response 403`. No behavior doc change beyond that; the public data surface is unchanged.

## Self-Review

- **Spec coverage:** S0 §4 requirements — public routes no longer expose drafts (gated at Reviewer+), draft detail/subresource routes gated, anonymous cannot enumerate IDs/comments/identities (403), tests inverted + anonymous-denial added, `_list` verified. Covered by Tasks 1–4.
- **Escalation gate (spec §4):** verified in this session — no anonymous/OpenAPI/MCP/SEO consumer of these lists; only authenticated approval queues consume them via `apiClient`. So "gate at Reviewer+" applies; no split needed.
- **Placeholder scan:** none — all edits show exact code; the only conditional is the `_list` public-vs-gate decision, which Task 2 Step 1 resolves by inspection with an explicit fallback.
- **Type/name consistency:** `require_role(req, res, "Reviewer")` used verbatim throughout; detail signatures consistently `function(req, res, <id>_requested)`.
