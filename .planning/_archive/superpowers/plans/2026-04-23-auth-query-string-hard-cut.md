# Auth Query-String Hard Cut Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the remaining auth/signup/password query-string transport and raw query-string logging in one hard-cut release, with regression tests and durable doc updates.

**Architecture:** The change is a coordinated transport cleanup across frontend, API, and logging. A short serial preflight verifies there are no remaining GET-auth callers, then three independent workstreams execute in parallel on disjoint files and converge at full verification.

**Tech Stack:** Vue 3, Axios, Vitest, MSW, R/Plumber, testthat, httr2, MySQL logging table, Make-based CI.

---

### Task 1: Preflight Usage Check And Lock The Hard-Cut Scope

**Files:**
- Modify: `.planning/superpowers/specs/2026-04-23-auth-query-string-hard-cut-design.md`
- Test: none

- [ ] **Step 1: Verify repo-local callers of insecure auth/query flows**

Run:
```bash
rg -n "api/auth/signup\\?signup_data|@get authenticate|req_url_query\\(signup_data|old_pass|new_pass_1|QUERY_STRING" app api documentation .planning
```

Expected:
- One live frontend signup call in `app/src/views/RegisterView.vue`
- legacy auth decorator in `api/endpoints/authentication_endpoints.R`
- legacy signup/password test usage in `api/tests/testthat/test-e2e-user-lifecycle.R`
- raw `QUERY_STRING` logging in `api/bootstrap/mount_endpoints.R`

- [ ] **Step 2: Record the hard-cut preflight outcome in the spec**

Add a short note to the spec confirming the grep result is the basis for the deletion. The note should say the repo-local insecure call surface is confined to registration, legacy endpoint decorators, tests, and request logging.

- [ ] **Step 3: If available, check one current operational log sample for live GET-auth callers**

Run one repo-appropriate inspection command if logs are locally available; otherwise record that only repo-local verification was possible.

Expected:
- no evidence of current live callers for `GET /api/auth/authenticate`
- or an explicit note that operational logs were not available in the workspace


### Task 2: Parallel Workstream A — Frontend Signup Hard Cut

**Ownership:** frontend registration transport and tests only

**Files:**
- Modify: `app/src/views/RegisterView.vue`
- Modify: `app/src/views/RegisterView.spec.ts`
- Modify: `app/src/test-utils/mocks/handlers.ts`
- Test: `app/src/views/RegisterView.spec.ts`

- [ ] **Step 1: Write the failing frontend test for POST body signup**

Update the registration spec to assert `POST /api/auth/signup` rather than `GET /api/auth/signup?signup_data=...`.

Key assertion shape:
```ts
server.use(
  http.post('/api/auth/signup', async ({ request }) => {
    const body = await request.json();
    capturedMethod = request.method;
    capturedAuthHeader = request.headers.get('authorization');
    capturedBody = body;
    return HttpResponse.json({ ok: true });
  })
);

expect(capturedMethod).toBe('POST');
expect(capturedAuthHeader).toBeFalsy();
expect(capturedBody).toMatchObject({
  user_name: 'new_user',
  email: 'new@sysndd.local',
  orcid: '0000-0000-0000-0000',
  first_name: 'New',
  family_name: 'User',
  comment: 'Motivation',
  terms_agreed: 'accepted',
});
```

- [ ] **Step 2: Run the frontend spec and confirm it fails for the old GET flow**

Run:
```bash
cd app && npx vitest run src/views/RegisterView.spec.ts
```

Expected:
- FAIL because the component still issues `GET /api/auth/signup?signup_data=...`

- [ ] **Step 3: Switch the component to body-only signup**

Update `sendRegistration()` in `app/src/views/RegisterView.vue` from query-string transport to JSON body transport.

Target code:
```js
const apiUrl = `${import.meta.env.VITE_API_URL}/api/auth/signup`;
await this.axios.post(apiUrl, {
  user_name: this.user_name,
  first_name: this.first_name,
  family_name: this.family_name,
  email: this.email,
  orcid: this.orcid,
  comment: this.comment,
  terms_agreed: this.terms_agreed,
});
```

- [ ] **Step 4: Update the MSW handler to match the new transport**

Change the mock handler to:
```ts
http.post('/api/auth/signup', async ({ request }) => {
  const body = await readJsonBody(request);
  if (
    typeof body.user_name !== 'string' ||
    typeof body.email !== 'string' ||
    typeof body.orcid !== 'string'
  ) {
    return HttpResponse.json({ message: 'invalid signup payload' }, { status: 400 });
  }
  return HttpResponse.json({ ok: true });
})
```

