# PR 1 Curation/Admin Design Reevaluation

Date: 2026-05-13

Scope: shared authenticated shell usage, footer-safe scroll spacing, and local Playwright design regression coverage.

Screenshots: `.planning/screenshots/2026-05-13-curation-admin-pr1-reevaluation/`

## Verification

Passed:

- `make lint-app`
- `cd app && npm run type-check`
- `cd app && npm run type-check:strict`
- `cd app && npm run test:unit`
- `PLAYWRIGHT_BASE_URL=http://127.0.0.1:5174 cd app && npx playwright test tests/e2e/authenticated-admin-curation-design.spec.ts`

Notes:

- The default Playwright global setup still reports `make _playwright-seed-users` cannot find the isolated `playwright` compose `mysql` service when run against the already-running local dev stack. The deterministic `pw_*` users were seeded into the active local dev DB before the Playwright run.
- The local Playwright run used the worktree Vite server at `http://127.0.0.1:5174` and the active local API behind Traefik.

## Route Scores

| Route | Before | After PR 1 | Notes |
|---|---:|---:|---|
| `/CreateEntity` | 3 | 4 | Now uses the authenticated shell and footer-safe scroll; wizard spacing still needs PR 4 refinement. |
| `/ModifyEntity` | 2 | 3 | Shell and heading hierarchy improved; legacy nested search/action cards remain for PR 4. |
| `/ApproveReview` | 2 | 3 | Shell and footer safety added; table/mobile-row redesign remains for PR 2. |
| `/ApproveStatus` | 2 | 3 | Shell and footer safety added; table/mobile-row redesign remains for PR 2. |
| `/ApproveUser` | 2 | 3 | Shell and heading hierarchy improved; compact mobile user rows remain for PR 2. |
| `/ManageReReview` | 2 | 3 | Shell and heading hierarchy improved; workflow separation remains for PR 4. |
| `/ManageUser` | 2 | 3 | Shell and footer safety added; admin table/mobile-row redesign remains for PR 2. |
| `/ManageAnnotations` | 3 | 3 | Shell added; operation board redesign remains for PR 5. |
| `/ManageOntology` | 2 | 3 | Shell and heading hierarchy improved; compact ontology rows remain for PR 3. |
| `/ManageAbout` | 2 | 3 | Shell and heading hierarchy improved; CMS layout remains for PR 5. |
| `/ViewLogs` | 3 | 3 | Shell added; log table/mobile-row redesign remains for PR 3. |
| `/AdminStatistics` | 4 | 4 | Shell and footer safety added; filter/header compression remains for PR 5. |
| `/ManageBackups` | 3 | 3 | Shell added; safer operation panels and mobile rows remain for PR 3. |
| `/ManagePubtator` | 2 | 3 | Shell added; operation-panel redesign remains for PR 5. |
| `/ManageLLM` | 3 | 3 | Duplicate heading removed and shell added; dashboard panel redesign remains for PR 5. |

## Remaining Design Debt

- Approval, user, ontology, log, and backup tables still use legacy table/card structures and need the planned `TableShell` and mobile-row work.
- Curation workflow forms still use legacy nested card sections; PR 4 should handle layout and state presentation.
- Admin operation pages still need grouped operation panels, safer destructive zones, and dashboard/table-specific refinements.
- The fixed-name Docker containers prevent `make playwright-stack` from running alongside the existing local dev stack; this PR verifies the spec against a worktree Vite server plus the active local API instead.
