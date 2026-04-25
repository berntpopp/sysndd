-- db/fixtures/playwright_users.sql
-- Playwright-only test users. Sourced by `make playwright-stack` AFTER the
-- API has applied its migrations (the `user` table is created mid-startup,
-- not at MySQL init time). NEVER source from production migrations.
-- Plaintext passwords for these accounts are committed in
-- app/tests/e2e/fixtures/test-users.ts because these accounts only exist in
-- the isolated `playwright` compose project.
--
-- Password format: sodium scrypt ($7$...) hashes generated via
-- `sodium::password_store()` — see api/core/security.R for the verification
-- pathway. Hashes were generated with this command (run on the host once):
--
--   Rscript -e 'for (u in c("Admin","Curator","Reviewer","User")) { \
--     cat(u, ":", sodium::password_store(paste0("Pw_", u, "!2026")), "\n", sep="") \
--   }'
--
-- The plaintext passwords intentionally satisfy the API's password
-- complexity rule (>=8 chars, upper, lower, digit, [!@#$%^&*]) so the
-- auth.password-update spec can both mutate and restore them via
-- /api/user/password/update without falling back to a slow mysql reseed.
--
-- The hashes below are reproducible verification targets but the salt is
-- random; regenerating produces different hash strings that all validate
-- against the same plaintext. Keep these literal hashes in sync with the
-- plaintext in app/tests/e2e/fixtures/test-users.ts.

INSERT INTO `user` (
  `user_name`,
  `password`,
  `email`,
  `abbreviation`,
  `first_name`,
  `family_name`,
  `user_role`,
  `comment`,
  `terms_agreed`,
  `approved`,
  `rereview_request`
) VALUES
  (
    'pw_admin',
    '$7$C6..../....n9sAMSCsBeiu0ZVg3OMM/0xxwiVlq/1Io2rX/vmcye7$25Bm/HgbAQoapG47nIRWX/9Jq/enz1zVfZdnsRjPLnB',
    'pw_admin@example.test',
    'PWA',
    'PW',
    'Admin',
    'Administrator',
    'Playwright test fixture user (Wave 0, v11.1)',
    1,
    1,
    0
  ),
  (
    'pw_curator',
    '$7$C6..../....d35k4LLPCBsrRsmV/d.7L9UM6P2CeelS4Q/wq5Tz.g/$R.q8.l2OvxA1K9dP.ZPOlDBRBFioZpKNEUAkq1fDMk9',
    'pw_curator@example.test',
    'PWC',
    'PW',
    'Curator',
    'Curator',
    'Playwright test fixture user (Wave 0, v11.1)',
    1,
    1,
    0
  ),
  (
    'pw_reviewer',
    '$7$C6..../....bRUA4kUtW/1vZ6DXWvJe5fD/FVR629SviSYGPW2mw33$iiuzpAdrOH693tt7PHha1RJIMFOwgrco1ITpnDYSEMC',
    'pw_reviewer@example.test',
    'PWR',
    'PW',
    'Reviewer',
    'Reviewer',
    'Playwright test fixture user (Wave 0, v11.1)',
    1,
    1,
    0
  ),
  (
    'pw_user',
    '$7$C6..../....KVbbJr8T6b0kUHDRjOYciv2/4cqr8NV4b.VKo0AgvtD$WyDJLFAVDxLr6tDia2n5rp6z8FDiIdP5Gzr6YtG0n/9',
    'pw_user@example.test',
    'PWV',
    'PW',
    'User',
    'Viewer',
    'Playwright test fixture user (Wave 0, v11.1)',
    1,
    1,
    0
  )
ON DUPLICATE KEY UPDATE
  `password` = VALUES(`password`),
  `email` = VALUES(`email`),
  `user_role` = VALUES(`user_role`),
  `approved` = VALUES(`approved`),
  `terms_agreed` = VALUES(`terms_agreed`);
