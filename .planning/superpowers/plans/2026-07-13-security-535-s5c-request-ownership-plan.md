# #553 S5c Frontend Request Ownership Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: superpowers:test-driven-development. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ensure only a read request that still owns a consumer's latest intent may update reactive data, error, busy/loading flags, browser state, or deferred callbacks.

**Architecture:** Follow S5/S5b's two-level model. Each composable owns a monotonic instance generation plus its own `AbortController`; starting a newer logical read aborts and invalidates the old one, and every success/catch/finally/deferred callback checks ownership. Shared transports retain their own slot identity: `useUserData` stores pending promises by parameter key and every subscribing instance applies only when its local generation/params are current; `tableRequestCoordinator` gives each caller a consumer generation rather than using its global transport generation as consumer identity.

**Tech Stack:** Vue 3 composables, typed `@/api/*` clients, AbortController, Vitest/MSW.

---

## Invariants

- No raw axios or direct `localStorage.token` / `localStorage.user` access.
- Capture identity before every await; stale success, catch, finally, `nextTick`, and abort cleanup are no-ops for consumer state.
- Abort is best-effort only; generation/slot checks remain the correctness boundary.
- A shared in-flight transport may serve multiple current consumers, but a transport completion may not clear/replace a newer transport slot.
- Tests use deferred promises and resolve obsolete work after the newer intent; no sleep-based race tests.
- Keep every touched source and test below 600 lines. Extract a cohesive test fixture/helper only if a target approaches the ceiling.

## Task 1: Plan review before production edits

**Files:**
- Create: `.planning/reviews/2026-07-13-security-535-s5c-request-ownership-plan-codex-review.md`

- [ ] Run a background, xhigh, read-only Codex plan review against this plan, the S5/S5b plans/reviews, and the nine target files.
- [ ] Fold any BLOCKER/HIGH and inexpensive MEDIUM/LOW into this plan before tests or production code.

## Task 2: `useUserData` params-keyed shared transport

**Files:**
- Modify: `app/src/views/admin/composables/useUserData.ts`
- Test: `app/src/views/admin/composables/__tests__/useUserData.spec.ts`

- [ ] Add RED tests for two mounted/live instances requesting the same params: exactly one typed-client request, both current subscribers receive the result, and neither instance remains busy.
- [ ] Add RED tests for A-B-A and stale rejection/finally while the newer request remains pending; prove a stale request cannot clear the new slot, cache, busy flag, or URL.
- [ ] Replace `moduleApiCallInProgress`/single-param bookkeeping with a module `Map<string, Promise<UserTableResponse>>` and per-param latest-start sequence/cache metadata. A new transport records itself only if it still owns its keyed slot; stale completion cannot delete or cache over a newer same-param transport.
- [ ] Each `useUserData()` instance retains its own intent generation and params predicate. A shared promise is subscribed to rather than silently returning; success/catch/finally, `nextTick(currentPage)`, and cache apply require that local predicate.
- [ ] Run the targeted spec GREEN.

## Task 3: Cross-instance table transport ownership

**Files:**
- Modify: `app/src/utils/tableRequestCoordinator.ts`
- Test: `app/src/utils/tableRequestCoordinator.spec.ts`

- [ ] Add RED tests with two distinct consumers sharing params: a later request from consumer B must not suppress still-current A; both apply the shared response exactly once.
- [ ] Add RED tests for one consumer changing params while another stays current, and for stale shared rejection; only the stale consumer is suppressed and the new slot is not cleared.
- [ ] Separate transport-slot generation (network/cache mutation) from caller-owned request generation. The coordinator keeps one shared in-flight slot but creates a per-caller token, and checks that token plus `isCurrent(params)` around apply/onError.
- [ ] Run the coordinator spec GREEN.

## Task 4: Entity and review workflow reads

**Files:**
- Modify: `app/src/views/curate/composables/useEntityInfo.ts`
- Test: `app/src/views/curate/composables/__tests__/useEntityInfo.spec.ts`
- Modify: `app/src/views/review/composables/useReviewData.ts`
- Test: `app/src/views/review/composables/__tests__/useReviewData.spec.ts`

