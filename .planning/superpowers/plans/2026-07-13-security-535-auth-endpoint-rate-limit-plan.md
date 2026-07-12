# Auth Endpoint Rate Limiting (#550) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply a fail-closed, bounded, per-caller admission throttle to body-only signup, signin, and password-reset-request endpoints without duplicating the hardened S6 client-fingerprint logic.

**Architecture:** Extract the IP parsing, rightmost-XFF trusted-proxy walk, bounded sliding-window store, and fail-closed response translation from the clustering-specific file into a source-first generic limiter module. Keep thin, named clustering and authentication adapters with independent stores/configuration but the same generic primitive. Each protected endpoint calls the authentication adapter before JSON parsing, database authentication, user collection, or email work.

**Tech Stack:** R, Plumber, testthat, Docker Compose / Traefik request headers.

---

### Task 1: Lock the generic security contract with deterministic tests

**Files:**
- Create: `api/tests/testthat/test-unit-per-caller-throttle.R`
- Create: `api/tests/testthat/test-endpoint-auth-rate-limit.R`
- Test: `api/tests/testthat/test-unit-clustering-submit-throttle.R`

- [x] **Step 1: Write a failing generic-limiter test**

  Source the future `functions/per-caller-throttle.R` and assert a test store admits `N` calls for a valid rightmost-XFF fingerprint, rejects call `N+1`, produces a positive integer retry value, leaves a distinct rightmost-XFF fingerprint admitted, retains the existing spoofed-leftmost behavior, and routes a rotation flood through the bounded overflow bucket.

- [x] **Step 2: Run the new test to verify it fails**

  Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-per-caller-throttle.R')"`

  Expected: FAIL because `functions/per-caller-throttle.R` does not exist.

- [x] **Step 3: Write failing protected-handler tests**

  Extract the three Plumber handlers into sandbox environments with a fake `auth_endpoint_admission_guard`. Assert that their `N+1` path returns the adapter's 429 body/status/header before `auth_signin`, database insert/email, or password-reset service can run; assert each route remains `POST`, reads request body fields (not query arguments), and does not include password/email values in the throttled response.

- [x] **Step 4: Run protected-handler tests to verify they fail**

  Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-endpoint-auth-rate-limit.R')"`

  Expected: FAIL because the handlers do not call `auth_endpoint_admission_guard`.

### Task 2: Extract the shared limiter and preserve S6 behavior

**Files:**
- Create: `api/functions/per-caller-throttle.R`
- Modify: `api/functions/clustering-submit-throttle.R`
- Modify: `api/bootstrap/load_modules.R`
- Test: `api/tests/testthat/test-unit-per-caller-throttle.R`
- Test: `api/tests/testthat/test-unit-clustering-submit-throttle.R`

- [x] **Step 1: Implement `per-caller-throttle.R`**

  Move the exact safe primitives into a generic module: integer env parsing, IPv4/IPv6 canonicalisation and trusted-CIDR matching, `per_caller_throttle_fingerprint(req, trusted_cidrs)`, bounded sliding-window rate limiting against an injected environment, and a parameterized admission guard. The fingerprint must walk the validated XFF chain right-to-left, skip only explicitly configured trusted proxy CIDRs, and select the first untrusted hop; it must never use a leftmost or arbitrary header token. Use `base::exists` and `base::get` for every environment lookup. Invalid rate-limit inputs and malformed limiter decisions must produce a 503 failure response instead of admitting the request.

- [x] **Step 2: Convert the clustering file to an adapter**

  Retain the public S6 names (`async_job_submit_fingerprint`, `async_job_submit_rate_limit`, `async_job_submit_admission_guard`, reset helper and current environment variables) as wrappers around the generic module. Preserve the existing response shape/error codes and independent clustering store so #547 behavior does not change.

- [x] **Step 3: Source the generic module first**

  Add `functions/per-caller-throttle.R` immediately before `functions/clustering-submit-throttle.R` in `bootstrap_load_modules()` so API and durable-worker source order is explicit and safe.

- [x] **Step 4: Run generic and S6 tests to verify GREEN**

  Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-unit-per-caller-throttle.R'); testthat::test_file('tests/testthat/test-unit-clustering-submit-throttle.R')"`

  Expected: both files report zero failures and zero unexpected skips.

