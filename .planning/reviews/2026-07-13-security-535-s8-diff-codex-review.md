# S8 account/email hardening — final adversarial Codex diff review (#535)

- **PR:** #545 — S8 account/email hardening (slice of umbrella security issue #535)
- **Branch:** `fix/535-s8-account-email-hardening`
- **Reviewer:** Codex (`gpt-5.6-sol`, `model_reasoning_effort=xhigh`, read-only)
- **Recipe:** `codex exec -s read-only -c approval_policy=never -c model_reasoning_effort=xhigh` over `git diff master...HEAD`
- **Final verdict:** `Verdict: SHIP` — "No BLOCKER / HIGH / MEDIUM / LOW findings."
- **Rounds to SHIP:** 4 review rounds (round 5 overall counting the pre-existing SHIP). Codex reviews the *committed* `HEAD`, so each round's folds had to be committed before the next round could see them.

## Confirmed correct on every round

- **CSPRNG temp password** (`random_password`, `account-helpers.R`): uniform / bias-free — 64-symbol alphabet, `256 %% 64 == 0` (four byte preimages per symbol, no modulo bias, no rejection sampling), 72 bits of entropy, drawn from `openssl::rand_bytes` (not seedable `sample()`). All four temp-password call sites use the helper; no other credential generator uses `sample()`/`runif()`.
- **HTML escaping** of user-controlled email fields (`email-templates.R`): complete and context-correct — element-text via `email_escape()`, HTML-attribute (ORCID href) via `email_escape_attr()`, NA/NULL/non-scalar coerced to `""`.
- No masked bare `get(..., mode=...)` introduced. `git diff --check` clean.

## Findings folded to reach SHIP

Codex's "budget ~2x scope / grep every adjacent same-class sink" pass surfaced credential/token-leak sinks beyond the original diff. All BLOCKER + HIGH + the cheap MEDIUM/LOW were folded (TDD RED→GREEN in `test-unit-account-email-hardening.R`).

### Round 1 (initial) — 2 MEDIUM + 2 LOW
- **MEDIUM — log injection:** signup fields length-checked only; CR/LF-bearing `user_name` logged verbatim on SMTP failure. → Root-cause fix: `account_field_has_control_char()` + signup rejects control chars in every account field.
- **MEDIUM — recipient/header validation delegated downstream:** unanchored, dotall email regex accepts CR/LF passed to `smtp_send()`. → Hardened `is_valid_email()` (scalar/NA-safe, reject `[[:cntrl:]]`, anchored) + control-char guard at the `send_noreply_email()` choke point.
- **LOW — greeting `nchar()` bypass:** throws on NA/vector `user_name`. → Branch on `nzchar(user_name_e)`.
- **LOW — stale roxygen** still described `sample()`. → Rewrote to document the CSPRNG + bias-free mapping.

### Round 2 (deeper) — 1 BLOCKER + 1 HIGH + 1 MEDIUM + 1 LOW
- **BLOCKER — password-reset BCC leak:** `send_noreply_email()` default `email_blind_copy = "noreply@sysndd.org"`; the password-reset send relies on the default, so the **bearer reset URL was blind-copied to a shared mailbox** → account takeover during token validity. → Default is now `NULL` (no BCC); NULL permitted and simply not attached.
- **HIGH — temp-password BCC leak:** the four account-approval sends BCCed the **plaintext temporary password** to `curator@sysndd.org` (shared mailbox → impersonation of newly approved users). → Credentials now go to the account address only; curator BCC removed from all four sends.
- **MEDIUM — permissive signup email regex:** `.+@.+\.+` (dotall) admits SMTP recipient grammar (`<a@b.com> NOTIFY=SUCCESS`). → Signup gates the email through the anchored `is_valid_email()`; choke point also requires a scalar recipient.
- **LOW — latent `batch_info` sink** in `email_rereview_request` (no caller). → HTML-escaped.

### Round 3 (residual) — 2 LOW
- **LOW — central address validation:** the send choke point rejected control chars but not full address grammar (legacy/admin-edited rows). → `send_noreply_email()` now validates every `to`/`bcc` address with `is_valid_email()`; empty-string bcc treated as "no blind copy".
- **LOW — stored-value log sink:** account-approval log interpolates a stored `user_name` (legacy CR/LF risk). → `sanitize_log_value()` neutralizes control chars at that log sink.

### Round 4 (final) — none
`Verdict: SHIP` — no findings.

## Gates (fresh evidence)

- `make code-quality-audit` → `code-quality audit clean` (exit 0).
- `make lint-api` → `Total issues: 0`, all 171 files pass.
- Targeted `test-unit-account-email-hardening.R` (in `sysndd-api-1`, which has htmltools) → `FAIL 0 | WARN 0 | SKIP 0 | PASS 154`.
- `make test-api-fast` → the only 4 failures are the pre-existing missing-`htmltools` host artifact in `test-unit-password-reset-request.R` (the htmltools call was introduced by the base S8 commit; those tests pass 17/17 in-container and are green on CI, which has htmltools). No other failures; `PASS 5962`.

Codex could not execute R in its read-only sandbox (temp-file creation blocked); test evidence above was produced by the author in-container and via `make test-api-fast`.

## Files touched by the folds

- `api/functions/account-helpers.R` — CSPRNG doc, hardened `is_valid_email()`, `account_field_has_control_char()`, `sanitize_log_value()`, `send_noreply_email()` NULL-default BCC + central address validation + scalar recipient + subject control-char guard.
- `api/functions/email-templates.R` — `nzchar` greeting guards; `batch_info` escaping.
- `api/endpoints/authentication_endpoints.R` — signup control-char rejection + strict `is_valid_email()` gate.
- `api/services/user-account-endpoint-service.R` — removed curator BCC from two approval sends; sanitized approval log sink.
- `api/services/user-service.R` — removed curator BCC from two approval sends.
- `api/tests/testthat/test-unit-account-email-hardening.R` — RED→GREEN tests for every fold.