- [ ] Add deferred A-B-A tests for entity, review, and status loads. Resolve the original request last and assert no mixed entity/review/status model, no stale clear/reset, and no stale error toast.
- [ ] Add per-read generation + AbortController state. Start a new logical read by aborting and superseding the previous controller; pass `signal` through the existing typed clients. Guard every multi-call `useEntityInfo.loadReview()` mutation as one atomic snapshot.
- [ ] In `useReviewData`, independently own table, option-list, entity, review-info, and status-info request families. Guard `isBusy`, `loading`, `loading_status_modal`, reactive-object assignment, option clears, and errors. `resetEntityContext()` invalidates its entity/review generations.
- [ ] If `useReviewData.ts` approaches 600 lines, move only the request-owner helper/types to an explicitly imported sibling file; preserve its public composable API.
- [ ] Run both targeted specs GREEN.

## Task 5: Per-gene, trend, network, and PubTator admin reads

**Files:**
- Modify: `app/src/composables/usePubtatorGenePublications.ts`
- Test: `app/src/composables/usePubtatorGenePublications.spec.ts`
- Modify: `app/src/views/admin/composables/useAdminTrendData.ts`
- Create: `app/src/views/admin/composables/useAdminTrendData.spec.ts`
- Modify: `app/src/composables/useNetworkData.ts`
- Test: `app/src/composables/useNetworkData.spec.ts`
- Modify: `app/src/composables/usePubtatorAdmin.ts`
- Create: `app/src/composables/usePubtatorAdmin.spec.ts`

- [ ] Add RED tests that supersede a gene/publication read via `resetCache()`/same-gene refetch; stale success, catch, and finally cannot repopulate cache, clear a newer controller, or stop its spinner.
- [ ] Add RED trend/network/admin-status tests with deferred typed-client promises: B wins over A; A's success/catch/finally cannot clear B's data/loading/error/controller. Test actual abort cleanup where a controller exists.
- [ ] Give each logical key/request family its own generation and controller. `useNetworkData` preserves the global preload promise as the transport slot but races a local abort signal and gates consumer refs/loading by its per-instance generation; cancelling one consumer must not abort the shared preload for another.
- [ ] Run all four targeted specs GREEN.

## Task 6: `useOntologyAdminTable` deferred page ownership

**Files:**
- Modify: `app/src/views/admin/composables/useOntologyAdminTable.ts`
- Test: `app/src/views/admin/ManageOntology.spec.ts`

- [ ] Add a RED deferred-response test: request page A, start page B, resolve A last, then flush `nextTick`; A must not assign B's `currentPage`, cursors, rows, busy flag, or URL.
- [ ] Capture a local table-load generation at intent scheduling, pass its ownership predicate into `applyApiResponse`, and recheck it inside the deferred `nextTick(currentPage)` assignment. `doLoadData` passes the same predicate to coordinator apply/error and clears busy only for its own current intent.
- [ ] Run the focused ManageOntology spec GREEN.

## Task 7: Final verification, adversarial review, and stacked PR

- [ ] Run all targeted specs, `make code-quality-audit`, `make lint-app`, `cd app && npm run type-check:strict`, `cd app && npm run test:unit`, and `git diff --check` with fresh output.
- [ ] Run a background deep xhigh Codex diff review. Fold all BLOCKER/HIGH and inexpensive MEDIUM/LOW test-first; repeat until no BLOCKER/HIGH remains. Commit the concise round/verdict record to `.planning/reviews/2026-07-13-security-535-s5c-request-ownership-diff-codex-review.md`.
- [ ] After a final `git status -sb`, commit on `fix/535-s5c-request-ownership`, push, and create one PR with base `fix/535-composables-bundle-budget`, `Closes #553`, and `Refs #535` on separate lines. Do not merge.

## Self-review

- Scope coverage: `useUserData` map → Task 2; coordinator cross-instance semantics → Task 3; entity/review ownership → Task 4; remaining four read composables → Task 5; ontology deferred page write → Task 6.
- No new public APIs or raw transport boundary are proposed; implementation is restricted to typed existing clients and S5/S5b identity patterns.
- Every async mutation class named by the issue—success, error, finally, abort cleanup, shared subscriber, and deferred callback—has a deterministic test task.
