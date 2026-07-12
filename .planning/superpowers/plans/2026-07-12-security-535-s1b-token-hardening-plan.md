# S1b — Distinct/Revocable/Rotating Tokens — Plan (implementation-ready; human-gated)

> REQUIRED SUB-SKILL: superpowers:test-driven-development. Design:
> `.../specs/2026-07-12-security-535-s1b-token-hardening-design.md`.
> **Risk: HIGH — auth flow + migration + SPA token model. The live regression gate (Task 6) is
> mandatory before merge; do not ship without it. All-or-nothing: the backend POST change and the
> frontend two-token change land together (or behind a transitional shim) so an in-flight SPA never
> breaks.**

## Non-regression gate (run at start AND end — must stay green)
The shipped S1 behavior (PR #538) is the invariant: legacy no-`sepoch` token → 401; epoch-bump →
401; valid → 200 with DB-derived (role-current) claims, minted under `SELECT … FOR UPDATE`. Reuse
`test-unit-auth-refresh-epoch.R` as the regression suite; every S1b change keeps it green.

## Task 1 — Migration 044 + manifest (RED: guard tests)
- [ ] `db/migrations/044_add_refresh_tokens.sql`: `refresh_token(jti CHAR(36) PK, user_id INT NOT
  NULL, issued_at DATETIME, expires_at DATETIME, used_at DATETIME NULL, replaced_by CHAR(36) NULL,
  revoked_at DATETIME NULL, session_epoch INT NOT NULL, KEY(user_id))`. Idempotent (information_schema
  guard, `CREATE TABLE IF NOT EXISTS`), restore-drift safe (match 043's style).
- [ ] Bump `EXPECTED_LATEST_MIGRATION` (`migration-manifest.R:5`) → `044_add_refresh_tokens.sql`; bump
  the min-count; update guard tests `test-unit-analysis-snapshot-migration.R:8` and
  `test-unit-core-views-manifest.R` (count). RED → GREEN.

## Task 2 — Distinct token minting (auth-service.R)
- [ ] `auth_generate_token()` gains `typ = "access"` and keeps the full claims + `sepoch` + access
  `exp` (`config$token_expiry`). Add `config$refresh_expiry` (default 30d).
- [ ] New `auth_issue_token_pair(user, config, conn)`: mints the access token AND a refresh token
  (`typ="refresh"`, minimal claims `user_id`+`sepoch`+`jti`, `exp = refresh_expiry`) and INSERTs the
  refresh row (`jti`, `user_id`, `issued_at`, `expires_at`, `session_epoch`) via `conn`. `auth_signin`
  returns the pair (its shape already has both fields) inside its existing flow.
- Tests: access & refresh are distinct, carry `typ`, have different `exp`; a refresh row is inserted.

## Task 3 — Rotation + reuse detection (auth_refresh)
- [ ] Inside the existing `FOR UPDATE` transaction: require `typ=="refresh"` (reject an access token);
  keep the legacy `sepoch`-missing reject and the `user_id` validation. `SELECT … FROM refresh_token
  WHERE jti=? FOR UPDATE`:
  - not found / expired / `revoked_at` set → reject;
  - `used_at` set (already rotated) → **REUSE**: `UPDATE refresh_token SET revoked_at=NOW() WHERE
    user_id=? AND revoked_at IS NULL` **and** bump `user.session_epoch` (kill outstanding access) →
    reject with re-login error;
  - else read `user FOR UPDATE` (S1 checks: `approved=1`, `token.sepoch==user.session_epoch`), then
    **rotate**: mint a new pair from the DB row, `UPDATE refresh_token SET used_at=NOW(),
    replaced_by=<new jti> WHERE jti=<old>`, INSERT the new row. Return **both** new tokens.
- Tests: valid rotation (old used_at set, new jti, both tokens, role from DB); reuse → chain revoked +
  epoch bumped + reject; unknown/expired/revoked jti → reject; access-token-as-refresh → reject.
- **Regression:** the Task-0 epoch/legacy tests stay green.

## Task 4 — POST /api/auth/refresh (endpoint + middleware)
- [ ] Change the route to `@post` reading JSON body `{ refresh_token }` (auth-body-only rule);
  response `{ access_token, refresh_token, token_type, expires_in }`. Keep it in `AUTH_ALLOWLIST`.
  (Decision: keep a transitional GET returning 410, or hard-cut — human call, default hard-cut with
  the frontend updated in the same PR.)

## Task 5 — Frontend two-token + POST (auth.ts + store)
- [ ] `app/src/api/auth.ts:108`: `refresh()` → `apiClient.post('/api/auth/refresh', { refresh_token })`
  reading the stored refresh token; return the new pair. Typed client only.
- [ ] Auth store stores BOTH tokens (no raw `localStorage` writes in views); interceptor sends the
  **access** token; `refresh()` replaces both on success; any refresh failure → logout.
- Tests: `auth.ts` posts the body + stores both; store round-trips two tokens.

## Task 6 — VERIFY (mandatory live regression, per umbrella §7)
- [ ] In-container R (test DB): auth-service rotation/reuse/typ tests + migration guards +
  `test-unit-auth-refresh-epoch.R` (regression). `cd app && npm run type-check && test:unit`.
- [ ] **Live monkey (auth — masking only surfaces loaded):** restart `api`+`worker`+`worker-maintenance`;
  mint tokens with the dev-block secret; drive (a) POST refresh → new PAIR; (b) replay OLD refresh →
  chain revoked + epoch bumped + 401; (c) **S0-2 regression:** legacy token → 401, epoch-bump → 401,
  valid → 200 DB-derived. Browser login→refresh→still-authed.
- [ ] `make code-quality-audit`, `make lint-api`, `make lint-app`. Codex plan review AND diff review
  (xhigh). Fold → PR (do-not-auto-merge, security-critical).

## Human decisions (flag on the PR)
`refresh_expiry` default; keep-GET-shim vs hard-cut; whether reuse-detection's epoch bump (logs out
all sessions) is the desired UX; device/IP binding (out of scope).