- [ ] **Step 5: Re-run the frontend registration spec**

Run:
```bash
cd app && npx vitest run src/views/RegisterView.spec.ts
```

Expected:
- PASS


### Task 3: Parallel Workstream B — API Auth And Password Hard Cut

**Ownership:** auth/password endpoint surface and auth lifecycle tests only

**Files:**
- Modify: `api/endpoints/authentication_endpoints.R`
- Modify: `api/endpoints/user_endpoints.R`
- Modify: `api/tests/testthat/test-endpoint-auth.R`
- Modify: `api/tests/testthat/test-e2e-user-lifecycle.R`
- Modify: `documentation/08-development.qmd`
- Test: `api/tests/testthat/test-endpoint-auth.R`
- Test: `api/tests/testthat/test-e2e-user-lifecycle.R`

- [ ] **Step 1: Write failing API endpoint assertions for the hard cut**

Update `test-endpoint-auth.R` so it asserts:
- `@post signup` exists
- `@get signup` does not exist
- `@post authenticate` exists
- `@get authenticate` does not exist
- signup and password-update reject non-JSON with `415`
- signup and password-update reject malformed or empty JSON with `400`

Representative checks:
```r
expect_false(any(grepl("^#\\*\\s+@get\\s+authenticate\\s*$", src)))
expect_true(any(grepl("^#\\*\\s+@post\\s+signup\\s*$", src)))
expect_match(handler_blob, "req\\$HTTP_CONTENT_TYPE")
expect_match(handler_blob, "res\\$status\\s*<-\\s*415")
expect_match(handler_blob, "res\\$status\\s*<-\\s*400")
```

- [ ] **Step 2: Run the auth endpoint test and confirm it fails against the transitional code**

Run:
```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-endpoint-auth.R')"
```

Expected:
- FAIL because the file still advertises legacy GET auth and signup is still query-string based

- [ ] **Step 3: Convert signup to JSON-body POST and remove GET authenticate**

Update `api/endpoints/authentication_endpoints.R` to:
- expose `#* @post signup`
- require `Content-Type: application/json`
- reject malformed/empty body with `400`
- remove `#* @get authenticate`

Target handler skeleton:
```r
#* @post signup
function(req, res) {
  if (!grepl("^application/json", req$HTTP_CONTENT_TYPE %||% "", ignore.case = TRUE)) {
    res$status <- 415
    res$body <- "Content-Type must be application/json."
    return(res)
  }

  if (is.null(req$postBody) || !nzchar(trimws(req$postBody))) {
    res$status <- 400
    res$body <- "Request body must be valid JSON."
    return(res)
  }

  body <- tryCatch(jsonlite::fromJSON(req$postBody), error = function(e) NULL)
  if (is.null(body)) {
    res$status <- 400
    res$body <- "Request body must be valid JSON."
    return(res)
  }

  user <- tibble::as_tibble(body) %>%
    mutate(terms_agreed = dplyr::if_else(terms_agreed == "accepted", "1", "0")) %>%
    dplyr::select(user_name, first_name, family_name, email, orcid, comment, terms_agreed)
  # existing validation and insert flow unchanged
}
```

- [ ] **Step 4: Make password update body-only with explicit content-type checks**

Update `api/endpoints/user_endpoints.R` password handler to:
- require `Content-Type: application/json`
- parse only `req$postBody`
- reject non-JSON with `415`
- reject malformed/empty JSON with `400`
- remove query-param fallback paths

- [ ] **Step 5: Update the lifecycle tests to body-only transport**

Replace `req_url_query(signup_data = signup_json)` with:
```r
httr2::req_headers(`Content-Type` = "application/json") |>
httr2::req_body_raw(signup_json, type = "application/json")
```

Replace password-change query params with:
```r
httr2::req_headers(`Content-Type` = "application/json") |>
httr2::req_body_json(list(
  user_id_pass_change = user_id,
  old_pass = old_password,
  new_pass_1 = new_password,
  new_pass_2 = new_password
), auto_unbox = TRUE)
```

- [ ] **Step 6: Update durable docs**

In `documentation/08-development.qmd`, replace any auth flow references that still imply query-param credentials with body-only `POST`/`PUT` transport.

- [ ] **Step 7: Re-run the targeted API auth tests**

Run:
```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-endpoint-auth.R')"
cd api && Rscript -e "testthat::test_file('tests/testthat/test-e2e-user-lifecycle.R')"
```

Expected:
- PASS


### Task 4: Parallel Workstream C — Logging Hard Cut And DB Scrub

