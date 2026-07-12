# #553 S5c request ownership — final Codex diff review

Scope: the complete `fix/535-s5c-request-ownership` diff against `master`.

## Rounds to merge bar

1. Initial deep review found per-table unmount/deferred callback gaps, shared network-consumer cleanup gaps, stale PubTator feedback, and reset/state ownership gaps.
2. Review found a typed `NetworkMetadata` fixture compile blocker, modal A→B ownership gap, and remaining mount-time deferred callbacks. These were covered with deterministic tests and fixed.
3. Review found the remaining HIGH: a modal generation guard could not prevent an already-started `useReviewForm.loadReviewData()` or `useStatusForm.loadStatusData()` from mutating shared form state after B had won. Direct form A→B tests failed RED (A overwrote B), then passed after loader-level generation/abort ownership and reset invalidation were added. The same pass added a deterministic queued-idle-hydration-after-unmount regression test.
4. Final xhigh review found no BLOCKER/HIGH defects. It verified typed-client signals, form loader generation/reset/finally behavior, child-loader A→B sequencing, table ownership, and network idle-callback cleanup.

Final reviewer verdict:

> No BLOCKER/HIGH defect found; focused Vitest execution is environment-blocked.

`BLOCKER/HIGH remaining: no`

The reviewer was correctly unable to start Vitest in its read-only sandbox because Vite could not create `.vite-temp`; the identical focused tests and full unit suite were run successfully in the writable worktree.

Raw prompts and outputs are retained alongside this summary as `*-diff-codex-*.md` and `*-diff-codex-*.txt`.
