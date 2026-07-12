# S1b — Distinct, Revocable, Rotating Access/Refresh Tokens — Design

Date: 2026-07-12
Issue: [#535](https://github.com/berntpopp/sysndd/issues/535) — umbrella hardening, slice **S1b**
(the deferred defense-in-depth follow-up to the shipped S1 session-epoch refresh, PR #538).
Parent design: `.planning/superpowers/specs/2026-07-11-security-hardening-535-design.md` §5 S1b.
Risk: **HIGH** — touches the auth flow, a DB migration, and the SPA token model. Human-gated.

## 1. What this is and the invariant it must preserve

Shipped S1 (v0.29.9) made refresh **role-current and revocable via a session epoch**: every JWT
carries a `sepoch` claim; `auth_refresh()` re-reads the DB row under `SELECT … FOR UPDATE`, requires
`approved=1` and `token.sepoch == user.session_epoch`, mints the new token from the **DB row** (not
the token), and **rejects a legacy no-`sepoch` token** (`auth-service.R:140-220`, `auth_generate_token`
`:231-258`). Privilege/state mutations increment `session_epoch` atomically.

S1b adds the audit's remaining P0-2 defense-in-depth that S1 deliberately deferred: **access and
refresh are the same JWT today** (`auth_generate_token` returns one token as both), so a leaked
access token is refreshable until an epoch bump. S1b makes them **distinct** (typ-scoped, different
lifetimes), stores refresh tokens in a **revocation table with single-use rotation and reuse
detection**, and moves `/api/auth/refresh` to a **POST JSON body** (auth-body-only rule).

**Hard non-regression invariant (a live gate, §7):** S1b must NOT weaken S1. After S1b:
- a legacy no-`sepoch` (and now no-`typ`) token is still rejected;
- an epoch bump (demotion/deactivation/password change) still immediately blocks refresh;
- refresh still mints role/claims from the DB row under the row lock, never from the token.

## 2. Design

### 2.1 Migration `044_add_refresh_tokens.sql`
New table `refresh_token`:
- `jti CHAR(36) PRIMARY KEY` (UUID v4, the refresh token's unique id),
- `user_id INT NOT NULL` (indexed; FK-free to match repo convention, app-enforced),
- `issued_at DATETIME NOT NULL`, `expires_at DATETIME NOT NULL`,
- `used_at DATETIME NULL` (set when this token is rotated/consumed — single-use),
- `replaced_by CHAR(36) NULL` (the jti this rotated into — the rotation chain),
- `revoked_at DATETIME NULL` (set when the chain is force-revoked on reuse detection),
- `session_epoch INT NOT NULL` (the epoch the token was minted under — audit/debug).
Idempotent (`CREATE TABLE IF NOT EXISTS` + information_schema guards, restore-drift safe, matching
043's style). Bump `EXPECTED_LATEST_MIGRATION` (`migration-manifest.R:5`) to `044_add_refresh_tokens.sql`,
the min-count, and the two guard tests (`test-unit-analysis-snapshot-migration.R:8`,
`test-unit-core-views-manifest.R` count).

### 2.2 Token minting — distinct access + refresh (`auth_generate_token`)
- **Access token:** `typ="access"`, exp = `config$token_expiry` (3600s), carries the full user
  claims + `sepoch` (unchanged from S1, plus `typ`). No DB row.
- **Refresh token:** `typ="refresh"`, exp = `config$refresh_expiry` (new; default e.g. 30 days),
  carries `user_id`, `sepoch`, and a fresh `jti`; a row is INSERTed into `refresh_token`
  (`issued_at`, `expires_at`, `session_epoch`). The refresh token carries **minimal** claims (id +
  epoch + jti + typ) — it is only a rotation credential, not an authorization token.
- `auth_signin` returns BOTH tokens (already its shape). A new internal helper
  `auth_issue_token_pair(user, config, conn)` mints the pair + inserts the refresh row in the caller's
  transaction. `auth_generate_token` keeps minting the **access** token (used by refresh's
  role-current mint) so the existing single-token call sites stay valid.

### 2.3 Refresh — rotation + reuse detection (`auth_refresh`)
`auth_refresh(refresh_token, pool, config)` now, inside the SAME `FOR UPDATE` transaction as S1:
1. decode + verify signature + `exp`; require `typ == "refresh"` (reject an access token presented
   as refresh); require `sepoch` present (legacy reject preserved) and a valid `user_id`.
2. `SELECT … FROM refresh_token WHERE jti = ? FOR UPDATE`.
   - **not found** → reject (unknown/forged jti).
   - `revoked_at` set → reject (chain already force-revoked).
   - `used_at` set (already rotated) → **REUSE DETECTED**: this is a replayed single-use token →
     force-revoke the whole chain for this user (`UPDATE refresh_token SET revoked_at=NOW() WHERE
     user_id=? AND revoked_at IS NULL`) AND **bump `user.session_epoch`** (so any outstanding access
     tokens are also killed at their next refresh) → reject with a re-login error.
   - expired row → reject.
3. read the `user` row `FOR UPDATE` (S1 logic): `approved=1`, `token.sepoch == user.session_epoch`.
4. **rotate:** mint a NEW pair from the DB row; `UPDATE refresh_token SET used_at=NOW(),
   replaced_by=<new jti> WHERE jti=<old>`; INSERT the new refresh row. Return **both** the new access
   and new refresh token.
Any failure → `stop_for_unauthorized` (frontend logs out). Reuse detection is the key new property.

### 2.4 Endpoint — POST JSON body
`/api/auth/refresh` becomes a **POST** with JSON body `{ refresh_token }` (auth-body-only rule;
matches the signup/authenticate transport hardening). Response: JSON
`{ access_token, refresh_token, token_type:"Bearer", expires_in }`. It stays in `AUTH_ALLOWLIST`
(the refresh token is the credential). Keep a **transitional GET** that returns 410/deprecation only
if needed; default is to move cleanly to POST and update the one frontend caller in the same PR.

### 2.5 Frontend — two-token storage + POST refresh
- `app/src/api/auth.ts:108`: `refresh()` becomes `apiClient.post('/api/auth/refresh', { refresh_token })`
  reading the stored refresh token, and returns the new pair. Typed client only.
- The auth store (`app/src/stores/*` / `useAuth`) stores BOTH tokens (never raw `localStorage.token`
  writes in views). The request interceptor keeps sending the **access** token as the Bearer; the
  refresh token is used only by `refresh()`. On refresh success, both are replaced (rotation). On any
  refresh failure, log out (existing proactive-logout behavior).
- Access-token expiry shortens nothing that S1 didn't already set; the refresh token's longer life is
  what enables a longer session, with rotation limiting theft value.

## 3. Tests (TDD)
- **Unit (auth-service):** access/refresh are DISTINCT tokens with different `typ` and `exp`; an
  access token presented to refresh is rejected (`typ` gate); a valid refresh rotates (old `used_at`
  set, new jti issued, both tokens returned, role from DB); **reuse of an already-rotated refresh
  token force-revokes the chain and bumps the epoch**; an unknown/expired/revoked jti is rejected.
- **Regression (S1 invariant, MUST stay green):** legacy no-`sepoch`/no-`typ` token rejected; epoch
  mismatch (post-demotion) rejected; role minted from DB row. Reuse the shipped
  `test-unit-auth-refresh-epoch.R` assertions.
- **Migration guards** updated (name + count + `res$latest`).
- **Frontend:** `auth.ts` refresh POSTs the body and stores both tokens (its `.spec.ts`); the store
  round-trips two tokens.

## 4. Verification (live, per the umbrella spec §7 — masking only surfaces in the loaded env)
- In-container R tests (auth-service + migration guards) against the test DB.
- **Live monkey (mandatory for auth):** restart `api` + `worker` + `worker-maintenance`; mint tokens
  via the dev-block secret; drive: (a) POST refresh returns a new PAIR; (b) replay the OLD refresh
  token → chain revoked + epoch bumped + 401; (c) **S0-2 regression**: legacy token → 401, epoch-bump
  → 401, valid → 200 with DB-derived claims. Verify the SPA login→refresh→still-authed cycle in the
  browser.
- `make code-quality-audit`, `make lint-api`, `cd app && npm run type-check && npm run test:unit`.
- Codex adversarial plan review AND diff review at xhigh.

## 5. Risk & rollout (human-gated)
- **Frontend two-token migration** is the riskiest part: an in-flight SPA with only the old
  single-token model must still work. The access token is unchanged in shape (still a valid Bearer),
  so already-signed-in users keep working; they get a refresh token on their next `signin`/`refresh`.
  A user who refreshes with a pre-S1b token (no `typ=refresh`, no jti row) is rejected → forced
  re-login (acceptable, one-time, same as the S1 legacy-reject).
- **Reuse-detection + epoch bump** deliberately logs out ALL of a user's sessions on a detected replay
  — correct for theft, but note the UX (a benign double-submit of a refresh could trip it; mitigated
  because rotation is only triggered by the SPA's single refresh path, not concurrently).
- Config: `refresh_expiry` (default 30d) and whether to keep the GET transitional shim are the human
  decisions flagged for sign-off.

## 6. Out of scope
- No change to access-token validation on normal requests (still stateless JWT + `sepoch`-at-refresh;
  per-request epoch check remains the separate optional decision from S1's residual-risk note).
- No refresh-token binding to device/IP (a further hardening; noted).
