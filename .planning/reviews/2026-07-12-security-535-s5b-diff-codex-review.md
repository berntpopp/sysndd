# S5b diff — Codex adversarial review (gpt-5.6-sol, xhigh, read-only)

## Round 1 (commit 97d0f564) — Verdict: FIX-FIRST (no BLOCKERs, 3 HIGH)

- **HIGH (useResource):** the cache-slot epoch was also used as the consumer ownership token, so a
  subscriber (consumer B) of a shared pending would reject its value and get **stuck loading** when
  another consumer (A) started a newer fetch. → Fixed: per-instance `fetchGeneration` gates consumer
  refs/loading; the slot epoch gates only cache writes.
- **HIGH (cacheStore):** per-key epoch increment could **collide after invalidate()** (old epoch 1 →
  delete → recreate epoch 0 → new epoch 1), letting a stale fetch overwrite the new slot. → Fixed:
  store-wide monotonic `epochCounter` (never reused).
- **HIGH (useUserData):** A→B→cached-A could leave `isBusy=true` forever, and the cache-hit path
  omitted `updateBrowserUrl()`. → Fixed: a current cache hit is treated as a completed intent
  (apply + URL + clear busy).
- **MEDIUM (useUserData transport):** the single-boolean/params module dedup can't represent two
  concurrent transports (possible duplicate request; cross-instance dedup returns without delivering
  the shared result; the 500ms timestamp reflects the most-recent start). → **Deferred to S5c**
  (params-keyed in-flight promise map) — it is the pre-existing best-effort dedup design the plan
  review told us to keep module-level; correctness of *displayed* data is handled by the ownership
  guards. Documented, not silently dropped.
- **LOW:** test coverage gaps for the three HIGHs → added cross-consumer, invalidate-collision, and
  A→B→cached-A tests; `removeFilters` debounce-timer leak → `dispose()` after the assertion; add
  reset-in-flight → added.

### Confirmed correct (round 1)
useResource cache-on-cancel preserved; set/endFetch/subscribe preserve epoch; activate/abort clear
loading; same-consumer concurrent refresh + stale rejection protect the newer slot; useAsyncJob
success+catch guards, terminal stopPolling, reset double-bump harmless, single-flight no leak;
useUserData dedup doesn't bump startGeneration, stable latestIntent survives pagination-ref mutation,
disposal prevents late mutation; useMetadataAdmin guards success/catch/finally; the 12 new tests are
non-vacuous and deterministic.

## Round 2 (commit 8940eb7e) — all 3 HIGH folded; re-review pending (see round-2 codex run).
