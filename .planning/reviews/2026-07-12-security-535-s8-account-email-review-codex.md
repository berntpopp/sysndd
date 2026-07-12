# S8 account/email — Codex adversarial review (gpt-5.6-sol, xhigh, read-only)

## Verdict: SHIP (no BLOCKER / HIGH / MEDIUM). LOW hardening applied.

### Confirmed correct
- CSPRNG mapping correct: 64-char alphabet (10+26+26+2), `rand_bytes(12)` → 12 secure bytes 0..255,
  `256 %% 64 == 0` (bias-free), `+1L` → indices 1..64, 72-bit entropy. `openssl` 2.4.0 pinned in
  renv.lock and in the API image; `openssl::rand_bytes` namespace-qualified; RNG failure throws (no
  insecure fallback). All 4 production call sites keep the scalar 12-char contract.
- Every HTML-email occurrence of user_name/first_name/family_name/email/orcid escaped; ORCID
  attribute-escaped in href + text-escaped label. Attribute mode escapes quotes + CR/LF; text mode
  preserves apostrophes. temp_password/URLs/batch numbers are non-user/system-controlled;
  `email_notification()` has no callers (its trusted body_content/subject_text unexposed).
- Tests non-vacuous (CSPRNG seed test fails vs sample(); injection assertions fail before escaping).
- No other credential generator uses R's PRNG (other sample()/runif() are sampling/jitter/tempnames).

### LOW (applied in this PR)
- `email_escape*()` now coerces NULL/NA/non-scalar → "" (reject `length != 1L`, `is.na`) so a
  malformed field can't render "NA"/vectorize (not previously exploitable; defensive).
- ORCID test now explicitly asserts `&quot;` (proves attribute escaping, not text); added an
  `email_escape` NULL/NA/scalar coercion test.

### Adjacent follow-up (NOT S8 — separate untrusted-markup sink)
- `app/src/components/filters/TermSearch.vue:31` uses raw `v-html` for API-derived gene symbols;
  `highlightMatch()` concatenates them without escaping. Not ordinary account-user input, so out of
  S8 scope — tracked as a frontend v-html follow-up (use Vue text bindings around `<strong>`).
