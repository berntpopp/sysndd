-- 051_entity_review_agreement_constraint.sql
-- Make "the connect row's entity disagrees with its review's entity"
-- unrepresentable (berntpopp/sysndd-administration#19).
--
-- THE PROBLEM THIS CLOSES:
--   ndd_review_phenotype_connect and ndd_review_publication_join each record the
--   owning entity TWICE -- in their own `entity_id`, and via the entity that owns
--   their `review_id`. Nothing enforced agreement. A 2022 seeding script resolved
--   review_id from the OLDEST snapshot CSV (`ndd_entity_review_files$value[1]`
--   after an ascending sort) while ndd_entity_review had been loaded from a newer
--   one. Between the two snapshots entity 3395 was deleted and entity 3651 added
--   -- a conserved off-by-one -- so every review_id in a 256-entity block pointed
--   one entity too far. 913 phenotype + 208 publication rows drifted, and nobody
--   noticed for four years because no constraint could notice.
--
-- WHY A COMPOSITE FOREIGN KEY RATHER THAN A CHECK OR A TRIGGER:
--   The invariant spans two tables, so a CHECK constraint cannot express it
--   (MySQL CHECK may not subquery). A trigger could, but it is application logic
--   living in the schema: it can be bypassed by disabling triggers, it must be
--   written twice (INSERT and UPDATE), and it is silent about intent.
--   A FOREIGN KEY on the PAIR is the declarative statement of the actual rule.
--   Because `review_id` is ndd_entity_review's PRIMARY KEY, the pair
--   (review_id, entity_id) resolves ONLY when entity_id equals that review's own
--   entity. Agreement stops being something the application must remember and
--   becomes something the engine refuses to violate.
--
--   The existing single-column FKs (`..._ibfk_1` on review_id) stay. They are
--   implied by this one but dropping them is a separate, riskier change with no
--   benefit.
--
-- WHY THE VARIATION TABLE IS NOT INCLUDED:
--   ndd_review_variation_ontology_connect still holds 256 rows that violate the
--   invariant (admin#18). ADD FOREIGN KEY against violating rows FAILS, and
--   migrations run at API startup -- so including it would turn a data defect
--   into a crash-looping API. It gets the identical constraint in a follow-up,
--   once those rows are repaired the same way #19's were.
--
-- WHY THE VIOLATION GUARD BELOW:
--   Same reasoning applied defensively to the two tables that ARE clean here.
--   Production was repaired before this migration shipped, but a developer
--   restoring an older dump, or any environment that skipped the repair, would
--   otherwise get an API that cannot start. The guard checks for violations
--   first and no-ops if any remain: such a database starts, serves, and reports
--   its pending state instead of crash-looping. The constraint then applies on
--   the next run after the data is fixed.
--
-- NULL keys: `review_id` is nullable and 3 rows hold NULL. A composite FK uses
-- MATCH SIMPLE semantics -- any NULL member satisfies the reference -- so those
-- rows are accepted and remain unconstrained. They are already invisible to
-- every read path (all of them join on review_id). Making the columns NOT NULL
-- is a separate change with its own data question.
--
-- Idempotent + restore-drift safe: information_schema guards in the style of
-- migrations 043/046/049. MySQL 8 has no ADD CONSTRAINT IF NOT EXISTS.

-- ---------------------------------------------------------------------------
-- 1. The parent key the composite reference needs.
--    (review_id, entity_id) is unique by construction because review_id is the
--    PRIMARY KEY, but MySQL still requires a real index on the referenced
--    columns before it will accept the FOREIGN KEY.
-- ---------------------------------------------------------------------------

SET @uq_exists := (
  SELECT COUNT(*) FROM information_schema.STATISTICS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'ndd_entity_review'
    AND INDEX_NAME = 'uq_entity_review_review_entity'
);

SET @ddl := IF(@uq_exists = 0,
  'ALTER TABLE `ndd_entity_review`
     ADD UNIQUE KEY `uq_entity_review_review_entity` (`review_id`, `entity_id`)',
  'SELECT 1');

PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ---------------------------------------------------------------------------
-- 2. ndd_review_phenotype_connect
-- ---------------------------------------------------------------------------

SET @pheno_violations := (
  SELECT COUNT(*) FROM `ndd_review_phenotype_connect` c
  JOIN `ndd_entity_review` r ON r.`review_id` = c.`review_id`
  WHERE c.`entity_id` <> r.`entity_id`
);

SET @pheno_fk_exists := (
  SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'ndd_review_phenotype_connect'
    AND CONSTRAINT_NAME = 'fk_phenotype_connect_review_entity'
);

SET @ddl := IF(@pheno_violations = 0 AND @pheno_fk_exists = 0,
  'ALTER TABLE `ndd_review_phenotype_connect`
     ADD CONSTRAINT `fk_phenotype_connect_review_entity`
     FOREIGN KEY (`review_id`, `entity_id`)
     REFERENCES `ndd_entity_review` (`review_id`, `entity_id`)',
  'SELECT 1');

PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- ---------------------------------------------------------------------------
-- 3. ndd_review_publication_join
-- ---------------------------------------------------------------------------

SET @pub_violations := (
  SELECT COUNT(*) FROM `ndd_review_publication_join` c
  JOIN `ndd_entity_review` r ON r.`review_id` = c.`review_id`
  WHERE c.`entity_id` <> r.`entity_id`
);

SET @pub_fk_exists := (
  SELECT COUNT(*) FROM information_schema.TABLE_CONSTRAINTS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'ndd_review_publication_join'
    AND CONSTRAINT_NAME = 'fk_publication_join_review_entity'
);

SET @ddl := IF(@pub_violations = 0 AND @pub_fk_exists = 0,
  'ALTER TABLE `ndd_review_publication_join`
     ADD CONSTRAINT `fk_publication_join_review_entity`
     FOREIGN KEY (`review_id`, `entity_id`)
     REFERENCES `ndd_entity_review` (`review_id`, `entity_id`)',
  'SELECT 1');

PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
