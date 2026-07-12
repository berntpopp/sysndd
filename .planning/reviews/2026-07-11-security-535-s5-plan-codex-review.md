Static review only; no edits, tests, or services run.

## BLOCKER

- [useResource.ts:72](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s5-request-ownership/app/src/composables/useResource.ts:72) is not fully request-race-safe, contrary to [plan:206](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s5-request-ownership/.planning/superpowers/plans/2026-07-11-security-535-s5-request-ownership-plan.md:206). `activeToken` changes only on key activation/abort, not per fetch. Two `refresh()` calls for the same active key share one token, so an older response can overwrite newer `data` at lines 100–106. Worse, unconditional `cache.set()`/`cache.endFetch()` at lines 101–113 can overwrite or clear a newer fetch’s cache slot. In A-B-A, an abort-ignoring old A fetch cannot mutate the consumer ref, but can overwrite A2’s cache. AbortController is best-effort and does not establish ownership.  
  Fix: add per-fetch generation/ownership and make cache completion conditional on the exact pending promise/token; cover concurrent forced refresh, A-B-A cache overwrite, and stale rejection clearing a newer pending slot.

- [useAsyncJob.ts:217](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s5-request-ownership/app/src/composables/useAsyncJob.ts:217): `jobId` alone is not a sufficient ownership key. The proposed post-`await` check at [plan:200](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s5-request-ownership/.planning/superpowers/plans/2026-07-11-security-535-s5-request-ownership-plan.md:200) does not guard the catch path at lines 258–271: a rejected j1 poll still stops j2 polling and marks j2 failed. It also misses overlapping polls for the same job ID and j1→j2→j1.  
  Fix: generation per `startJob()`/`reset()`, plus per-poll sequence or prohibit overlapping polls. Guard success, 200 `JOB_NOT_FOUND`, terminal handling, and catch before every mutation/`stopPolling()`.

## HIGH

- [useUserData.ts:7](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s5-request-ownership/app/src/views/admin/composables/useUserData.ts:7): a module-global generation conflates transport deduplication with consumer ownership. A P2 fetch from instance B would suppress the still-current P1 response for instance A. That leaves A without data while its request was never superseded by A.  
  Fix: per-instance generation/current-params guard for consumer state; separate module-level ownership for the shared transport/cache, preferably a params-keyed pending promise.

- [useUserData.ts:98](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s5-request-ownership/app/src/views/admin/composables/useUserData.ts:98): the “cache” is not response-param-safe. Starting P2 updates `moduleLastApiParams` but leaves P1 in `moduleLastApiResponse`; another P2 call within 500 ms can apply P1 data. The proposed plan does not clear or separately key the cached response.  
  Fix: track `moduleLastApiResponseParams`, require equality, and clear/replace response ownership when a fresh request begins.

- [useUserData.ts:95](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s5-request-ownership/app/src/views/admin/composables/useUserData.ts:95): generation changes only when `doLoadData()` starts. During the 50 ms debounce, table refs may already describe P2 while P1 remains “latest”; P1 can then apply and `updateBrowserUrl()` reads P2 refs at lines 165–176. Also the unconditional `isBusy=false` at lines 122–124 lets an older request clear the flag while a newer same-instance request is pending.  
  Fix: compare captured request params against current params before apply/URL mutation, and guard busy with the per-instance request generation.

- [useSearchSuggestions.ts:37](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s5-request-ownership/app/src/composables/useSearchSuggestions.ts:37): the proposed counter is insufficient because it increments only when a non-empty fetch begins. If query `"a"` is pending and the query changes or clears before the debounced successor begins, `"a"` can still apply. `clearSuggestions()` at lines 59–62 does not invalidate ownership.  
  Fix: capture `requestedQuery`, guard both generation and `query.value === requestedQuery`, and invalidate pending ownership on every query change/explicit clear.

## MEDIUM

- [tableRequestCoordinator.ts:17](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s5-request-ownership/app/src/utils/tableRequestCoordinator.ts:17): the proposed global generation correctly fixes single-consumer A-B-A, and `inFlightGen === myGen` cannot clear another network owner because generations are unique. However, coordinators are module-level at real call sites, e.g. [useEntitiesTable.ts:26](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s5-request-ownership/app/src/components/tables/useEntitiesTable.ts:26). A later request from consumer B suppresses a legitimate owner/shared response for still-current consumer A. Shared borrowers inherit the transport generation, not consumer ownership.  
  Fix: distinguish transport-slot generation from per-consumer freshness. This likely requires a caller-owned request token/consumer identity or per-instance generation around `apply`, while retaining module-level promise dedupe.

- [plan:37](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s5-request-ownership/.planning/superpowers/plans/2026-07-11-security-535-s5-request-ownership-plan.md:37): the A-B-A test is deterministic and catches stale application, but does not prove that original A cannot corrupt A2’s slot. A2 still applies under the old implementation even after its slot was cleared.  
  Fix: while A2 is pending, issue another A request and assert it shares A2/no fourth fetch; after A2 resolves, assert the recent-cache branch returns A2.

- [plan:184](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s5-request-ownership/.planning/superpowers/plans/2026-07-11-security-535-s5-request-ownership-plan.md:184): resolving P1 after P2 cannot demonstrate that P1 did not clear `moduleApiCallInProgress`; P2 has already cleared it.  
  Fix: resolve stale P1 while P2 remains pending, then make another P2 request and prove it dedupes rather than starts a third network call.

- Error-path coverage is missing. Stale success tests will not catch the unguarded `useAsyncJob` catch defect. Add stale rejection tests for all ownership sites, plus shared-promise rejection and same-job overlapping polls.

## LOW

- The existing user-data spec is at [composables/__tests__/useUserData.spec.ts:1](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s5-request-ownership/app/src/views/admin/composables/__tests__/useUserData.spec.ts:1), not the path named at plan line 182. Extend it rather than creating a parallel spec location.

## Corrections to apply

1. Replace `jobId`-only polling ownership with start/reset generation plus poll sequence; guard catch paths.
2. Include `useResource` in S5; add exact cache pending-owner checks.
3. Split `useUserData` module transport ownership from per-instance state ownership.
4. Key/null the user-data cached response by response params.
5. Guard user-data `isBusy`, URL mutation, and deferred `nextTick` mutations.
6. Capture and compare the search query; invalidate on query change/clear.
7. Resolve the coordinator’s cross-instance ownership semantics before implementing a global generation.
8. Expand deterministic tests for slot integrity, shared branches, stale errors, rapid same-params, same-job overlapping polls, and concurrent refreshes.

## Confirmed correct

- The proposed coordinator network generation fixes the described single-consumer A-B-A.
- A lone coordinator request is not suppressed.
- An unsuperseded shared borrower correctly applies.
- `inFlightGen === myGen` safely protects the single in-flight slot.
- Leaving the synchronous recent-response branch unchanged is safe provided cached response ownership is correct.
- All three existing [tableRequestCoordinator.spec.ts](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s5-request-ownership/app/src/utils/tableRequestCoordinator.spec.ts:4) tests remain compatible; none expects a superseded same-params response to apply.
- The proposed search `finally` guard does not stick loading: latest finishes → false; stale later does nothing. If stale finishes first, loading remains true until latest settles.
- A stale job poll must not call `stopPolling()`: `startJob()` merely resumes the same shared interval at lines 277–287, so an old poll stopping it would harm the new job.
- `useResource` does guard consumer refs and `loading` across key changes in both shared-pending and fresh-fetch paths; the residual defect is same-key/per-fetch and cache ownership.