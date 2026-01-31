# Make Migration 002 Idempotent

**Priority:** Low
**Category:** Infrastructure / Database
**Created:** 2026-01-28
**Status:** Backlog
**Source:** Code audit of HGNC update pipeline (I6)

## Problem

`db/migrations/002_add_genomic_annotations.sql` uses plain `ALTER TABLE ... ADD COLUMN` statements without `IF NOT EXISTS` guards:

```sql
ALTER TABLE non_alt_loci_set ADD COLUMN gnomad_constraints TEXT NULL;
ALTER TABLE non_alt_loci_set ADD COLUMN alphafold_id VARCHAR(100) NULL;
```

Running this migration twice will fail with "Duplicate column name". Migration 003 uses the correct idempotent stored procedure pattern, but migration 002 does not.

## Impact

- **Current**: Low — the migration has already been applied and won't be re-run unless a fresh database is created
- **Future**: If a formal migration system is implemented (see `database-migration-system.md` backlog item), non-idempotent migrations will need special handling
- **Development**: New developers setting up the project may hit this if they run migrations out of order

## Suggested Fix

Rewrite migration 002 using the same idempotent pattern as migration 003:

```sql
DELIMITER //
CREATE PROCEDURE IF NOT EXISTS migrate_genomic_annotations()
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'non_alt_loci_set'
          AND COLUMN_NAME = 'gnomad_constraints'
    ) THEN
        ALTER TABLE non_alt_loci_set ADD COLUMN gnomad_constraints TEXT NULL;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE()
          AND TABLE_NAME = 'non_alt_loci_set'
          AND COLUMN_NAME = 'alphafold_id'
    ) THEN
        ALTER TABLE non_alt_loci_set ADD COLUMN alphafold_id VARCHAR(100) NULL;
    END IF;
END //
DELIMITER ;

CALL migrate_genomic_annotations();
DROP PROCEDURE IF EXISTS migrate_genomic_annotations;
```

## Files Affected

- `db/migrations/002_add_genomic_annotations.sql`

## Dependencies

- Related to `database-migration-system.md` backlog item — a proper migration runner would track applied versions, reducing the need for idempotency in individual scripts.

---
*Discovered during HGNC bulk gnomAD enrichment code audit (2026-01-28).*
