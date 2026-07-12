# #553 S5c request-ownership plan review

Perform a deep xhigh adversarial **plan** review only. Do not edit files. The approved scope is
exactly the #553 S5c plan at
`.planning/superpowers/plans/2026-07-13-security-535-s5c-request-ownership-plan.md`.

Read that plan, current target code/tests, and the shipped S5/S5b records:

- `.planning/superpowers/plans/2026-07-12-security-535-s5b-resource-ownership-plan.md`
- `.planning/reviews/2026-07-13-security-535-s5b-diff-codex-review.md`

Targets:

- `useUserData`: params-keyed shared in-flight transport map with independent subscribing
  instances.
- `tableRequestCoordinator`: cross-instance consumer ownership separate from its shared transport.
- `useEntityInfo`, `useReviewData`, `usePubtatorGenePublications`, `useAdminTrendData`,
  `useNetworkData`, `usePubtatorAdmin`: generation/slot ownership plus abort protection.
- `useOntologyAdminTable`: deferred `currentPage` ownership.

The solution must use existing typed `@/api/*` clients only (no raw axios/localStorage), preserve
public composable APIs, keep source/test files under 600 lines, and add deterministic deferred
A-B-A/out-of-order tests for stale success, catch, finally, abort cleanup, cross-instance shared
subscribers, and page reset. Abort is optimization; ownership checks establish correctness.

Attack the plan for stale overwrites, cross-instance suppression, same-param A-B-A slot corruption,
controller deletion/abort races, unmount/reset and `nextTick` writes, shared preloads, cache poisoning,
unhandled stale errors, URL/busy regressions, test vacuity, and implementation-size risks. Expand to
adjacent same-class races in these exact files only. Classify every finding BLOCKER/HIGH/MEDIUM/LOW.
End exactly with `Verdict: <SHIP|FIX-FIRST>` and state whether any BLOCKER or HIGH remains.
