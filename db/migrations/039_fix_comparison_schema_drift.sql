-- Migration 039: Restore ndd_database_comparison schema after dbWriteTable drift
--
-- Issue: On databases whose ndd_database_comparison table was (re)created by a
-- dbWriteTable-style restore rather than by migration 009, the schema drifts:
-- comparison_id becomes DOUBLE (a PRIMARY KEY *without* AUTO_INCREMENT), the
-- text columns collapse to narrow auto-sized VARCHARs (e.g. version VARCHAR(34),
-- publication_id VARCHAR(341)), and the `granularity` column is dropped
-- entirely. The comparisons refresh then fails with either:
--   - "Data too long for column 'version'/'publication_id'/..." (narrow VARCHARs), or
--   - a PRIMARY KEY violation, because comparisons_update_async() relies on
--     AUTO_INCREMENT to assign comparison_id for the per-list re-insert.
--
-- Migration 012 already widened these columns but is a no-op once its ledger row
-- exists, so a restore performed *after* 012 reintroduces the drift. This
-- migration re-asserts the intended migration-009/012 schema idempotently
-- (safe no-op on databases that already match).
--
-- Non-destructive: MODIFY preserves existing rows; comparison_id DOUBLE values
-- (1.0, 2.0, ...) convert cleanly to INT and AUTO_INCREMENT resumes from MAX+1.
--
-- Idempotent: guarded by an INFORMATION_SCHEMA check for the dropped column,
-- and MODIFY is a no-op when the type already matches.
--
-- Related: #158 (migration 012), comparison-source repair (#502).

DELIMITER //

DROP PROCEDURE IF EXISTS migrate_039_fix_comparison_schema_drift //

CREATE PROCEDURE migrate_039_fix_comparison_schema_drift()
BEGIN
    -- Re-add granularity if a dbWriteTable restore dropped it (matches
    -- migration 009 step 2).
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'ndd_database_comparison'
          AND COLUMN_NAME = 'granularity'
    ) THEN
        ALTER TABLE ndd_database_comparison
          ADD COLUMN granularity TEXT NULL COMMENT 'Data granularity description for source';
    END IF;

    -- Re-assert the intended migration-009/012 column types in one rebuild.
    ALTER TABLE ndd_database_comparison
      MODIFY COLUMN comparison_id         INT          NOT NULL AUTO_INCREMENT COMMENT 'Auto-increment primary key',
      MODIFY COLUMN symbol                VARCHAR(50)  NULL COMMENT 'Gene symbol (uppercase)',
      MODIFY COLUMN hgnc_id               VARCHAR(20)  NULL COMMENT 'HGNC ID with prefix (e.g., HGNC:12345)',
      MODIFY COLUMN disease_ontology_id   TEXT         NULL COMMENT 'Disease ID (OMIM:123456, ORPHA:1234, MONDO:0001234)',
      MODIFY COLUMN disease_ontology_name TEXT         NULL COMMENT 'Disease name from source',
      MODIFY COLUMN inheritance           TEXT         NULL COMMENT 'Mode of inheritance term(s)',
      MODIFY COLUMN category              VARCHAR(100) NULL COMMENT 'Confidence/evidence category from source',
      MODIFY COLUMN pathogenicity_mode    TEXT         NULL COMMENT 'Pathogenicity mechanism/mode',
      MODIFY COLUMN phenotype             TEXT         NULL COMMENT 'HPO terms or phenotype description',
      MODIFY COLUMN publication_id        TEXT         NULL COMMENT 'Publication IDs (PMIDs)',
      MODIFY COLUMN list                  VARCHAR(50)  NOT NULL COMMENT 'Source database name',
      MODIFY COLUMN version               VARCHAR(500) NULL COMMENT 'Source version/date (can be long path/description)',
      MODIFY COLUMN granularity           TEXT         NULL COMMENT 'Data granularity description for source';
END //

CALL migrate_039_fix_comparison_schema_drift() //

DROP PROCEDURE IF EXISTS migrate_039_fix_comparison_schema_drift //

DELIMITER ;
