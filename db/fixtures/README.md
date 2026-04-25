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

## When this fixture is applied

The fixture is sourced by `make playwright-stack` AFTER the API has applied
its migrations. The `user` table is created during API startup (by
`db/migrations/000_initialize_base_schema.sql`), not at MySQL init time, so
seeding via `/docker-entrypoint-initdb.d/` is too early. The Makefile target
waits for `/api/health/ready` to return 200, then runs `mysql < playwright_users.sql`.
