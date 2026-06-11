-- 028_add_db_version.sql
--
-- Issue #22: Track the SysNDD database version with semantic versioning in a
-- dedicated, human-facing table and expose it in the App and API.
--
-- This is intentionally SEPARATE from the migration runner's `schema_version`
-- ledger (which records one row per applied migration file for at-most-once
-- semantics) and from `about_content.version` (About-page CONTENT publish
-- versioning). Neither is a human-facing semantic version of the DB schema +
-- seed data, which is what this table provides.
--
-- The table holds a single "current" row (id = 1):
--   * db_version  -- semantic version (major.minor.patch) of the DB
--   * db_commit   -- last db/ folder related git commit short hash; captured at
--                    release time (see db/scripts/update-db-version.sh) and
--                    upserted by the API at startup from DB_VERSION / DB_COMMIT
--                    env vars when present. 'unknown' when not yet captured.
--   * description -- short human-readable note for this DB version
--   * applied_at  -- when this version row was first seeded (immutable)
--   * updated_at  -- last time the row was refreshed (e.g. commit injection)
--
-- The CHECK on id keeps the table single-row by convention; the API and the
-- release helper both target id = 1.
--
-- Idempotent: CREATE TABLE IF NOT EXISTS + INSERT IGNORE so re-running is safe.

CREATE TABLE IF NOT EXISTS `db_version` (
  `id`          TINYINT UNSIGNED NOT NULL DEFAULT 1,
  `db_version`  VARCHAR(20)  NOT NULL,
  `db_commit`   VARCHAR(40)  NOT NULL DEFAULT 'unknown',
  `description` VARCHAR(255) NULL DEFAULT NULL,
  `applied_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at`  DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  CONSTRAINT `chk_db_version_single_row` CHECK (`id` = 1)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4;

-- Seed the current DB version. The version below mirrors the schema + seed-data
-- state at this migration. Bump it (and add a new migration) when the DB
-- structure or core seed data changes meaningfully.
INSERT IGNORE INTO `db_version` (`id`, `db_version`, `db_commit`, `description`)
VALUES (1, '1.0.0', 'unknown', 'Initial tracked SysNDD database version (issue #22).');
