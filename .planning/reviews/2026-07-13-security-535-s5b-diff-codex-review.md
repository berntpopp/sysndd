# S5b diff — Codex adversarial review (final, gpt-5.x, xhigh, read-only)

Final pre-merge adversarial diff review of PR #544 (S5b frontend request-ownership,
slice of #535). Reviews run with `codex exec -s read-only -c model_reasoning_effort=xhigh`
against `git diff master...HEAD`. This record covers the final passes (rounds 2–4);
the round-1 record is `2026-07-12-security-535-s5b-diff-codex-review.md`.

## Round 2 (commit 5d6e2849) — Verdict: FIX-FIRST (no BLOCKERs, 2 HIGH)

- **HIGH (useResource — subscriber path):** the shared-pending subscriber applied the
  awaited value even after ANOTHER consumer superseded the slot, stranding the
  subscriber on same-key stale data. The r1 fix (per-instance generation) avoided
  *stuck loading* but the correct behavior is to *follow the current slot*.
  → **Fixed:** capture the subscribed slot `epoch`; on supersession call a new
  `followCurrentSlot(key, background)` that hydrates from the resolved cache entry if
  the superseding fetch already completed, else re-enters `doFetch` to follow/restart
  it. Never applies the stale value, never leaves loading stuck, no redundant 3rd fetch
  (no await between the two peeks), recursion bounded by monotonic epochs.
- **HIGH (useUserData — module cache poisoning):** the module recent-response cache was
  written unconditionally on every completion, so a superseded SAME-param fetch
  (A1→B→A2, A2 first) completing last overwrote the fresher cached A2. Param-keying only
  protects cross-param, not same-param out-of-order.
  → **Fixed:** module-wide monotonic per-fetch-START sequence `moduleFetchSeq` +
  `moduleLastResponseSeq`; the cache write happens only when `mySeq >= moduleLastResponseSeq`.
  Preserves the existing A→B→cached-A isBusy behavior (unlike gating by current intent).
- **MEDIUM (touched files):** `loadRoleList`/`loadUserList` disposal guards;
  `useMetadataAdmin.loadCatalog` generation guard.

## Round 3 (worktree, pre-commit) — Verdict: FIX-FIRST (no BLOCKERs, 1 genuine MEDIUM)

- **HIGH (useResource — owner/starter path):** SYMMETRIC gap — a consumer that OWNS an
  in-flight fetch still wrote its stale value into its own refs when another consumer
  advanced the slot (`consumerCurrent()` stayed true while `slotCurrent()` went false).
  → **Fixed:** the owner success AND catch paths now `if (!slotCurrent()) return
  followCurrentSlot(...)` after the `consumerCurrent()` check, symmetric with the
  subscriber path.
- **HIGH (useMetadataAdmin — catalog auto-select ownership):** a newer catalog could
  keep a stale `activeSlug` with rows loading under it (catalog/selection desync).
  → **Fixed:** after accepting a catalog under the generation guard, reconcile
  `activeSlug` — reselect the first entry (or clear on empty) when the active slug is
  absent from the accepted catalog, routing through `selectVocabulary` so
  `rowsGeneration` bumps and an older catalog-initiated row load is superseded.
- **MEDIUM (useMetadataAdmin — empty-catalog branch, introduced by the r3 fix):** the
  empty-catalog reconcile branch cleared `activeSlug`/`rows` but did not bump
  `rowsGeneration` or clear `loadingRows`, so an in-flight row load left the spinner
  stuck. → **Fixed:** bump `rowsGeneration` and set `loadingRows = false` in that branch.
- **MEDIUM (useUserData — single in-flight boolean):** the coarse module dedup boolean
  cannot represent two concurrent same-param transports; a second same-param instance
  returns from the dedup branch without subscribing to the first's promise. This is
  **pre-existing** (not S5b-introduced — displayed-data correctness is fully guarded by
  the ownership checks) and was scoped to **S5c** (params-keyed in-flight promise map)
  in the r1 plan review. **Deferred to S5c.**
- **LOW (useMetadataAdmin — mutation busy flags):** `saving`/`deleting` are unordered
  across overlapping mutations. Mutations are UI-serialized (buttons disabled while
  saving), a different concern from read/poll response-ownership. **Deferred.**
- The two "HIGH" items about the r2/r3 folds being "unstaged" were an artifact of
  reviewing `master...HEAD` before the folds were committed; Codex confirmed the
  worktree folds are correct ("hands loading ownership correctly, avoids cache
  poisoning, no synchronous recursion hazard"). Resolved by committing (5d8836e5).

## Round 4 (commit 5d8836e5) — Verdict: FIX-FIRST (no BLOCKER/HIGH, 1 MEDIUM)

All r2/r3 folds committed and verified in `master...HEAD`; no BLOCKER/HIGH remained.
One residual MEDIUM:

- **MEDIUM (useUserData — cache write guard):** the guard compared the completing
  fetch's start sequence with the last cache *writer*, not the latest start. In
  A1→B→A2, if stale A1 resolved BEFORE A2, A1 passed the guard (no later writer yet)
  and transiently repopulated the A cache; a cache-serve in that window returned A1
  until A2 corrected it. → **Fixed (commit 123314dd):** replace `moduleLastResponseSeq`
  with a per-parameter-key latest-start map (`moduleLatestStartSeqByParam`); a
  completing fetch may record the cache only if it is still the latest-STARTED fetch
  for its own params. Closes the same-param window in ANY completion order; preserves
  A→B→cached-A (different params). Regression test added.

## Round 5 (commit 123314dd) — Verdict: SHIP

No BLOCKER/HIGH/MEDIUM/LOW findings. All committed folds verified in `master...HEAD`;
no new hazard. Typed `@/api/*` clients only; `axios` used only for `isAxiosError` plus
a JSDoc example; no direct `localStorage.token`/`localStorage.user`. `useAsyncJob`
poll-generation + single-flight and the `cacheStore` global monotonic epoch counter
re-confirmed sound. Codex ran `vue-tsc --noEmit`, targeted ESLint, and `git diff --check`
itself — all passed.

## Deferred to S5c (documented, not built in S5b)

- `useUserData` params-keyed in-flight promise transport map (replaces the single
  boolean dedup; fixes the cross-instance two-same-param-instances dedup miss).
- Read-composable request-ownership in other files: `usePubtatorGenePublications`,
  `useAdminTrendData` (catch/finally versioning), `tableRequestCoordinator`
  (cross-instance single generation), `useOntologyAdminTable` (deferred `currentPage`),
  `useNetworkData`, `usePubtatorAdmin`.
- `useMetadataAdmin` mutation busy-flag ordering (`saving`/`deleting`).

## Gates (final)

- `make code-quality-audit` → OK (exit 0)
- `make lint-app` → 0 errors (warnings pre-existing `no-explicit-any`)
- `cd app && npm run type-check:strict` → 0 errors (all scopes OK)
- `cd app && npm run type-check` (full `vue-tsc --noEmit`) → 0 errors
- `cd app && npm run test:unit` → 1995 passed | 2 todo, 0 failures (264 files)
