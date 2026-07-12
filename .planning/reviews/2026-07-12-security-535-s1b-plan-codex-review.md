# S1b plan — Codex adversarial review (gpt-5.6-sol, xhigh) — Verdict: FIX-FIRST (NOT implementation-ready)

This deep plan review found **4 BLOCKERs + 7 HIGHs** — precisely the subtle auth landmines that make
S1b unsafe to implement autonomously. S1b therefore ships as a **design + plan + this review** (a
docs/design PR); the plan must be revised to resolve these before ANY code lands.

## BLOCKER
1. **Reuse response is rolled back.** Prod `auth_refresh` runs in `dbWithTransaction`; raising 401
   inside it rolls back the `revoked_at`/`session_epoch` writes. Return a `reuse_detected` outcome,
   COMMIT it, then raise 401 outside the transaction. Test that the 401 leaves revocation committed.
2. **SPA never receives the initial refresh token.** `/authenticate` returns only `access_token` (a
   string); `authenticate()`/`LoginView` expect a scalar. Define the login wire contract and make
   user-read + refresh-row insert atomic before implementing. The pair helper needs a `conn`/txn that
   `auth_signin` does not currently have.
3. **Token-type isolation is one-way.** Refresh rejects access tokens, but middleware/`auth_verify`
   don't require `typ="access"`, so a refresh token is a valid Bearer on ungated endpoints. Add
   fail-closed expected-typ validation to EVERY consumer. Password-reset JWTs share the key and have
   no `typ` — give them `typ="password_reset"`, validate only on that route.
4. **Rollout claim is false.** "Land together" can't update already-loaded JS; a hard POST cut / GET
   410 logs out in-flight SPAs, and an object-returning `/authenticate` breaks their re-login. Use a
   phased/versioned contract (backend supports legacy scalar+GET AND new pair+POST; deploy SPA;
   retain compatibility for the access-token window; then remove legacy).

## HIGH (summary)
- Concurrent legitimate refresh (multi-tab/double-click/retry/lost-response) trips reuse → logs out
  all sessions; need single-flight + a documented grace/retry policy vs strict logout.
- Lock ordering (token-then-user, bulk-lock all tokens) can deadlock; classify epoch BEFORE reuse;
  treat stale-epoch tokens as already-revoked unless account-wide IR is intended.
- "Revoke chain" = revoke EVERY session (no family id); add `family_id`/parent linkage OR make
  account-wide-compromise explicit.
- The shipped S1 regression fixture mints `auth_generate_token(...)$access_token` and presents it to
  refresh — the new typ gate rejects it and it has no refresh row; update the FIXTURE only, keep the
  legacy/epoch/DB-role assertions; add commit-after-reuse + concurrency tests.
- Logout does no server revocation — add a credential-body POST logout that revokes the family.

## MEDIUM/LOW
- 044 underspecified (reassert columns/indexes; `expires_at` index; `(user_id, revoked_at)` or
  `(family_id, revoked_at)`; UUID `BINARY(16)`/`ascii_bin`). Migration count is 42 — update
  `test-unit-analysis-snapshot-migration.R:8` + `test-unit-core-views-manifest.R:12,21`.
- Epoch bump does NOT kill existing access tokens (stateless, ~1h) — correct the threat-model wording.
- refresh_token table growth needs expiry cleanup (tie to S7) + `expires_at` index + user-delete
  cleanup.
- Frontend: specify access/refresh/user all-or-none, Plumber scalar-array normalization, atomic
  replacement, refresh single-flight, LoginView/MSW/OpenAPI-drift/interceptor updates.
- refresh token in `localStorage` is XSS-readable — prefer HttpOnly/SameSite cookie or record the
  accepted residual.

## Confirmed correct
`FOR UPDATE` prevents double-rotation; preserving approval/epoch/DB-claims under the user lock keeps
S1's invariant once the txn defects are fixed; POST-body refresh honors auth-body-only + stays
allowlisted; minimal-claims refresh + server `jti` + stateless short access is the right split;
checking both JWT + row expiry is right; password/role/approval/deactivation epoch bumps already
invalidate refresh.
