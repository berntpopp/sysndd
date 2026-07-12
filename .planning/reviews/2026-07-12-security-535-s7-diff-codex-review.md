# S7 diff — Codex adversarial review (gpt-5.6-sol, xhigh) — Verdict round 1: FIX-FIRST → folded

## HIGH (folded)
- Single unbounded DELETE could make a huge transaction/lock set on a large first-run backlog. →
  Fixed: `run_async_job_retention` deletes in bounded batches (`LIMIT 1000`, each auto-committed)
  looping until under a full batch.

## MEDIUM (folded)
- Age anchored on `submitted_at` only → a long-delayed job could be deleted right after completing. →
  Fixed: predicate now requires BOTH `submitted_at` AND `updated_at` older than the window (terminal
  for N days). Added a count/delete predicate-identity test + a batched-loop test.
- Live DB matrix test (every status, retry-pending, cascade) → tracked follow-up (needs a live DB;
  pure predicate + guard logic is host-tested).

## LOW (noted)
- 09-deployment.qmd still says only `logging` is pruned + omits the new env vars → doc follow-up.
- `llm_generation_log` is another monotonic table — deliberately NOT folded in (separate retention
  policy; contains prompts/responses).

## Confirmed correct
- `active_request_hash IS NULL` is migration 020's exact non-retryable marker (queued/running/
  cancel-requested/retry-pending are non-NULL) → the predicate cannot delete an active/retry-pending
  job; retention interpolation injection-safe; `submitted_at` indexed; events cascade via FK; S2
  scrub scope matches (row-lock-safe); entrypoint mirrors pool/config/error handling; compose runs
  cleanups sequentially with independent failure handling; 90-day default reasonable.
