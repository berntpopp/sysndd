# Playwright fixtures (CI-only)

Files in this directory are sourced by `make playwright-stack` only.
They MUST NOT be referenced from `db/migrations/`, `db/data/`, or
production migration paths.

CI greps `db/migrations/` for `playwright_users` and fails the build if
any production migration references this fixture.

## Files

- `playwright_users.sql` — provisions the four deterministic test users
  (`pw_admin`, `pw_curator`, `pw_reviewer`, `pw_user`) used by the Playwright
  suite. Plaintext passwords for these accounts are committed in
  `app/tests/e2e/fixtures/test-users.ts` because the accounts only exist in
  the isolated `playwright` compose project.
- `playwright_e2e_baseline.sql` — the shared E2E baseline fixture. Provisions a
  small self-contained set of genes (CHD8/ARID1B/NAA10/SCN2A), one CHD8
  entity/review/status chain, a re-review assignment, and simplified copies of
  the heavy production read views so the fixture surfaces through the app. This
  gives the data-dependent baseline specs (public table filters, curation
  comparisons, gene-detail cards, slow-provider resilience, Modify Entity) rows
  to assert against. Also used by the documentation screenshot lane
  (`make docs-screenshots`), which layers no extra data on top. (Formerly
  `playwright_docs_screenshots.sql`.)

## When these fixtures are applied

The fixtures are sourced by `make playwright-stack` AFTER the API has applied
its migrations. The `user` table is created during API startup (by
`db/migrations/000_initialize_base_schema.sql`), not at MySQL init time, so
seeding via `/docker-entrypoint-initdb.d/` is too early. The Makefile target
waits for `/api/health/ready` to return 200, then runs
`mysql < playwright_users.sql` followed by `mysql < playwright_e2e_baseline.sql`.

Both fixtures are also re-seeded by `app/tests/e2e/global-setup.ts` before every
`npx playwright test` run (via the `_playwright-seed-users` /
`_playwright-seed-e2e-baseline` make targets), so each run starts from a known
state even after a spec mutates a row.
