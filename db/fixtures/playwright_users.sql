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
--   Rscript -e 'for (u in c("admin","curator","reviewer","user")) { \
--     cat(u, ":", sodium::password_store(paste0("playwright_", u, "_pw_2026")), "\n", sep="") \
--   }'
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
    '$7$C6..../....oQfpqYXzkBj6QtOFLN6XVLPEW7M3cTcSnmlbT5xsEdA$je0ZsWWNhbj7V8qyKrvDC5tPTEQDlrhTZY4r5tDKF2A',
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
    '$7$C6..../....n5sFIR4fD9dNs43RZ21L/nNL8JGObSowUI19jOKBxgA$9gJMwP17wOUoQsgGyueM9fYNasTDagSvPtPK27yAq//',
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
    '$7$C6..../....7/D/UIV2lUhIzigjj6rH2B70cwIq3OftDvCW22pFxKB$MU1ZI4x4wW6DiaOXqqVtiLog3WDCEJ2QfJhClU4cASD',
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
    '$7$C6..../....wKLAMXWWH7GE/gBqGM8qzLzKmxmPmcxLy47d95DPYe9$V.otZzT0hZ1H/us1Ia0NQSX.67KovkNPODrG4vQqAa1',
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
