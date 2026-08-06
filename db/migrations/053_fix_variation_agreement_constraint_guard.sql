-- 053_fix_variation_agreement_constraint_guard.sql
-- Apply the constraint that migration 052 silently skipped
-- (berntpopp/sysndd-administration#18, #19).
--
-- WHAT WENT WRONG IN 052:
--   Its guard required `@parent_key_exists = 1`, where @parent_key_exists came
--   from information_schema.STATISTICS for the index
--   `uq_entity_review_review_entity`. STATISTICS holds one row PER COLUMN of an
--   index, and that index has two columns (review_id, entity_id) -- so the count
--   is 2, the condition was false, and the ALTER never ran.
--
--   It failed in the worst available way: silently. The migration was recorded
--   as applied, health/ready reported "applied 50, pending 0, manifest ok", and
--   the foreign key was simply not there. Nothing surfaced it except explicitly
--   asking information_schema whether the constraint existed. CI did not catch
--   it either -- the smoke test asserts the API starts, not that a constraint
--   was created.
--
--   Migration 051 was not affected: its equivalent guard tested `= 0`
--   (absence), which a count of 2 does not satisfy either way it is read.
--
-- THE FIX: an index-existence guard must ask `> 0`, never `= 1`. 052 is left
-- exactly as it shipped -- it is already recorded as applied, so editing it
-- would change history without re-running anything.
--
-- Otherwise identical to 052: same constraint, same name, same violation guard,
-- so a database that skipped the repair still no-ops rather than failing to
-- boot, and a database where 052 somehow did apply sees the FK already present
-- and no-ops too.

SET @vario_violations := (
  SELECT COUNT(*) FROM `ndd_review_variation_ontology_connect` c
  JOIN `ndd_entity_review` r ON r.`review_id` = c.`review_id`
  WHERE c.`entity_id` <> r.`entity_id`
);

SET @vario_fk_exists := (
  SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'ndd_review_variation_ontology_connect'
    AND CONSTRAINT_NAME = 'fk_variation_connect_review_entity'
);

-- `> 0`, not `= 1`: STATISTICS has one row per indexed column.
SET @parent_key_exists := (
  SELECT COUNT(*) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'ndd_entity_review'
    AND INDEX_NAME = 'uq_entity_review_review_entity'
);

SET @ddl := IF(@vario_violations = 0 AND @vario_fk_exists = 0
               AND @parent_key_exists > 0,
  'ALTER TABLE `ndd_review_variation_ontology_connect`
     ADD CONSTRAINT `fk_variation_connect_review_entity`
     FOREIGN KEY (`review_id`, `entity_id`)
     REFERENCES `ndd_entity_review` (`review_id`, `entity_id`)',
  'SELECT 1');

PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
