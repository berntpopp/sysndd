# PR 3 Curation/Admin Design Reevaluation

Date: 2026-05-13

Scope: admin ontology, logs, and backup table surfaces with compact mobile rows, mobile sorting, and clearer backup danger confirmations.

Screenshots: `.planning/screenshots/2026-05-13-curation-admin-pr3-reevaluation/`

## Verification

Passed:

- `make lint-app`
- `cd app && npm run type-check`
- `cd app && npm run type-check:strict`
- `cd app && npm run test:unit`
- `PLAYWRIGHT_BASE_URL=http://127.0.0.1:5173 cd app && npx playwright test tests/e2e/authenticated-admin-curation-design.spec.ts`

Notes:

- The Playwright global setup still reports the isolated compose `mysql` service is not running when the spec targets the active local dev stack. The deterministic `pw_*` users were seeded into the active local dev DB before the Playwright run and removed afterward.
- The duplicate-heading regression check was tightened to catch singular/plural variants. The approval, user, ontology, and entries-over-time surfaces now use distinct route and section titles.

## Route Scores

| Route | Before PR 3 | After PR 3 | Notes |
|---|---:|---:|---|
| `/CreateEntity` | 4 | 4 | Unchanged in PR 3; wizard/form polish remains for PR 4. |
| `/ModifyEntity` | 3 | 3 | Unchanged in PR 3; search/action card consolidation remains for PR 4. |
| `/ApproveReview` | 4 | 4 | Section title changed to `Review Queue` to avoid repeated route heading. |
| `/ApproveStatus` | 4 | 4 | Section title changed to `Status Queue` to avoid repeated route heading. |
| `/ApproveUser` | 4 | 4 | Section title changed to `Application Queue`; table/mobile refactor remains intact. |
| `/ManageReReview` | 3 | 3 | Unchanged in PR 3; workflow separation remains for PR 4. |
| `/ManageUser` | 4 | 4 | Unchanged in PR 3. |
| `/ManageAnnotations` | 3 | 3 | Unchanged in PR 3; operation board redesign remains for PR 5. |
| `/ManageOntology` | 3 | 4 | Uses `TableShell`, compact ontology mobile rows, mobile sort control, and non-duplicative `Variation Terms` section title. |
| `/ManageAbout` | 3 | 3 | Unchanged in PR 3; CMS layout remains for PR 5. |
| `/ViewLogs` | 3 | 4 | Uses `TableShell`, compact log mobile rows, mobile sort, mobile loading state, and mobile access to hidden column filters. |
| `/AdminStatistics` | 4 | 4 | Unchanged in PR 3; dashboard refinements remain for PR 5. |
| `/ManageBackups` | 3 | 4 | Uses `TableShell`, compact backup mobile rows, mobile sort/loading state, and clearer restore/delete danger modals. |
| `/ManagePubtator` | 3 | 3 | Unchanged in PR 3; operation-panel redesign remains for PR 5. |
| `/ManageLLM` | 3 | 3 | Unchanged in PR 3; dashboard panel redesign remains for PR 5. |

## Remaining Design Debt

- Curation workflow forms still need PR 4 layout work: `CreateEntity`, `ModifyEntity`, and `ManageReReview`.
- Admin operation pages still need PR 5 grouped operation panels and dashboard-specific refinements.
- Some warning-level lint debt remains in pre-existing frontend files and generic mobile row item typing, but lint exits 0.
