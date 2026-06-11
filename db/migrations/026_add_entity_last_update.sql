-- Migration 026: Add a derived `last_update` column to ndd_entity_view
--
-- Feature request 2026-06-11: alongside the existing `entry_date` (when an
-- entity was first created and which never changes), expose a "last updated"
-- date so a visitor can judge how current a curated record is.
--
-- SysNDD's curation model is append-only/versioned across three tables:
--   * ndd_entity.entry_date          -- entity creation date
--   * ndd_entity_status.status_date  -- each (re)classification; the active +
--                                       approved one is surfaced by
--                                       ndd_entity_status_approved_view
--   * ndd_entity_review.review_date  -- each synopsis/phenotype/publication/
--                                       variation review; the curated record is
--                                       the PRIMARY APPROVED review
--                                       (is_primary = 1 AND review_approved = 1)
--
-- `last_update` is therefore the most recent meaningful curation touch:
--   GREATEST(entry_date,
--            approved status_date,
--            COALESCE(latest primary-approved review_date, entry_date))
--
-- GREATEST never returns NULL here: entry_date and the approved status_date are
-- both NOT NULL (the approved-status view is an inner join), and the review term
-- is coalesced to entry_date when an entity has no primary-approved review.
--
-- This rebuilds the verbatim ndd_entity_view body from migration 025 with the
-- single new column added; keep db/C_Rcommands_set-table-connections.R in sync.
--
-- Idempotent: CREATE OR REPLACE VIEW is safe to run multiple times.

CREATE OR REPLACE
  ALGORITHM = UNDEFINED SQL SECURITY INVOKER
  VIEW `ndd_entity_view` AS
    SELECT
        `ndd_entity`.`entity_id` AS `entity_id`,
        `ndd_entity`.`hgnc_id` AS `hgnc_id`,
        `non_alt_loci_set`.`symbol` AS `symbol`,
        `disease_ontology_set`.`disease_ontology_id_version` AS `disease_ontology_id_version`,
        `disease_ontology_set`.`disease_ontology_name` AS `disease_ontology_name`,
        `mode_of_inheritance_list`.`hpo_mode_of_inheritance_term` AS `hpo_mode_of_inheritance_term`,
        `mode_of_inheritance_list`.`hpo_mode_of_inheritance_term_name` AS `hpo_mode_of_inheritance_term_name`,
        `mode_of_inheritance_list`.`inheritance_filter` AS `inheritance_filter`,
        `ndd_entity`.`ndd_phenotype` AS `ndd_phenotype`,
        `boolean_list`.`word_english` AS `ndd_phenotype_word`,
        `ndd_entity`.`entry_date` AS `entry_date`,
        GREATEST(
            `ndd_entity`.`entry_date`,
            `ndd_entity_status_approved_view`.`status_date`,
            COALESCE(`primary_review_date`.`review_date`, `ndd_entity`.`entry_date`)
        ) AS `last_update`,
        `ndd_entity_status_categories_list`.`category` AS `category`,
        `ndd_entity_status_categories_list`.`category_id` AS `category_id`
    FROM
        ((((((`ndd_entity`
        JOIN `non_alt_loci_set` ON (`ndd_entity`.`hgnc_id` = `non_alt_loci_set`.`hgnc_id`))
        JOIN `disease_ontology_set` ON (`ndd_entity`.`disease_ontology_id_version` = `disease_ontology_set`.`disease_ontology_id_version`))
        JOIN `mode_of_inheritance_list` ON (`ndd_entity`.`hpo_mode_of_inheritance_term` = `mode_of_inheritance_list`.`hpo_mode_of_inheritance_term`))
        JOIN `ndd_entity_status_approved_view` ON (`ndd_entity`.`entity_id` = `ndd_entity_status_approved_view`.`entity_id`))
        JOIN `ndd_entity_status_categories_list` ON (`ndd_entity_status_approved_view`.`category_id` = `ndd_entity_status_categories_list`.`category_id`))
        JOIN `boolean_list` ON (`ndd_entity`.`ndd_phenotype` = `boolean_list`.`logical`))
        LEFT JOIN (
            SELECT
                `ndd_entity_review`.`entity_id` AS `entity_id`,
                MAX(`ndd_entity_review`.`review_date`) AS `review_date`
            FROM `ndd_entity_review`
            WHERE `ndd_entity_review`.`is_primary` = 1
              AND `ndd_entity_review`.`review_approved` = 1
            GROUP BY `ndd_entity_review`.`entity_id`
        ) `primary_review_date` ON (`ndd_entity`.`entity_id` = `primary_review_date`.`entity_id`)
    WHERE
        `ndd_entity`.`is_active` = 1;
