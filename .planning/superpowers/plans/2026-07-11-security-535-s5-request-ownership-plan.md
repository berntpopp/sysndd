# S5 — Frontend Request Ownership (A-B-A / out-of-order races) — Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans. Steps use `- [ ]`.

**Goal:** Stop stale async responses from being applied (or corrupting in-flight bookkeeping) after the view has moved on — the A-B-A and out-of-order response races in `tableRequestCoordinator` and the sibling data composables (#535 P1-7/P2-3). Only the response of the **latest** request for a given consumer may mutate state.

**Architecture:** Each request-ownership site gains a monotonic **generation** (or the natural identity — jobId) captured when a fetch starts. On resolution, a response may (a) clear shared in-flight bookkeeping only if it still **owns** it, and (b) apply data only if its generation is still the **latest** and the consumer is still current. This is a uniform, minimal guard — no refactor of the working composables into the coordinator (noted as a DRY follow-up). `useResource` already implements this (`activeToken`/`myToken` + `AbortController`) and is left unchanged.

**Tech Stack:** Vue 3 composables, TypeScript, Vitest.

## Global Constraints

- Deterministic tests only: drive races with **manually-resolved deferred promises**, never timers/sleeps.
- Do not change public composable signatures; add internal generation state only.
- Keep touched files < 600 lines.

---

### Task 1: `tableRequestCoordinator` — generation-based ownership

**Files:**
- Modify: `app/src/utils/tableRequestCoordinator.ts`
- Test: `app/src/utils/tableRequestCoordinator.spec.ts` (extend)

**The bug:** identity is the `params` string. After A→B→A, the *original* A promise resolves, matches the new A2's slot (`inFlightParams === "A"`), clears A2's `inFlightPromise`, records A's stale data, and `isCurrent("A")` passes → stale apply + corrupted in-flight state.

- [ ] **Step 1: Write failing deterministic tests** (append to the spec)

```ts
// Deferred helper
function deferred<T>() {
  let resolve!: (v: T) => void; let reject!: (e: unknown) => void;
  const promise = new Promise<T>((res, rej) => { resolve = res; reject = rej; });
  return { promise, resolve, reject };
}

it('A-B-A: the original A response does not apply after A2 supersedes it', async () => {
  const coord = createTableRequestCoordinator<string>();
  const applied: string[] = [];
  let current = 'A';
  const dA = deferred<string>(); const dB = deferred<string>(); const dA2 = deferred<string>();
  const rA = coord.request({ params: 'A', fetcher: () => dA.promise, apply: (d) => applied.push(`A:${d}`), onError: () => {}, isCurrent: (p) => p === current });
  current = 'B';
  const rB = coord.request({ params: 'B', fetcher: () => dB.promise, apply: (d) => applied.push(`B:${d}`), onError: () => {}, isCurrent: (p) => p === current });
  current = 'A';
  const rA2 = coord.request({ params: 'A', fetcher: () => dA2.promise, apply: (d) => applied.push(`A2:${d}`), onError: () => {}, isCurrent: (p) => p === current });

  dA.resolve('stale');   // original A resolves LAST-ish, view is back on A
  await rA;
  expect(applied).not.toContain('A:stale'); // stale original A must NOT apply

  dB.resolve('bdata'); await rB;             // B superseded, must not apply
  expect(applied).not.toContain('B:bdata');

  dA2.resolve('fresh'); await rA2;
  expect(applied).toContain('A2:fresh');     // the latest A2 applies
});

it('out-of-order: an earlier request resolving after a later one does not clobber', async () => {
  const coord = createTableRequestCoordinator<string>();
  const applied: string[] = [];
  let current = 'X';
  const d1 = deferred<string>(); const d2 = deferred<string>();
  const r1 = coord.request({ params: 'X', fetcher: () => d1.promise, apply: (d) => applied.push(d), onError: () => {}, isCurrent: () => true });
  current = 'Y';
  const r2 = coord.request({ params: 'Y', fetcher: () => d2.promise, apply: (d) => applied.push(d), onError: () => {}, isCurrent: (p) => p === current });
  d2.resolve('y'); await r2;
  d1.resolve('x'); await r1;
  expect(applied).toEqual(['y']); // only the latest (Y) applied
});
```

- [ ] **Step 2: Run to verify FAIL** — `cd app && npx vitest run src/utils/tableRequestCoordinator.spec.ts`

- [ ] **Step 3: Add the generation counter** to `createTableRequestCoordinator`

Add state: `let inFlightGen = 0; let generation = 0;`

In the **shared** branch, capture the current generation and guard on it:
```ts
    if (inFlightParams === params && inFlightPromise) {
      const source: TableRequestSource = 'shared';
      const myGen = generation;
      try {
        const data = await inFlightPromise;
        if (myGen !== generation || !isCurrent(params)) return { handled: false, source };
        apply(data, source);
        return { handled: true, source };
      } catch (error) {
        if (myGen !== generation || !isCurrent(params)) return { handled: false, source };
        onError(error, source);
        return { handled: true, source };
      }
    }
```

In the **network** branch, stamp a new generation and guard both the clear and the apply:
```ts
    const source: TableRequestSource = 'network';
    const myGen = ++generation;
    lastParams = params;
    lastCallTime = now();
    lastResponse = null;
    lastResponseParams = null;

    const promise = fetcher();
    inFlightPromise = promise;
    inFlightParams = params;
    inFlightGen = myGen;

    try {
      const data = await promise;
      if (inFlightGen === myGen) {           // only the owner clears/records
        inFlightPromise = null;
        inFlightParams = null;
        lastResponse = data;
        lastResponseParams = params;
      }
      if (myGen !== generation || !isCurrent(params)) return { handled: false, source };
      apply(data, source);
      return { handled: true, source };
    } catch (error) {
      if (inFlightGen === myGen) {
        inFlightPromise = null;
        inFlightParams = null;
        lastResponse = null;
        lastResponseParams = null;
      }
      if (myGen !== generation || !isCurrent(params)) return { handled: false, source };
      onError(error, source);
      return { handled: true, source };
    }
```

(Leave the recent-response `cache` branch as-is — it is a synchronous read guarded by `isCurrent`.)

- [ ] **Step 4: Run to verify PASS** (new tests + the whole existing spec stay green).

- [ ] **Step 5: Commit** `git commit -m "fix(app): generation-based request ownership in tableRequestCoordinator (A-B-A) (#535)"`

---

### Task 2: `useSearchSuggestions` — ignore out-of-order responses

**Files:**
- Modify: `app/src/composables/useSearchSuggestions.ts`
- Test: `app/src/composables/useSearchSuggestions.spec.ts` (new)

- [ ] **Step 1: Failing test** — mock `apiService.fetchSearchInfo` with deferred promises; fire for `"a"` then `"ab"`, resolve `"a"` LAST, assert `suggestions` reflect `"ab"` (not `"a"`).

- [ ] **Step 2: Add a generation guard** to `fetchSuggestions`:

```ts
  let requestGeneration = 0;

  async function fetchSuggestions(): Promise<void> {
    if (query.value.length < 1) { clearSuggestions(); return; }
    const myGen = ++requestGeneration;
    isLoading.value = true;
    try {
      const response = await apiService.fetchSearchInfo(query.value);
      if (myGen !== requestGeneration) return;              // a newer query superseded this one
      [searchObject] = response as unknown as [Record<string, Array<{ link: string }>>];
      suggestions.value = Object.keys(searchObject).map((key) => ({ label: key, link: searchObject[key][0].link }));
    } catch {
      if (myGen !== requestGeneration) return;
      suggestions.value = []; searchObject = {};
    } finally {
      if (myGen === requestGeneration) isLoading.value = false; // only the latest owns the flag
    }
  }
```

- [ ] **Step 3: Run PASS. Commit.**

---

### Task 3: `useUserData` — generation guard on `doLoadData`

**Files:**
- Modify: `app/src/views/admin/composables/useUserData.ts`
- Test: `app/src/views/admin/composables/useUserData.spec.ts` (new, or extend if present)

- [ ] **Step 1: Failing test** — mock `getUserTable` with deferred promises; fire load for params P1 then P2 (change tableData), resolve P1 LAST, assert `applyApiResponse` used P2's data and `moduleApiCallInProgress` was not cleared by P1.

- [ ] **Step 2: Add a module generation counter**; in `doLoadData`, when a fetch starts: `const myGen = ++moduleRequestGeneration;`. After `await getUserTable(...)`: only clear `moduleApiCallInProgress`/record `moduleLastApiResponse` and call `applyApiResponse`/`updateBrowserUrl` when `myGen === moduleRequestGeneration`; the `catch` clears `moduleApiCallInProgress` and toasts only when `myGen === moduleRequestGeneration`.

- [ ] **Step 3: Run PASS. Commit.**

---

### Task 4: `useAsyncJob` — ignore a stale poll after the job changes

**Files:**
- Modify: `app/src/composables/useAsyncJob.ts` (`checkJobStatus`)
- Test: `app/src/composables/useAsyncJob.spec.ts` (new, or extend)

- [ ] **Step 1: Failing test** — mock `apiClient.get` deferred; start job "j1", trigger a poll, then `startJob('j2')`, then resolve j1's poll; assert j1's status did NOT overwrite j2's state.

- [ ] **Step 2: Capture the polled job id** at the top of `checkJobStatus` (`const polledJobId = jobId.value;`) and, immediately after the `await`, `if (polledJobId !== jobId.value) return;` before any `status/step/progress/error` assignment or `stopPolling()`.

- [ ] **Step 3: Run PASS. Commit.**

---

### Task 5: Confirm `useResource`, verify, PR

- [ ] **Step 1: Confirm `useResource` already guards ownership** — `activeToken`/`myToken` is checked in both the shared-pending and fresh-fetch paths, plus `AbortController`. No change; document it as the reference pattern in the PR.
- [ ] **Step 2: Verify** — `cd app && npx vitest run src/utils/tableRequestCoordinator.spec.ts src/composables/useSearchSuggestions.spec.ts src/composables/useAsyncJob.spec.ts src/views/admin/composables/useUserData.spec.ts`; `npm run type-check`; `npm run lint` on touched files.
- [ ] **Step 3: Codex adversarial diff review; fold; open PR referencing #535.**

## Self-Review

- Spec coverage: A-B-A `tableRequestCoordinator` → Task 1; the four sibling composables → Tasks 2-4 + Task 5 (useResource already safe). Deterministic A-B-A + out-of-order tests → Tasks 1-4.
- Consistency: the guard is uniformly "capture identity at start; apply/clear only if still the owner/latest". `myGen !== generation` = superseded; `inFlightGen === myGen` = still owner.
- No placeholders; each fix shows the exact guarded code.
