# S5b — Frontend Request Ownership (useResource / useAsyncJob / useUserData) — Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:test-driven-development. Steps use `- [ ]`.

**Goal:** Only the latest request for a consumer may mutate state. Close the three request-ownership
races S5 deferred: `useResource` (per-fetch + transport-slot ownership), `useAsyncJob` (poll
generation, guarding success AND catch AND `stopPolling`), `useUserData` (module generation +
response-param-safe cache). Design: `.../specs/2026-07-12-security-535-s5b-resource-ownership-design.md`.

## Global constraints
- Deterministic tests: manually-resolved deferred promises, resolve the **stale** request last.
- No public composable signature changes; internal generation state only.
- Keep touched files < 600 lines. Namespaced/typed as the surrounding code.

---

### Task 1: `useResource` — per-fetch + transport-slot ownership

**Files:** modify `app/src/composables/useResource.ts`; extend `app/src/composables/__tests__/useResource.spec.ts`.

- [ ] **Step 1 — RED tests** (append a `describe('useResource — S5b request ownership', …)`), using
  per-call deferred resolvers so each fetch is resolved independently:

```ts
// concurrent same-key refresh: older resolves last, must not win, cache holds newer
it('two concurrent refresh() for the same key: the stale (older) resolution does not win', async () => {
  const resolvers: Array<(v: string) => void> = [];
  const fetcher = vi.fn(() => new Promise<string>((res) => { resolvers.push(res); }));
  const Comp = defineComponent({ setup() { return { r: useResource('k-race', fetcher, { ttlMs: 60_000 }) }; }, render: () => h('div') });
  const w = mount(Comp); await nextTick(); await Promise.resolve(); // fetch #0 in flight (initial)
  resolvers[0]('v0'); await Promise.resolve(); await nextTick();    // settle initial
  const p1 = (w.vm as any).r.refresh();   // fetch #1
  const p2 = (w.vm as any).r.refresh();   // fetch #2 (newer)
  resolvers[2]('fresh'); await p2; await Promise.resolve();
  resolvers[1]('stale'); await p1; await Promise.resolve();         // stale resolves LAST
  expect((w.vm as any).r.data.value).toBe('fresh');
  const cache = useCacheStore();
  expect(cache.peek('k-race')?.value).toBe('fresh');               // stale did NOT overwrite cache
  w.unmount();
});

// stale rejection must not clear a newer fetch's pending slot / newer error/data
it('a stale rejection does not corrupt the newer fetch cache slot or refs', async () => {
  const rs: Array<(v: string) => void> = []; const rj: Array<(e: unknown) => void> = [];
  const fetcher = vi.fn(() => new Promise<string>((res, rej) => { rs.push(res); rj.push(rej); }));
  const Comp = defineComponent({ setup() { return { r: useResource('k-rej', fetcher, { ttlMs: 60_000 }) }; }, render: () => h('div') });
  const w = mount(Comp); await nextTick(); await Promise.resolve();
  rs[0]('v0'); await Promise.resolve(); await nextTick();
  const p1 = (w.vm as any).r.refresh(); const p2 = (w.vm as any).r.refresh();
  rs[2]('fresh2'); await p2; await Promise.resolve();
  rj[1](new Error('stale-boom')); await p1.catch(() => {}); await Promise.resolve();
  expect((w.vm as any).r.data.value).toBe('fresh2');
  expect((w.vm as any).r.error.value).toBeNull();                  // stale rejection ignored
  const cache = useCacheStore();
  expect(cache.peek('k-rej')?.value).toBe('fresh2');
  w.unmount();
});
```

- [ ] **Step 2 — run RED** — `cd app && npx vitest run src/composables/__tests__/useResource.spec.ts`.
  The first test fails (stale overwrites data/cache); guards do not yet exist.

- [ ] **Step 3 — implement.** Add per-instance fetch generation and transport-slot ownership.

  Near `activeToken` (line ~48) add: `let fetchGeneration = 0;`

  Rewrite `doFetch` so BOTH branches capture identity at start and guard on it:
```ts
  async function doFetch(key: ResourceKey, force: boolean, background = false): Promise<void> {
    const myToken = activeToken;
    const myGen = ++fetchGeneration;
    const isLatest = (): boolean => myToken === activeToken && myGen === fetchGeneration;

    const existing = cache.peek<T>(key);
    if (existing?.pending && !force) {
      try {
        if (!background) loading.value = true;
        const value = (await existing.pending) as T;
        if (!isLatest()) return;
        data.value = value; error.value = null; isStale.value = false;
      } catch (e) {
        if (!isLatest()) return;
        error.value = e instanceof Error ? e : new Error(String(e));
      } finally {
        if (isLatest() && !background) loading.value = false;
      }
      return;
    }

    const ac = new AbortController();
    const promise = (async () => await fetcher(ac.signal))();
    cache.beginFetch<T>(key, promise, ac);
    // Transport-slot ownership: only the fetch whose promise is still the slot's
    // `pending` may write/clear the shared cache entry. A newer beginFetch()
    // replaces `pending`, so a stale fetch declines to touch the slot.
    const ownsSlot = (): boolean => cache.peek<T>(key)?.pending === promise;
    if (!background) loading.value = true;
    try {
      const value = await promise;
      if (ownsSlot()) cache.set<T>(key, value, ttlMs);
      if (!isLatest()) return;
      data.value = value; error.value = null; isStale.value = false;
    } catch (e) {
      if (ownsSlot()) cache.endFetch(key);
      if (!isLatest()) return;
      error.value = e instanceof Error ? e : new Error(String(e));
    } finally {
      if (ownsSlot()) cache.endFetch(key);
      if (isLatest() && !background) loading.value = false;
    }
  }
```
  (Note: `cache.set()` already nulls `pending`, so the `finally` `ownsSlot()` is false after a
  successful owned write — no double-clear. `activate`/`abort`/`refresh` are unchanged.)