**Ownership:** request logging hook, DB scrub migration, and logging regression tests only

**Files:**
- Modify: `api/bootstrap/mount_endpoints.R`
- Add: `db/migrations/019_redact_logged_query_strings.sql`
- Modify: `api/tests/testthat/test-unit-logging-functions.R`
- Modify: `documentation/08-development.qmd`
- Test: `api/tests/testthat/test-unit-logging-functions.R`
- Test: `api/tests/testthat/test-unit-migration-runner.R`

- [ ] **Step 1: Write the failing regression test for query redaction semantics**

Add a unit-level assertion that the logging pipeline treats query strings as fixed redacted text, not raw values.

Representative expectation:
```r
expect_equal(convert_empty("[redacted]"), "[redacted]")
```

And add a text-level assertion against `mount_endpoints.R`:
```r
src <- readLines(file.path(api_dir, "bootstrap", "mount_endpoints.R"), warn = FALSE)
expect_true(any(grepl("\\[redacted\\]", src)))
expect_false(any(grepl("convert_empty\\(req\\$QUERY_STRING\\)", src)))
```

- [ ] **Step 2: Run the logging test and confirm it fails before the change**

Run:
```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-logging-functions.R')"
```

Expected:
- FAIL because `mount_endpoints.R` still persists raw `req$QUERY_STRING`

- [ ] **Step 3: Redact query logging in the postroute hook**

Update `api/bootstrap/mount_endpoints.R` so both the app log entry and DB log writer use a fixed placeholder:
```r
redacted_query <- "[redacted]"

log_entry <- paste(
  convert_empty(req$REMOTE_ADDR),
  convert_empty(req$HTTP_USER_AGENT),
  convert_empty(req$HTTP_HOST),
  convert_empty(req$REQUEST_METHOD),
  convert_empty(req$PATH_INFO),
  redacted_query,
  safe_post_body,
  convert_empty(res$status),
  round(end$toc - end$tic, digits = getOption("digits", 5)),
  sep = ";",
  collapse = ""
)

log_message_to_db(
  address = convert_empty(req$REMOTE_ADDR),
  agent = convert_empty(req$HTTP_USER_AGENT),
  host = convert_empty(req$HTTP_HOST),
  request_method = convert_empty(req$REQUEST_METHOD),
  path = convert_empty(req$PATH_INFO),
  query = redacted_query,
  post = safe_post_body,
  status = convert_empty(res$status),
  duration = round(end$toc - end$tic, digits = getOption("digits", 5)),
  file = logging_temp_file,
  modified = Sys.time()
)
```

- [ ] **Step 4: Add the one-shot DB scrub migration**

Create `db/migrations/019_redact_logged_query_strings.sql`:
```sql
UPDATE logging
SET query = '[redacted]'
WHERE query IS NOT NULL
  AND query <> ''
  AND query <> '-'
  AND query <> '[redacted]';
```

- [ ] **Step 5: Re-run the targeted logging and migration-runner tests**

Run:
```bash
cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-logging-functions.R')"
cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-migration-runner.R')"
```

Expected:
- PASS


### Task 5: Integrate, Verify, And Close Out

**Files:**
- Modify: `AGENTS.md`
- Modify: `.planning/superpowers/specs/2026-04-23-auth-query-string-hard-cut-design.md`
- Test: full verification gate

- [ ] **Step 1: Update durable agent-facing guidance**

Remove any remaining references to legacy GET auth flows from `AGENTS.md` if present, or add a short note that auth/signup/password-sensitive inputs are body-only and must not be logged via raw query strings.

- [ ] **Step 2: Re-read the spec and confirm all scoped items landed**

Checklist:
- signup is body-only
- GET authenticate is removed
- password update is body-only
- query logging is fixed to `[redacted]`
- DB scrub migration exists
- docs updated

- [ ] **Step 3: Run the shortest safe verification batch**

Run:
```bash
make lint-api
cd api && Rscript -e "testthat::test_file('tests/testthat/test-endpoint-auth.R')"
cd api && Rscript -e "testthat::test_file('tests/testthat/test-e2e-user-lifecycle.R')"
cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-logging-functions.R')"
cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-migration-runner.R')"
cd app && npx vitest run src/views/RegisterView.spec.ts
```

Expected:
- all commands exit `0`

- [ ] **Step 4: Run the full repo handoff gate**

Run:
```bash
make ci-local
```

Expected:
- exit `0`

- [ ] **Step 5: Record residual risk explicitly**

Document only this remaining limitation if still true:
- historical file logs may still contain pre-change raw query strings if no existing safe scrub path was available in this change
