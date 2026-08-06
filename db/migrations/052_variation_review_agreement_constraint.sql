-- 052_variation_review_agreement_constraint.sql
-- Complete the entity/review agreement invariant: constrain the third and last
-- join table (berntpopp/sysndd-administration#18, #19).
--
-- WHY THIS IS SEPARATE FROM 051:
--   051 constrained ndd_review_phenotype_connect and ndd_review_publication_join
--   but deliberately skipped ndd_review_variation_ontology_connect, which still
--   held 256 rows violating the invariant. ADD FOREIGN KEY against violating
--   rows FAILS, and migrations run at API startup, so including it then would
--   have turned a data defect into a crash-looping API.
--
--   Those rows have since been repaired: 255 were pointed back at their own
--   entity's seed-era review (the review they were generated against, before a
--   stale-snapshot renumbering shifted every review_id in a 256-entity block by
--   one), and one -- entity 3395, VariO:0001 -- was removed, because that entity
--   had been deleted from ndd_entity outright and therefore had no review to be
--   repaired onto. It was the single obstacle to this constraint: the pair
--   (review_id 3303, entity_id 3395) can never resolve.
--
-- WHAT THIS BUYS:
--   With this in place all three review join tables are covered, and the class
--   of defect that produced ~1,377 silently misattributed rows between 2022 and
--   2026 is unrepresentable rather than merely absent.
--
-- The unique parent key `uq_entity_review_review_entity` was created by 051 and
-- is NOT re-added here; doing so would fail wherever 051 has applied.
--
-- Guarded identically to 051: a database that skipped the repair no-ops and
-- starts, rather than failing to boot.

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

SET @parent_key_exists := (
  SELECT COUNT(*) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'ndd_entity_review'
    AND INDEX_NAME = 'uq_entity_review_review_entity'
);

SET @ddl := IF(@vario_violations = 0 AND @vario_fk_exists = 0
               AND @parent_key_exists = 1,
  'ALTER TABLE `ndd_review_variation_ontology_connect`
     ADD CONSTRAINT `fk_variation_connect_review_entity`
     FOREIGN KEY (`review_id`, `entity_id`)
     REFERENCES `ndd_entity_review` (`review_id`, `entity_id`)',
  'SELECT 1');

PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