- [ ] **Step 4 — run GREEN** — the two new tests pass and the whole existing `useResource.spec.ts`
  suite stays green (dedupe, abort, SWR, cached-null, refresh-preserves-refcount).

- [ ] **Step 5 — commit** `fix(app): per-fetch + transport-slot ownership in useResource (#535 S5b)`.

---

### Task 2: `useAsyncJob` — poll generation guards success + catch + stopPolling

**Files:** modify `app/src/composables/useAsyncJob.ts`; extend `app/src/composables/useAsyncJob.spec.ts`.

- [ ] **Step 1 — RED tests.** Use the existing fake-interval harness. Drive a poll whose HTTP
  resolution is deferred via a manual `server.use` handler that holds a promise, then `startJob(j2)`
  before releasing j1's response.

  Simplest deterministic construction: mock the status endpoint to return per-job payloads and
  assert cross-job non-interference:
```ts
it('a stale poll from a superseded job does not overwrite the new job or stop its polling', async () => {
  // j1 poll resolves AFTER startJob('j2'); j1 must not touch j2 state or polling.
  let release!: () => void;
  const gate = new Promise<void>((r) => { release = r; });
  let seen: string[] = [];
  server.use(http.get('/api/jobs/:job_id/status', async ({ params }) => {
    const id = String(params.job_id); seen.push(id);
    if (id === 'j1') { await gate; return HttpResponse.json({ job_id:['j1'], status:['failed'], error:['j1 crashed'] }); }
    return HttpResponse.json({ job_id:['j2'], status:['running'], step:['go'], progress:{current:[1],total:[2]} });
  }));
  const [job, app] = withSetup(() => useAsyncJob(statusEndpoint, { pollingInterval: TEST_POLL_MS, timerInterval: TEST_TIMER_MS }));
  job.startJob('j1');
  await vi.advanceTimersByTimeAsync(TEST_POLL_MS);   // j1 poll starts, awaits gate
  job.startJob('j2');                                // supersede while j1 in flight
  release(); await flushPromises();                  // j1 resolves LAST (failed)
  expect(job.status.value).not.toBe('failed');       // stale j1 did not fail j2
  expect(job.jobId.value).toBe('j2');
  expect(job.isPolling.value).toBe(true);            // stale j1 did not stopPolling
  job.stopPolling(); app.unmount();
});

it('a stale poll REJECTION does not fail or stop the new job', async () => {
  let release!: () => void; const gate = new Promise<void>((r)=>{ release = r; });
  server.use(http.get('/api/jobs/:job_id/status', async ({ params }) => {
    const id = String(params.job_id);
    if (id === 'j1') { await gate; return HttpResponse.json({ error:'boom' }, { status: 500 }); }
    return HttpResponse.json({ job_id:['j2'], status:['running'], step:['go'], progress:{current:[0],total:[0]} });
  }));
  const [job, app] = withSetup(() => useAsyncJob(statusEndpoint, { pollingInterval: TEST_POLL_MS, timerInterval: TEST_TIMER_MS }));
  job.startJob('j1'); await vi.advanceTimersByTimeAsync(TEST_POLL_MS);
  job.startJob('j2'); release(); await flushPromises();
  expect(job.status.value).not.toBe('failed');
  expect(job.isPolling.value).toBe(true);
  job.stopPolling(); app.unmount();
});
```

- [ ] **Step 2 — run RED** — `npx vitest run src/composables/useAsyncJob.spec.ts` (stale j1 currently
  fails/stops j2).

- [ ] **Step 3 — implement.** Add `let pollGeneration = 0;` (near the refs). At the top of
  `checkJobStatus`, after the `if (!jobId.value) return;`, capture `const myGen = pollGeneration;`.
  Immediately after the `await apiClient.get(...)` resolves — before the `JOB_NOT_FOUND`/status
  handling — insert `if (myGen !== pollGeneration) return;`. In the `catch`, as the **first**
  statement, insert `if (myGen !== pollGeneration) return;` (before `stopPolling()`/mutations). In
  `startJob()` and `reset()` add `pollGeneration += 1;` (in `reset`, after `stopPolling()`; in
  `startJob`, before `resumePolling()`).

