# Security & Reliability Hardening (#535) — Program + P0 Slice Design

Date: 2026-07-11
Issue: [#535](https://github.com/berntpopp/sysndd/issues/535) — umbrella remediation of the 2026-07-11 deep repository audit (independently validated by Claude Opus 4.8 at `xhigh`).
Status: **Design — awaiting review**

## 1. What this is

Issue #535 is an umbrella issue collecting ~25 distinct findings across authorization, secrets,
restore safety, deployment hardening, resource use, frontend correctness, and maintainability.
It is far too large for a single spec/plan/PR. The issue itself says *"Security-critical work must
land first; lower-priority work may be split into linked child issues."*

This document does two things:

1. **Decomposes** the umbrella into sequenced, independently-shippable child slices (§3).
2. **Fully specs the P0 security slice** — the two authorization findings the audit ranks as
   *"fix immediately"* — which is what we implement first (§4–§7).

The remaining slices are scoped here at roadmap granularity and each gets its own spec → plan → PR
cycle. Several of them (restore redesign, production credential rotation, Docker-socket topology
change) touch production secrets and deployment topology that cannot be safely validated from the
dev checkout; those are explicitly **human-gated** and are *not* auto-executed (§8).

## 2. Verified findings (deep review)

Both P0 findings were re-verified against current `master` (HEAD `8cc39642`) during this review:

- **P0-1 confirmed.** `api/core/middleware.R:93-97` forwards *every* unauthenticated `GET`. The
  review list handler defaults `filter_review_approved = FALSE`, filters *for* unapproved rows
  (`review_endpoints.R:34-36,100-103`), and returns `synopsis`, reviewer/approver `user_name` +
  `user_role`, and `comment` to anonymous callers (`:104-124`). The status list is identical
  (`status_endpoints.R:27-28,87-113`). The enumerable detail/subresource routes
  (`review_endpoints.R:385,439,481,523`; `status_endpoints.R:168`) query raw tables with no
  approval gate. Two tests **actively assert the absence of a role gate**
  (`test-endpoint-review.R:200-214`, `test-endpoint-status.R:156-166`).

- **P0-2 confirmed.** `auth_refresh()` decodes the presented token and reissues claims verbatim with
  **no DB lookup** (`auth-service.R:140-164`). `auth_generate_token()` returns the **same JWT** as
  both `access_token` and `refresh_token` (`:194-198`), and `/api/auth/refresh` is allowlisted
  (`middleware.R:32`). A demoted or deactivated user refreshes stale privileges indefinitely until
  the (short) `exp`, and can keep doing so forever because the refresh token never expires
  differently from the access token and carries no revocation state.

**Prior work does not cover P0.** A previous security effort (#520/#521, v0.29.2/v0.29.3, spec
`2026-07-06-security-bug-scan-fixes-design.md`) fixed a related "#3 exposure class": it gated the
phenotype/variant **connect views** on `review_approved = 1` (migration
`042_gate_connect_views_review_approved.sql`) and hardened the entity endpoints + SEO service.
That work did **not** touch the `/api/review` or `/api/status` **endpoint handlers**, nor the
refresh flow. This audit (post-#521) and a fresh re-read of current `master` confirm both P0
findings remain open. There are currently **no open PRs or branches** targeting #535.

**Frontend consumption (load-bearing for the P0-1 design):** the `/api/review` and `/api/status`
**list** endpoints have *no* current frontend consumer (`listReviews`/`listStatus` are unused
outside `api/review.ts`/`api/status.ts`). The detail/subresource routes are consumed only by
**authenticated curation/review** composables — `useReviewForm.ts`, `useReviewData.ts`,
`useStatusForm.ts`. Public approved curation data reaches the browser through the already
approved-gated `/api/entity/*` family (e.g. `GET /api/entity/<id>/review`, a *different* endpoint).
This means these two endpoint families are **curation surfaces**, and gating them behind Reviewer+
does not break any known public page.

## 3. Program decomposition (sequenced slices)

Ordering follows the audit's own "Recommended remediation order". Dependencies noted.

| Slice | Findings | Surface | Risk | Autonomy |
|-------|----------|---------|------|----------|
| **S0 — Endpoint authorization** (this spec) | P0-1 | `api/endpoints`, tests | Low, api-only, in-repo testable | **Implement now** |
| **S1 — Revocable role-current refresh** (this spec) | P0-2 | `api/services`, migration, `middleware`, frontend auth store | Medium — auth flow + DB + FE | **Implement now** |
| S2 — Secrets out of jobs/argv | P1-1 | backup service, async-job service, `backup-functions` | Medium — touches prod cred handling | Spec + plan; **human-gated execution** (credential rotation is operator work) |
| S3 — Restore fencing redesign | P1-2 | restore plane, Compose, ops runbook | High — production topology | Spec only; **human-gated** |
| S4 — Deployment hardening | P1-3/4/5/6 | Compose, Vite, nginx, Dockerfile, Makefile | Medium — infra/build | Spec + plan; deploy-topology items **human-gated** |
| S5 — Frontend request ownership | P1-7, P2-3 | `tableRequestCoordinator`, 4 composables | Low-Med — FE only, unit-testable | Spec + plan; implementable after S0/S1 |
| S6 — Clustering admission controls | P2-1 | job submission services | Medium | Spec + plan |
| S7 — Perf & retention | P2-2/4/5/6 | composables barrel, external-proxy cache, backup I/O, job retention | Medium | Spec + plan |
| S8 — Defense-in-depth & maintainability | P2-7/8, P3, misc | MCP DB principal, throttling, CSPRNG, HTML-escape, dead code, CI gating | Low-Med, several independent | Spec + plan; several are quick wins |

Cheap, low-risk, clearly-correct wins that can be pulled forward opportunistically (each < ~1 PR):
dead backup `executor_fn` removal, HTML-escape signup fields, CSPRNG temp passwords, Makefile
`pipefail` on restore targets, source-map/`stats.html` suppression. These are noted in S4/S8 but
carry no infra decision, so they are safe to batch when convenient.

**This session implements S0 and S1** (the P0 slice) as two separate PRs, opened for human sign-off
(no auto-merge of security-critical auth changes). Everything else is left as sequenced roadmap.

## 4. S0 — Endpoint authorization (P0-1)

### Goal
No anonymous caller can read draft/unapproved curation rows, curator identities, roles, comments,
or workflow state through `/api/review` or `/api/status`. Approved-public data continues to reach
the public through its existing approved-gated paths.

### Strategy: gate the curation families behind Reviewer+
Because these two families are curation surfaces with no public consumer, the correct and safest
fix is to require **Reviewer+** on every route that can expose draft rows or curator metadata,
using the established `require_role(req, res, "Reviewer")` pattern already used across
`api/endpoints/*`. This is strictly safer than building parallel "public approved-only" routes and
introduces no new column-stripping logic that could regress.

Routes to gate at **Reviewer+**:
- `GET /api/review/` (list), `GET /api/review/<id>`, `.../phenotypes`, `.../variation`, `.../publications`
- `GET /api/status/` (list), `GET /api/status/<id>`
- Write/approve routes (`/create`, `/update`, `/approve/<id>`) — verify they already gate at
  Curator/Reviewer; add the guard if any is missing (the audit did not flag them, but the plan must
  confirm rather than assume).

Routes that may stay public (verify in plan):
- `GET /api/status/_list` returns only the status *category* vocabulary
  (`ndd_entity_status_categories_list`), no curation rows or identities. Keep public **only if**
  the plan confirms it exposes no draft/identity data; it is consumed by public entity-create option
  loaders.

### Escalation gate (plan must execute, not assume)
Before finalizing, the plan **must** verify no public/OpenAPI-documented/MCP consumer depends on an
anonymous approved-only list from these two families (grep frontend, check `openapi.json` tags, check
the MCP repository queries, check the sitemap/prerender). If such a consumer exists, that specific
route is instead handled by the **split strategy**: hard-code the approved predicate
(`review_approved == TRUE` / `status_approved == TRUE`) **and** drop the curator-identity/comment/
workflow columns for anonymous callers, keeping full behavior for Reviewer+. Default remains
"gate at Reviewer+"; split is the fallback only where a real public consumer is found.

### Tests
- **Invert** `test-endpoint-review.R:200-214` and `test-endpoint-status.R:156-166`: assert the list
  handlers now contain `require_role(`.
- **Add anonymous-access denial tests**: anonymous `GET /api/review/`, `/api/review/<id>`,
  subresources, `/api/status/`, `/api/status/<id>` return 401/403 and **no** draft row / curator
  identity in the body. A Reviewer token gets the data (positive control).
- Keep the existing write-path/approval tests green.

### Out of scope for S0
The audit's secondary note that review detail routes "collect whole tables before filtering"
(`review_endpoints.R:446-455,488-497,530-539`) is a **performance** cleanup, not part of the
authorization fix. It is folded into S7, not S0, to keep the security PR minimal and reviewable.

## 5. S1 — Revocable, role-current token refresh (P0-2)

### Goal
A refresh operation reflects the **current** account state: a deactivated or demoted user cannot
mint fresh privileges, refresh tokens are distinct from access tokens, rotate on use, and can be
revoked.

### Design
1. **Distinct tokens.** `auth_generate_token()` mints two different JWTs:
   - *access token*: short `exp` (`config$token_expiry`, default 3600s), `typ="access"`, carries the
     role claims as today.
   - *refresh token*: longer `exp` (new `config$refresh_token_expiry`, default e.g. 30 days),
     `typ="refresh"`, carries `user_id` + a server-generated **`jti`** and **nothing role-bearing**
     that a stale copy could trust.
2. **Server-side revocation store.** New migration `db/migrations/043_add_refresh_tokens.sql` (next
   after the current latest `042_gate_connect_views_review_approved.sql`; bump
   `EXPECTED_LATEST_MIGRATION` + the two manifest guard tests) adds a
   `refresh_token` table: `jti` (PK, indexed), `user_id`, `issued_at`, `expires_at`, `revoked_at`
   (nullable), `rotated_to_jti` (nullable, for reuse detection), `user_agent`/`ip` optional. On
   sign-in, insert the issued `jti`.
3. **Refresh flow (`auth_refresh`)** now:
   - Decode + signature-verify the refresh JWT; require `typ="refresh"`.
   - Look up its `jti` in `refresh_token`. Reject if missing, `revoked_at` set, or expired.
   - **Reuse detection:** if the `jti` was already rotated (`rotated_to_jti` set), treat as replay —
     revoke the whole chain for that user and reject.
   - **Load current user by `user_id` from the DB.** Require `approved == 1` (active). Mint the new
     access token's role **from the DB row**, not the token.
   - **Rotate:** mark the old `jti` `revoked_at`/`rotated_to_jti`, issue a new refresh `jti`, return
     new access + new refresh token.
4. **Revoke on account change.** When a user is demoted, deactivated, or deleted (admin user
   endpoints), revoke all their outstanding refresh `jti`s. Deactivation/demotion then prevents any
   further refresh immediately.
5. **Frontend coordination.** The auth store must store and send the refresh token to
   `/api/auth/refresh`, accept the rotated refresh token in the response, and replace it. Today the
   endpoint returns only a string access token; the response shape becomes
   `{ access_token, refresh_token, token_type, expires_in }`. Keep a transitional path so an
   in-flight legacy session degrades gracefully (forces re-login rather than 500).

### Tests
- Refresh after **demotion** → new access token carries the *new* (lower) role.
- Refresh after **deactivation** → rejected.
- **Replay:** using a rotated (old) refresh token → rejected and chain revoked.
- **Rotation:** each refresh returns a new refresh `jti`; old one no longer works.
- **Expiry:** expired refresh token rejected; expired access token still refreshable within refresh
  window.
- **Distinctness:** access token ≠ refresh token; access token cannot be used at `/refresh` (`typ`
  mismatch) and refresh token cannot authenticate a normal protected route.

### Migration & compatibility
- The migration is additive (new table); `EXPECTED_LATEST_MIGRATION` and the manifest count update
  per the migrations skill. No change to existing tables.
- Existing access tokens keep working until they expire (they still decode). Only the refresh
  contract changes. Frontend and API ship together (S1 is one PR spanning both), so the response
  shape change is coordinated.

## 6. Architecture & isolation

- S0 and S1 are **independent code areas** (endpoint authz vs auth token service + migration + FE)
  with minimal overlap (both could touch `middleware.R`, but S0 does not need to). They are
  implemented in **separate git worktrees / branches** by parallel agents and become **two PRs**.
- Each unit stays testable in isolation: S0 via the R endpoint test suite; S1 via auth-service unit
  tests + a migration + frontend auth-store unit tests.
- Neither PR is auto-merged: both are security-critical and get Codex adversarial review of the diff
  plus human sign-off.

## 7. Verification (both slices)

- `make code-quality-audit` (file-size ratchet) — both PRs must keep touched files < 600 lines.
- Targeted R tests in the running API container (tests dir is not bind-mounted): the inverted +
  new endpoint tests (S0), the auth-service refresh tests (S1).
- `cd app && npm run test:unit` for the S1 frontend auth-store changes.
- `make test-api-fast` as the PR gate; `make ci-local` before handoff where scope warrants.
- Live end-to-end sanity where feasible (mint a Reviewer JWT, hit the gated routes; exercise the
  refresh flow) — the audit repeatedly notes that masking effects only surface in the fully-loaded
  API env, so prefer a live check over unit tests alone.

## 8. Explicitly deferred / human-gated (not auto-executed this session)

These are specced at roadmap level (§3) and left for their own cycles because they involve
production secrets or deployment topology that must not be changed autonomously from a dev checkout:

- **S2 credential rotation** — the code change (resolve secrets from mounted config, mode-0600
  defaults file, scrub payload rows) is implementable, but *rotating the live DB credential* is
  operator work and must be human-driven.
- **S3 restore fencing redesign** — changes production maintenance topology; design only.
- **S4 Docker-socket proxy + removing writable prod mounts** — production Compose topology; the
  build-side items (source maps, `stats.html`, nginx denies) are safe and can be pulled forward.

## 9. Non-goals

- No refactor beyond what each fix requires (YAGNI). Performance cleanups adjacent to the P0 code
  (whole-table collects in review detail) are deferred to S7.
- No change to the public entity/gene data surface, which the audit confirms is already
  approved-gated.