### Task 3: Add an auth-specific adapter and gate the three routes

**Files:**
- Create: `api/functions/auth-endpoint-throttle.R`
- Modify: `api/bootstrap/load_modules.R`
- Modify: `api/endpoints/authentication_endpoints.R`
- Modify: `api/endpoints/user_endpoints.R`
- Test: `api/tests/testthat/test-endpoint-auth-rate-limit.R`

- [x] **Step 1: Implement the auth adapter with safe defaults**

  Define `AUTH_ENDPOINT_PER_CALLER_MAX`, `AUTH_ENDPOINT_WINDOW_SECONDS`, `AUTH_ENDPOINT_MAX_TRACKED`, and `AUTH_ENDPOINT_TRUSTED_PROXY_CIDRS` using the generic safe integer parser. Preserve S6's direct-Traefik default of an empty trusted-CIDR set (the appended rightmost hop is selected); operators must configure only a real upstream proxy CIDR, never an untrusted client range. Keep an auth-only history environment and expose `auth_endpoint_admission_guard(req, res)`, returning `429 RATE_LIMITED` with a positive `Retry-After` for excess calls and `503 THROTTLE_UNAVAILABLE` on internal failure. Do not parse request bodies or log user-controlled body/query values.

- [x] **Step 2: Gate endpoints before expensive work**

  At the first executable line of `POST /api/auth/signup`, `POST /api/auth/authenticate`, and `POST /api/user/password/reset/request`, call the adapter and immediately return its response when denied. Leave all inputs body-only and do not add a new router/mount.

- [x] **Step 3: Run handler tests to verify GREEN**

  Run: `cd api && Rscript -e "testthat::test_file('tests/testthat/test-endpoint-auth-rate-limit.R')"`

  Expected: the routes allow `N`, return 429 plus `Retry-After` on `N+1`, retain independent callers, and do not invoke the expensive sandbox functions after a denial.

### Task 4: Review, verify, and live-prove the protection

**Files:**
- Create: `.planning/reviews/2026-07-13-security-535-auth-endpoint-rate-limit-plan-codex-review.md`
- Create: `.planning/reviews/2026-07-13-security-535-auth-endpoint-rate-limit-diff-codex-review.md`
- Modify: `.env.example`
- Modify: `documentation/09-deployment.qmd`

- [x] **Step 1: Run xhigh adversarial plan review and fold valid issues before production code**

  Run the exact background `codex exec -s read-only -c approval_policy=never -c model_reasoning_effort=xhigh --skip-git-repo-check < prompt.md > out.txt 2>&1` command. Review public auth siblings, response/header safety, XFF aliases, bounded state, failure mode, and body/query disclosure. Update this plan with every valid finding before Task 2.

- [x] **Step 2: Document deploy configuration**

  Add bounded auth-rate environment variables and the trusted-proxy configuration/risk to `.env.example` and deployment documentation. State that no kill switch exists and configuration errors fall back safely or fail closed at admission.

- [x] **Step 3: Run xhigh adversarial diff review and fold findings with tests first**

  Review at least the full public authentication endpoint set and the S6 limiter siblings. Address every BLOCKER/HIGH and cheap MED/LOW with a RED-to-GREEN test. Re-run until no BLOCKER/HIGH remain; record all rounds and the final verdict in the committed diff review.

- [x] **Step 4: Run required gates and live verification**

  Run: `git diff --check`, `make code-quality-audit`, `make lint-api`, targeted tests including `test-unit-base-exists-get-guard.R`, and `make test-api-fast`. After an API restart, send validly formed body-only signin attempts with a placeholder invalid password from the same test client through Traefik until `N+1` yields `429` and `Retry-After`; verify a second client receives a non-429 response. Do not print any request body or credential.

- [x] **Step 5: Commit, push, and open the child-only PR**

  Check `git status -sb` immediately before commit. Commit only #550 files, push `fix/535-auth-endpoint-rate-limit`, and create one PR titled `DO-NOT-AUTO-MERGE: Rate-limit public auth endpoints` with separate body lines `Closes #550` and `Refs #535`.