- [ ] **Step 4 — run GREEN** — new tests pass; all existing useAsyncJob lifecycle tests stay green
  (complete/blocked/500/404/200-JOB_NOT_FOUND, reset).

- [ ] **Step 5 — commit** `fix(app): poll-generation ownership in useAsyncJob (#535 S5b)`.

---

### Task 3: `useUserData` — module generation + response-param-safe cache

**Files:** modify `app/src/views/admin/composables/useUserData.ts`; extend
`app/src/views/admin/composables/__tests__/useUserData.spec.ts`.

- [ ] **Step 1 — RED tests.** Use deferred `axios.get` resolvers (the spec mocks axios at module
  level). Fire P1, change params, fire P2, resolve P1 LAST:
```ts
it('an out-of-order stale response does not apply or clear busy over the newer request', async () => {
  const axios = await getAxiosMock();
  const resolvers: Array<(v: unknown) => void> = [];
  axios.get.mockImplementation(() => new Promise((res) => { resolvers.push(res); }));
  const data = useUserData();
  const p1 = data.loadDataNow();                 // P1 params (default)
  data.perPage.value = 50;                        // change → P2 params differ
  const p2 = data.loadDataNow();                  // P2
  resolvers[1]({ status: 200, data: { ...userTablePayload, meta: [{ ...userTablePayload.meta[0], totalItems: 99 }] } });
  await p2; await flushPromises();
  resolvers[0]({ status: 200, data: userTablePayload }); // stale P1 resolves LAST
  await p1; await flushPromises();
  expect(data.totalRows.value).toBe(99);          // P2 data retained, P1 ignored
});

it('the 500ms cache does not serve a prior params response for new params', async () => {
  const axios = await getAxiosMock();
  axios.get.mockResolvedValueOnce({ status: 200, data: userTablePayload });        // P1
  const data = useUserData();
  await data.loadDataNow(); await flushPromises();
  data.perPage.value = 50;                          // params change (P2)
  axios.get.mockResolvedValueOnce({ status: 200, data: { ...userTablePayload, meta:[{...userTablePayload.meta[0], totalItems: 7}] } });
  await data.loadDataNow(); await flushPromises();  // must fetch P2, not serve P1 cache
  expect(data.totalRows.value).toBe(7);
  expect(axios.get).toHaveBeenCalledTimes(2);
});
```

- [ ] **Step 2 — run RED** — `npx vitest run src/views/admin/composables/__tests__/useUserData.spec.ts`.

- [ ] **Step 3 — implement.** Add module state `let moduleLastApiResponseParams: string | null =
  null;` and `let moduleRequestGeneration = 0;`, reset both in `__resetUserDataCache()`.
  In `doLoadData`:
  - recent-cache branch: only apply when `moduleLastApiResponse && moduleLastApiResponseParams ===
    urlParam`.
  - after passing the dedup guards, `const myGen = ++moduleRequestGeneration;` and clear
    `moduleLastApiResponse = null; moduleLastApiResponseParams = null;` at request start.
  - success: `if (myGen !== moduleRequestGeneration) return;` before clearing
    `moduleApiCallInProgress`, recording `moduleLastApiResponse = data` /
    `moduleLastApiResponseParams = urlParam`, `applyApiResponse`, `updateBrowserUrl`.
  - catch: `if (myGen !== moduleRequestGeneration) return;` before clearing
    `moduleApiCallInProgress` / toasting.
  - finally: `if (myGen === moduleRequestGeneration) tableData.isBusy.value = false;`.

- [ ] **Step 4 — run GREEN** — new tests pass; existing useUserData tests stay green (loadData
  populate, error path clears isBusy, roleList, handlePageChange 2 calls, removeFilters).

- [ ] **Step 5 — commit** `fix(app): module-generation + param-safe cache in useUserData (#535 S5b)`.

---

### Task 4: Verify, Codex diff review, PR

- [ ] **Step 1 — full verify** — `cd app && npm run test:unit`; `npm run type-check`;
  `npm run type-check:strict`; `make lint-app`; `make code-quality-audit` (file-size ratchet).
- [ ] **Step 2 — Codex adversarial diff review** at GPT-5.5 xhigh; commit to
  `.planning/reviews/2026-07-12-security-535-s5b-diff-codex-review.md`; fix → re-review until SHIP.
- [ ] **Step 3 — open PR** against master (do-not-auto-merge, security-critical), `Closes` line refs
  #535 on its own line. Do NOT auto-merge.

## Self-review
- Spec coverage: §2.1→Task1, §2.2→Task2, §2.3→Task3; deterministic deferred-promise races in each.
- Consistency: uniform "capture identity at start; mutate only if still owner/latest"; `useResource`
  splits per-instance freshness (fetchGeneration+activeToken) from transport-slot ownership
  (`pending === promise`), exactly as the S5 Codex review prescribed.
- No public signature changes; no placeholders; each fix shows exact guarded code.
