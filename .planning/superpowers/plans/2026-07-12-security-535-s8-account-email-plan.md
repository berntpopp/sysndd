# S8 (account/email hardening) — Plan

> REQUIRED SUB-SKILL: superpowers:test-driven-development. Steps use `- [ ]`.

**Goal:** CSPRNG temp passwords + HTML-escaped user fields in account emails, contract-preserving.
Design: `.../specs/2026-07-12-security-535-s8-account-email-design.md`.

## Task 1: RED tests
- [ ] Create `api/tests/testthat/test-unit-account-email-hardening.R`:
  - CSPRNG: `set.seed(1); a <- random_password(); set.seed(1); b <- random_password();
    expect_false(identical(a, b))`; `expect_equal(nchar(random_password()), 12)`; every char of many
    draws ∈ `c(0:9, letters, LETTERS, "!", "$")`.
  - Escape: `out <- email_registration_request(list(user_name = "<img src=x onerror=alert(1)>",
    email = "a@b.c", first_name = "A", family_name = "B"))`; `expect_true(grepl("&lt;img", out))`;
    `expect_false(grepl("<img src=x onerror", out, fixed = TRUE))`. ORCID attribute:
    `out2 <- email_rereview_request(list(user_name="u", email="a@b.c", orcid='"><b>'))`;
    `expect_false(grepl('"><b>', out2, fixed = TRUE))`; `expect_true(grepl("&gt;&lt;b&gt;", out2))`.
    Benign name round-trips (`grepl("Ada", email_account_approved("Ada", "pw"))`).
- [ ] Run in-container → RED (source current `account-helpers.R` + `email-templates.R`).

## Task 2: CSPRNG `random_password()`
- [ ] `api/functions/account-helpers.R`: replace the `sample()` draw with
  ```r
  # 64-char alphabet; 256 %% 64 == 0 so `byte %% 64` is bias-free (no rejection sampling).
  possible_characters <- c(0:9, letters, LETTERS, "!", "$")  # length 64 — keep at 64
  idx <- as.integer(openssl::rand_bytes(12)) %% length(possible_characters) + 1L
  paste(possible_characters[idx], collapse = "")
  ```
  Keep roxygen; note the CSPRNG + bias-free invariant. Verify `openssl` loads in-container.

## Task 3: HTML-escape helpers + field escaping
- [ ] `api/functions/email-templates.R`: add `email_escape()` (attribute=FALSE, NULL/empty→"") and
  `email_escape_attr()` (attribute=TRUE). Pre-escape user-controlled locals in
  `email_password_reset`, `email_registration_request`, `email_account_approved`,
  `email_rereview_request` (ORCID: attr for href + text for label), `email_batch_assigned`,
  `email_notification` (`user_name` only). Leave `body_content`, URLs, brand constants, numeric batch
  fields, and `temp_password` unescaped (system-controlled / intentional HTML).

## Task 4: GREEN + verify
- [ ] In-container: new test + `test-unit-user-approval.R` + `test-unit-user-endpoint-services.R`
  green. `make lint-api` (host). File sizes < 600. Live render a hostile name → grep escaped.
- [ ] Codex adversarial diff review; fold; PR (do-not-auto-merge, security-critical), `Closes` refs
  #535 on its own line.

## Self-review
- Contract preserved (12 chars, same alphabet); only entropy source + escaping change. Escaping is
  applied to every user-derived interpolation; `body_content` intentionally excluded. Both files
  stay < 600 lines.
