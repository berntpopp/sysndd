# S5b — Frontend Request Ownership (useResource / useAsyncJob / useUserData) — Design

Date: 2026-07-12
Issue: [#535](https://github.com/berntpopp/sysndd/issues/535) — umbrella hardening, slice **S5b**
Parent design: `.planning/superpowers/specs/2026-07-11-security-hardening-535-design.md` (§3 S5 row)
Predecessor: **S5** (PR #541, v0.29.9) fixed `tableRequestCoordinator` (A-B-A) and
`useSearchSuggestions` (out-of-order). S5's Codex plan review **explicitly deferred** three
load-bearing composables to this slice with a documented adversarial analysis
(`.planning/reviews/2026-07-11-security-535-s5-plan-codex-review.md`).

## 1. What this is

The S5 request-ownership work fixed two of the five racing data paths and deferred the three whose
fixes are load-bearing (the in-house SWR layer + the durable-job poller + the admin user table).
This slice closes those three. **Only the response of the latest request for a given consumer may
mutate state**; a superseded or reset request must neither apply data nor corrupt shared in-flight
bookkeeping (cache slots, `isBusy`, polling intervals).

This is a correctness/reliability hardening (audit findings **P1-7 / P2-3**), not a feature. It is
frontend-only, unit-testable with deterministic deferred promises, and touches no API, no auth, and
no persisted state. Public composable signatures do not change.

## 2. Verified defects (re-read against current master `3b529c71`)

Each was named by the S5 plan-stage Codex review (BLOCKER/HIGH) and re-verified in current code.

### 2.1 `useResource.ts` (BLOCKER)
`activeToken` (line 48) changes only on **key activation/abort** (`activate`/`abort`), never per
fetch. Two `refresh()` calls (or an SWR background revalidate racing an explicit `refresh()`) for
the **same active key** share one token, so:
- The older resolution overwrites the newer fetch's `data`/`error`/`isStale` refs
  (`useResource.ts:100-106`), because the `myToken !== activeToken` guard cannot distinguish two
  same-key fetches.
- Worse, `cache.set()` / `cache.endFetch()` (`:101,108,112`) run **unconditionally** — a stale
  fetch overwrites the newer fetch's cached value or clears its pending slot / abortController in
  the shared `cacheStore`, corrupting the transport slot for **every** subscriber of that key. In an
  A-B-A key cycle an abort-ignoring old-A fetch cannot mutate the (token-guarded) consumer ref, but
  can still overwrite A2's cache entry. `AbortController` is best-effort and does not establish
  ownership (a fetcher that ignores the signal still resolves).

### 2.2 `useAsyncJob.ts` (BLOCKER)
`checkJobStatus()` (`:217`) keys ownership on nothing: after `startJob('j2')` supersedes `j1`, an
in-flight `j1` poll that resolves **or rejects** still writes `status`/`step`/`progress`/`error`
and — critically — calls `stopPolling()`. Because `startJob()` merely `resumePolling()`s the **one
shared `useIntervalFn` interval** (`:286`), a stale poll's `stopPolling()` **pauses the new job's
polling**. The `catch` path (`:258-271`) is entirely unguarded: a rejected `j1` poll marks `j2`
failed and stops it. `jobId`-equality alone is insufficient (it misses `j1→j2→j1` and overlapping
same-job polls).

### 2.3 `useUserData.ts` (HIGH)
`doLoadData()` (`:95`) has no ownership guard, so an out-of-order response applies stale data. Two
distinct sub-defects:
- **Unowned mutation:** a superseded P1 response still runs `applyApiResponse`, `updateBrowserUrl`,
  clears `moduleApiCallInProgress`, and clears `isBusy` (`:115-124`) even though a newer P2 request
  is the latest. `updateBrowserUrl` reads **current** table refs, so a late P1 can pair P1 rows with
  P2's URL.
- **Cache is not response-param-safe:** the 500 ms recent-response branch (`:98-101`) keys the
  *decision* on `moduleLastApiParams` but serves `moduleLastApiResponse` without proving that stored
  response belongs to the requested params. Starting P2 sets `moduleLastApiParams = P2` but leaves
  P1 in `moduleLastApiResponse`; a second P2 call within 500 ms can apply P1 data.

## 3. Strategy — uniform generation/ownership guard (mirror shipped S5)

Every request-ownership site captures its identity **when the fetch starts** and, on resolution,
mutates state only if it still **owns** it. This is the exact, already-reviewed pattern shipped in
S5 (`tableRequestCoordinator`, `useSearchSuggestions`). No refactor of the working composables; add
internal generation state only.

- **`useResource`** — two distinct ownership tokens, per the S5 Codex review's "distinguish
  transport-slot generation from per-consumer freshness":
  - *Per-instance fetch generation* (`++fetchGeneration` at each `doFetch` start) gates the
    **consumer refs** (`data`/`error`/`isStale`/`loading`) — combined with the existing `activeToken`
    key guard, so both same-key concurrency and key changes are covered.
  - *Transport-slot ownership* gates the **shared cache** writes: capture the exact `promise` this
    fetch created and call `cache.set()` / `cache.endFetch()` only while
    `cacheStore.peek(key)?.pending === promise` (a newer `beginFetch` replaces `pending`, so a stale
    fetch cleanly declines to touch the slot). The subscribe-to-existing-pending branch never owns
    the slot (it only reads), so it keeps its consumer-ref guard and touches no cache writes.
- **`useAsyncJob`** — one `pollGeneration`, bumped in `startJob()` and `reset()`. `checkJobStatus`
  captures it at the top; immediately after the `await`, if `myGen !== pollGeneration` it **returns
  before any mutation and before `stopPolling()`**, on **both** the success path (including the 200
  `JOB_NOT_FOUND` and terminal `completed`/`failed` branches) and the `catch` path.
- **`useUserData`** — module-level `moduleRequestGeneration` (consistent with the existing
  module-level dedup singleton; the ManageUser page mounts one instance and the module cache is
  shared by design). Bumped at each `doLoadData` start. Guards `applyApiResponse`,
  `updateBrowserUrl`, the `moduleApiCallInProgress` clear, and the `isBusy` clear. Additionally add
  `moduleLastApiResponseParams`: the 500 ms cache branch requires `moduleLastApiResponseParams ===
  urlParam`, and a fresh request clears `moduleLastApiResponse`/`moduleLastApiResponseParams` so a
  superseded response can never be served for the wrong params.

### Non-goal / documented residual
`useUserData`'s generation is module-level, matching the pre-existing module-level transport dedup
(`moduleApiCallInProgress`). A theoretical second concurrent instance could have its still-current
response suppressed by the other instance's newer fetch — but that is a property of the **existing**
shared-singleton design (not introduced here), and the page mounts exactly one instance. A
per-instance/params split is out of scope; the current-params guard already prevents applying a
response whose params no longer match the live table.

## 4. Tests (deterministic; no timers/sleeps for the race logic)

Drive races with **manually-resolved deferred promises**, resolving the stale request **last**.
Extend the existing specs (do not create parallel paths):

- `app/src/composables/__tests__/useResource.spec.ts` — concurrent same-key `refresh()` (older
  resolves last → newer `data` wins, cache holds newer value); A-B-A cache-overwrite (old-A cannot
  overwrite A2's cache slot); stale **rejection** does not clear a newer pending slot / newer error.
- `app/src/composables/useAsyncJob.spec.ts` — stale success (`j1` poll resolves after `startJob(j2)`
  → `j2` state intact, still polling); stale **rejection** (`j1` poll rejects after `j2` start →
  must not fail/stop `j2`); `j1→j2` supersede; `reset()` invalidates an in-flight poll.
- `app/src/views/admin/composables/__tests__/useUserData.spec.ts` — out-of-order apply (P1 resolves
  after P2 → P2 data wins, `isBusy`/in-progress not cleared by stale P1); cache-param-safety (P2
  within 500 ms does not serve P1's stored response).

## 5. Verification

- `cd app && npx vitest run` on the three specs (RED first, then GREEN) + full `npm run test:unit`.
- `npm run type-check` and `npm run type-check:strict` (touched scope).
- `make lint-app` on touched files.
- Keep every touched file < 600 lines (all three are well under).
- Codex adversarial diff review at GPT-5.5 xhigh before PR.

## 6. Out of scope
- No public signature changes; no API/auth/DB changes.
- The `useResource` subscribe-branch loading flicker and broader SWR ergonomics are unchanged.
- `tableRequestCoordinator` / `useSearchSuggestions` are already shipped (S5) and untouched.
