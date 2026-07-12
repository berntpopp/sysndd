# S6 — Clustering Admission Controls — Plan

> REQUIRED SUB-SKILL: superpowers:test-driven-development. Design:
> `.../specs/2026-07-12-security-535-s6-clustering-admission-design.md`.

## Task 1 — pure limiter + fingerprint (TDD)
- [x] `test-unit-clustering-submit-throttle.R`: max_n/window/slide/retry_after/distinct-fingerprint/
  disable/unknown-bucket + fingerprint XFF-first-hop/REMOTE_ADDR/unknown. (host-runnable, no DB)
- [x] `async-job-service.R`: `async_job_submit_rate_limit()` (injectable clock + store, non-positive
  cap disables) + `async_job_submit_fingerprint()` (XFF first hop → REMOTE_ADDR → "unknown") +
  `async_job_submit_rate_limit_reset()` (tests). Env: `CLUSTERING_SUBMIT_PER_CALLER_MAX` (5),
  `CLUSTERING_SUBMIT_WINDOW_SECONDS` (60).

## Task 2 — wire both submit services
- [x] `job-functional-submission-service.R` + `job-phenotype-submission-service.R`: call the throttle
  AFTER cache-hit/duplicate short-circuits and BEFORE the global capacity guard; on throttle →
  `429 + Retry-After` (`RATE_LIMITED`).

## Task 3 — verify + review + PR
- [x] Host R throttle test green; `make lint-api` clean; files < 600.
- [ ] Codex adversarial diff review (xhigh); fold; PR (do-not-auto-merge). Live check flagged
  (X-Forwarded-For carries the real client IP behind Traefik).

## Self-review
- Extends `async_job_capacity_exceeded` with a per-caller dimension; does not touch the global cap,
  cache path, or dup check. Process-local trade-off documented; DB-backed cross-replica is a
  follow-up. Both submit paths identically wired.
