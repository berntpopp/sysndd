# #553 S5c Codex plan review

**Reviewer:** Codex, xhigh, read-only, master-based bounded pass.

**Initial verdict:** `FIX-FIRST` — BLOCKER/HIGH remaining: yes.

## Findings folded before implementation

1. `useEntityInfo.reset()` must abort/invalidate entity, review, and status work; otherwise a
   pending request can repopulate the cleared form. Added reset-while-pending success/rejection tests.
2. `useReviewData.resetEntityContext()` must also abort/invalidate `loadStatusInfo` and reset its
   modal spinner. Each option-list loader gets its own owner because phenotype, variation, and status
   lists load concurrently; a shared owner would suppress valid results. Added concurrent-list and
   current/stale status-rejection coverage.
3. The Ontology test must let A queue its deferred `currentPage` write before B supersedes it; a
   merely stale network response never enters `applyApiResponse` and cannot expose the bug.
4. `useNetworkData.clearNetworkData()` is a superseding intent: it must invalidate/detach its local
   consumer while retaining the shared preload for another instance. Added the two-instance test.
5. `usePubtatorGenePublications.cancelAll()` followed by same-gene refetch needs a slot-ownership
   test, not only `resetCache()` coverage.
6. `loadStatusInfo` needs a current-rejection spinner test plus a stale-rejection no-op test.

All plan findings are folded into the implementation plan above. Production edits begin only with
test-first RED cases for these corrected invariants.
