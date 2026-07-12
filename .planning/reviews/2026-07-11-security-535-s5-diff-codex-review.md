## Findings

- **MEDIUM** — [useSearchSuggestions.ts:65](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s5-request-ownership/app/src/composables/useSearchSuggestions.ts:65), [useSearchSuggestions.ts:69](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s5-request-ownership/app/src/composables/useSearchSuggestions.ts:69): clearing during an active request permanently leaves `isLoading=true`. `clearSuggestions()` increments the generation, so the invalidated request’s `finally` cannot clear loading.  
  **Fix:** set `isLoading.value = false` in `clearSuggestions()` and assert it in the clear-during-pending test.

- **LOW** — [useSearchSuggestions.spec.ts:25](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s5-request-ownership/app/src/composables/useSearchSuggestions.spec.ts:25): query mutations activate the real 300 ms watcher, leaving timers that can trigger extra unmocked requests during/after tests. The clear test also leaves query `"a"`, allowing a later debounced refetch.  
  **Fix:** use fake timers with cleanup, or isolate/stop the watcher and explicitly drain/cancel timers.

- **LOW** — [tableRequestCoordinator.spec.ts:162](/home/bernt-popp/development/sysndd/.claude/worktrees/535-s5-request-ownership/app/src/utils/tableRequestCoordinator.spec.ts:162): the unexpected A4 fetch returns an unresolved deferred, so a regression can hang until Vitest timeout. On old code within 500 ms, the test does fail by receiving stale cached A; outside that timing window it hangs. It also never explicitly tests the promised post-A2 recent-cache behavior.  
  **Fix:** return a settled sentinel for A4, assert `r4.source === "shared"`, then make a controlled-time fifth request and assert `{source:"cache"}` with `"fresh"`.

Coordinator implementation itself is sound for the intended single-consumer/remount model: lone requests and unsuperseded shared borrowers apply; stale generations cannot clear a newer slot; stale completions cannot corrupt `lastResponse`; the recent-cache branch remains valid. Existing tests are statically compatible. Search generation/query guards prevent stale response/error application, including debounce-time query changes; `getDirectLink` is not newly corrupted. No evident type error.

**Verdict: FIX-FIRST** — address the stuck loading state before shipping. Static review only; no tests or services run.