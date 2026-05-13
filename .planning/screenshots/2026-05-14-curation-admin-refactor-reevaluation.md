# Curation/Admin Refactor Reevaluation - 2026-05-14

## Scores

| Route | Before | After | Notes |
|---|---:|---:|---|
| `/CreateEntity` | 3 | 4 | Authenticated shell, tighter wizard controls, switch-style yes/no, improved review step. |
| `/ModifyEntity` | 2 | 4 | Search/selection and inline workflows now use compact entity context and detail-page-style chips. |
| `/ApproveReview` | 2 | 4 | Duplicate route title removed; approval table/header/action sizing aligned with shared visual language. |
| `/ApproveStatus` | 2 | 4 | Duplicate route title removed; status approval table follows the same approval surface. |
| `/ApproveUser` | 2 | 4 | User table and mobile rows modernized with consistent table/action styling. |
| `/ManageReReview` | 2 | 3.5 | Submissions table is now primary; create/manual assignment are secondary collapsed panels; batch form still has remaining complexity. |
| Admin operation routes | 2-4 | 3.5-4 | Authenticated shells, footer safety, and table/operation surface consistency improved. |

## Screenshots

- `.planning/screenshots/2026-05-13-curation-admin-live-review/`
- `.planning/screenshots/2026-05-13-curation-admin-pr4-reevaluation/`
- `.planning/screenshots/2026-05-14-create-entity-review-audit/`
- `.planning/screenshots/2026-05-14-manage-rereview-audit/`

## Checks

- `make lint-app`: passed, with existing warnings.
- `cd app && npm run type-check`: passed.
- `cd app && npm run type-check:strict`: passed.
- `cd app && npm run test:unit`: passed, `154` files, `1124` tests, `2` todo.
- `make ci-local`: passed. R test output includes existing skipped tests and warnings for optional packages/live services.
- Local Playwright screenshot audit for `/ManageReReview`: passed with zero captured console errors and no horizontal overflow at `1440x900` or `390x844`.

## Remaining Design Debt

- `/ManageReReview` batch creation remains a dense specialist form; it is improved but should eventually become a clearer guided criteria builder.
- Some curation/admin views still use local table wrappers instead of fully sharing `TableShell` internals.
- Lint warnings pre-exist in several admin/curation files, mostly `any` usage and test helper structure.
