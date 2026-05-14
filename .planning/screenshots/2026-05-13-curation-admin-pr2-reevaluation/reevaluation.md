# PR 2 Curation/Admin Design Reevaluation

Date: 2026-05-13

Scope: approval/user-management `TableShell` surfaces, compact mobile rows, and approval/user table pagination/filter behavior preservation.

Screenshots: `.planning/screenshots/2026-05-13-curation-admin-pr2-reevaluation/`

## Verification

Passed:

- `make lint-app`
- `cd app && npm run type-check`
- `cd app && npm run type-check:strict`
- `cd app && npm run test:unit`
- `PLAYWRIGHT_BASE_URL=http://127.0.0.1:5173 cd app && npx playwright test tests/e2e/authenticated-admin-curation-design.spec.ts`

Notes:

- The Playwright global setup still reports `make _playwright-seed-users` cannot find the isolated compose `mysql` service when pointed at the already-running local dev stack. The deterministic `pw_*` users were seeded into the active local dev DB before the Playwright run.
- The local Playwright run used the worktree Vite server at `http://127.0.0.1:5173` and the active local API behind Traefik.
- `make lint-app` exits 0 with existing warning-level findings; new generic mobile-row components keep the same flexible item typing pattern as the surrounding table code.

## Route Scores

| Route | Before PR 2 | After PR 2 | Notes |
|---|---:|---:|---|
| `/CreateEntity` | 4 | 4 | Unchanged in PR 2; wizard/form polish remains for PR 4. |
| `/ModifyEntity` | 3 | 3 | Unchanged in PR 2; search/action card consolidation remains for PR 4. |
| `/ApproveReview` | 3 | 4 | Uses `TableShell`, compact mobile rows, table-level title no longer duplicates the shell heading, and review/status actions remain separate. |
| `/ApproveStatus` | 3 | 4 | Uses `TableShell` through the shared approval table and compact mobile approval rows. |
| `/ApproveUser` | 3 | 4 | Uses `TableShell`, mobile user-application rows, and mobile pagination aligned with desktop pagination. |
| `/ManageReReview` | 3 | 3 | Unchanged in PR 2; workflow separation remains for PR 4. |
| `/ManageUser` | 3 | 4 | Uses `TableShell` and compact admin user mobile rows while preserving selection/edit/delete behavior. |
| `/ManageAnnotations` | 3 | 3 | Unchanged in PR 2; operation board redesign remains for PR 5. |
| `/ManageOntology` | 3 | 3 | Unchanged in PR 2; compact ontology rows remain for PR 3. |
| `/ManageAbout` | 3 | 3 | Unchanged in PR 2; CMS layout remains for PR 5. |
| `/ViewLogs` | 3 | 3 | Unchanged in PR 2; log table/mobile-row redesign remains for PR 3. |
| `/AdminStatistics` | 4 | 4 | Unchanged in PR 2; dashboard refinements remain for PR 5. |
| `/ManageBackups` | 3 | 3 | Unchanged in PR 2; safer operation panels and mobile rows remain for PR 3. |
| `/ManagePubtator` | 3 | 3 | Unchanged in PR 2; operation-panel redesign remains for PR 5. |
| `/ManageLLM` | 3 | 3 | Unchanged in PR 2; dashboard panel redesign remains for PR 5. |

## Remaining Design Debt

- Admin ontology, log, and backup table surfaces still need PR 3 `TableShell` and compact mobile-row treatment.
- Curation workflow forms still use legacy nested card sections; PR 4 should handle layout density, state presentation, and form controls.
- Admin operation pages still need grouped operation panels, safer destructive zones, and dashboard/table-specific refinements in PR 5.
- The local Playwright stack target remains blocked by fixed-name containers in this environment, so design checks continue to run against the worktree Vite server plus the active local API.
