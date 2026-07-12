# S5b plan — Codex adversarial review (gpt-5.6-sol, xhigh, read-only) — 2026-07-12

Verdict: **FIX-FIRST**. Deep adversarial pass. Findings below folded into plan v2.

## BLOCKER
1. **useAsyncJob overlapping same-job polls** (plan:174 / useAsyncJob.ts:217) — `pollGeneration`
   changes only across jobs, so two overlapping polls of the SAME job share a generation and an
   older response can overwrite a terminal result after polling stopped. Fix: add generation-scoped
   single-flight (`inFlightGeneration`): skip another poll for a generation already in flight, let a
   new job generation proceed, clear the slot only when still owned.
2. **useUserData debounce window** (plan:229 / useUserData.ts:127) — generation advances only when
   the debounced request STARTS, leaving 50 ms where refs describe P2 but P1 is still authorized to
   apply rows and rewrite the P2 URL. Fix: invalidate ownership when `loadData()` records the P2
   intent (bump at schedule time), AND require the captured param string == freshly-rebuilt current
   params before every apply/error/URL mutation.

## HIGH
3. **useResource consumer-ref cross-consumer** (plan:96 / useResource.ts:75) — `pending === promise`
   protects the cache slot but not consumer refs; a P1 owner/subscriber can still apply P1 after
   another consumer replaced the shared slot with P2. Fix: add a monotonically-preserved cache-slot
   epoch (bumped in `beginFetch`); capture it and require it current in BOTH the owner and subscribe
   branches before applying consumer state.
4. **useResource loading stuck on key-change/abort** (useResource.ts:117) — moving from a loading
   key to a cached/SWR key, or `abort()`, invalidates the old fetch so its `finally` cannot clear
   `loading`, and neither `activate()` nor `abort()` clears it. Fix: `activate()`/`abort()`
   synchronously reset `loading`. Tests: A→cached-B, A→SWR-B, explicit abort.
5. **useAsyncJob public stopPolling()/unmount** (useAsyncJob.ts:293 / plan:179) — pause timers
   without invalidating an in-flight poll, so it can still mutate state after cancellation/unmount.
   Fix: bump `pollGeneration` on public `stopPolling`, `reset`, and unmount (in-flight poll becomes
   a no-op).
6. **useUserData no unmount cleanup** (useUserData.ts:62) — a pending debounce/request can apply
   rows and call `history.replaceState()` after navigation. Fix: `onBeforeUnmount` clears the timer
   and sets an instance-local `disposed`; include `!disposed` in every continuation guard.
7. **useUserData nextTick currentPage** (useUserData.ts:83) — guarded `applyApiResponse()` still
   schedules an UNguarded `nextTick()` mutation of `currentPage`. Fix: pass an ownership predicate
   into the callback and re-check before mutation (or assign synchronously).
8. **cache-parameter test is vacuous** (plan:212) — passes before the fix (single P2, waits for P2).
   Fix: cache P1, start a deferred P2, mutate a sentinel state value, issue a second identical P2
   while pending, assert P1 was NOT reapplied before resolving P2.
9. **ADJACENT: useMetadataAdmin.ts:72** — switching vocabulary A→B lets late A rows populate the B
   table; a subsequent edit then uses `activeSlug=B` with an A row id and can modify the WRONG
   vocabulary (data-integrity/security). Fix: fold into S5b — captured slug + request generation
   across success/catch/loading.
10. **ADJACENT (follow-up): useEntityInfo.ts:87, useReviewData.ts:241** — rapid entity/selection
    changes interleave multi-call loads → mixed curation form / overwritten record. File a P1
    follow-up (whole-workflow instance token/abort scope); larger than S5b.

## MEDIUM
11. useUserData recent-call ordering (plan:230 / :98) — order same-param in-flight dedup first;
    make a cache hit conditional on a non-null response whose stored params match.
12. useUserData module-global generation can suppress one live instance with another and leave the
    suppressed instance's `isBusy` true forever — keep transport/cache ownership module-level but
    make consumer generation + busy ownership INSTANCE-local.
13. stale-rejection test (plan:43) resolves P2 before rejecting P1 — reject P1 while P2 remains
    deferred; assert `cache.pending`/`loading` stay owned by P2, then resolve P2.
14. MSW gate deadlock risk (plan:134) — use a "handler entered" deferred; start timer advancement
    without awaiting, supersede/release, then await; `finally` cleanup.
15. spec promises A-B-A / reset-in-flight / overlapping same-job coverage (spec:104) the plan omits —
    add all three + an interval single-flight test advancing several ticks while one same-job request
    stays gated.
16. useAdminTrendData.ts:96, usePubtatorGenePublications.ts:89 — stale catch/finally can clear newer
    data / delete newer controller. Follow-up.

## LOW
17. useNetworkData.ts:199, usePubtatorAdmin.ts:48 — repeated fetches without request ownership.
    General read-composable ownership follow-up.

## Confirmed correct
- `peek(key)?.pending === promise` is a valid shared-cache write/clear ownership test (beginFetch
  synchronously replaces pending; set/endFetch clear it; no check-to-mutation interleave).
- Owned successful `cache.set()` making the subsequent `ownsSlot()` false is intentional (no
  double-clear; preserves refCount).
- `activeToken` + per-instance fetch generation correctly handles same-instance SWR-vs-refresh,
  concurrent refreshes, key changes, stale success/catch.
- Cross-job poll-generation guard immediately after await + first in catch protects all current
  success/error/terminal sites incl. j1→j2→j1.
- Separate cached-response params are necessary and correct once the whole cache-hit condition is
  fixed.
- useUserData axios mock + useAsyncJob MSW mocks match the real `apiClient.get()` boundary.

## Disposition (plan v2)
- Fold BLOCKER 1,2 + HIGH 3-9 + MEDIUM 11-15 into S5b (4 files: useResource, useAsyncJob,
  useUserData, useMetadataAdmin).
- Findings 10, 16, 17 → tracked **S5c follow-up** (whole-workflow / read-composable ownership),
  documented in plan + final report, NOT built now (larger, multi-call, reviewer said "follow-up").
