# S8 (account/email hardening) — CSPRNG temp passwords + HTML-escaped email fields — Design

Date: 2026-07-12
Issue: [#535](https://github.com/berntpopp/sysndd/issues/535) — umbrella hardening, slice **S8**
(defense-in-depth quick wins). This is the first of the S8 splits (clean seam: the account
notification/credential path). Parent design:
`.planning/superpowers/specs/2026-07-11-security-hardening-535-design.md` §3 (S8), §cheap-wins.

## 1. What this is

Two independent, low-risk, well-bounded defense-in-depth fixes in the account-email subsystem,
shipped together because they share the exact same code area, the same reviewers, and the same
verification path (`account-helpers.R` + `email-templates.R`):

1. **CSPRNG temporary passwords (P3).** `random_password()` (`api/functions/account-helpers.R:37-46`)
   draws with `sample()`, which uses R's Mersenne-Twister PRNG — **not cryptographically secure** and
   seedable/predictable. This is the generator for the temporary login credential emailed on account
   approval (call sites: `user-service.R:135,415`, `user-account-endpoint-service.R:55,260`). Replace
   the draw with a CSPRNG.
2. **HTML-escape user-controlled email fields (P2/P3, stored-XSS-in-email).** Signup fields
   (`user_name`, `first_name`, `family_name`, `email`, `orcid`) are stored raw (parameterized SQL —
   SQL-safe) and later interpolated **raw** into HTML email bodies via `glue::glue()`; the body is
   marked as trusted HTML with `htmltools::HTML()` (`account-helpers.R:162-167`, `html_content=TRUE`)
   and sent (BCC'd to `curator@sysndd.org`). A crafted `user_name` such as
   `<img src=x onerror=...>` or `"><a href=...>` is delivered as live markup to the curator's mail
   client. No HTML-escaping exists anywhere in `api/`. Escape the user-controlled fields at each
   interpolation site.

Neither change touches DB schema, auth flow, or deployment topology. Both are operator-invisible.

## 2. Design

### 2.1 CSPRNG password
Keep the public contract identical: a 12-character string over the same 64-character alphabet
`c(0:9, letters, LETTERS, "!", "$")`. The alphabet is **exactly 64** characters and 256 is an exact
multiple of 64 (256 / 64 = 4), so mapping a uniform random byte with `byte %% 64` is **bias-free**
(no rejection sampling needed). Draw 12 CSPRNG bytes via `openssl::rand_bytes(12)` (openssl is in
`renv.lock`; verify it loads in-container) and index the alphabet. `random_password()` keeps its
signature, length, and charset; only the entropy source changes. A code comment states the
64|256 bias-free invariant so a future alphabet change is flagged.

### 2.2 HTML-escaped email fields
Add two tiny helpers in `email-templates.R`:
- `email_escape(x)` → `htmltools::htmlEscape(as.character(x), attribute = FALSE)` for element **text**
  contexts, NULL/empty-safe (returns `""`).
- `email_escape_attr(x)` → `htmltools::htmlEscape(as.character(x), attribute = TRUE)` for values
  interpolated into an **attribute** (the ORCID `href`), also escaping quotes.

Pre-escape the user-controlled locals at the top of each template that renders them, then interpolate
the escaped locals in the `glue` template (keeping templates readable):
- `email_password_reset`: `user_name`.
- `email_registration_request`: `first_name`, `user_info$user_name`, `user_info$email`,
  `user_info$first_name`, `user_info$family_name`.
- `email_account_approved`: `user_name`. (`temp_password` is system-generated over a known safe
  alphabet — left as-is.)
- `email_rereview_request`: `user_name`, `user_info$user_name`, `user_info$email`, and `user_info$orcid`
  **twice** — `email_escape_attr` for the `href="https://orcid.org/{orcid}"` and `email_escape` for
  the visible label.
- `email_batch_assigned`: `user_name`. (`batch_number`/`entity_count` are numeric/system.)
- `email_notification`: `user_name`. (`subject_text` and `body_content` are developer/system-
  controlled — `body_content` is deliberately HTML; left unescaped by design.)

The wrapper's brand constants, URLs (`reset_url`, `login_url`, `review_url`), and static markup are
system-controlled and unchanged.

## 3. Tests (TDD, R testthat)
New `api/tests/testthat/test-unit-account-email-hardening.R`:
- **CSPRNG:** `set.seed(1); a <- random_password(); set.seed(1); b <- random_password();
  expect_false(identical(a, b))` — the old `sample()` path is seed-reproducible (RED), a CSPRNG
  ignores the seed (GREEN). Plus: length == 12, every char ∈ the alphabet, and a distribution
  sanity check (many draws use > 1 distinct alphabet class).
- **HTML-escape:** `email_registration_request(list(user_name = '<img src=x onerror=alert(1)>', ...))`
  output **contains** `&lt;img` and **does not contain** the literal `<img src=x onerror`; same for a
  quote-breaking `orcid = '"><b>'` in `email_rereview_request` (attribute-escaped). A benign name
  round-trips unchanged.
Keep the existing `test-unit-user-approval.R` / `test-unit-user-endpoint-services.R` green (they
reference `random_password`; the contract is unchanged).

## 4. Verification
- In-container R tests (tests dir is not bind-mounted): run the new test + the two existing user
  tests. Confirm `openssl::rand_bytes` loads in the API image.
- `make lint-api` (host), `make code-quality-audit` (file-size ratchet — both files stay < 600).
- Live monkey check (optional, high-value): render `email_registration_request` with a hostile name
  in-container and grep the output for escaped markup.
- Codex adversarial diff review before PR.

## 5. Out of scope / follow-ups
- Frontend admin user-management rendering of the same fields is a separate consumer (Vue escapes by
  default; not an API concern).
- Throttling of signup/auth, dead `create_job` executor_fn, and the MCP SELECT-only DB principal are
  the other S8 splits (separate PRs).
- The approved-comment visibility question (S8-c in the umbrella spec) is unrelated.
