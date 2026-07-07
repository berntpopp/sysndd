-- Migration 042: Gate review-connect views on review_approved (public exposure fix)
--
-- Security (Codex PR-1 review): ndd_review_phenotype_connect_view and
-- ndd_review_variant_connect_view filtered is_active = 1 AND is_primary = 1 but
-- NOT review_approved = 1. An in-place primary-review edit sets
-- review_approved = 0 while leaving is_primary = 1 (review-repository.R
-- review_update()), so the new UNAPPROVED phenotype/variation content leaked
-- through the public phenotype/variant browse, count, and correlation endpoints
-- (api/functions/endpoint-functions.R consumes both views) and the entity-list
-- vario filter -- the same #3 exposure class fixed at the entity endpoints and
-- the SEO service.
--
-- Fix: add `AND ndd_entity_review.review_approved = 1` to both view WHERE
-- clauses. SELECT bodies are copied verbatim from
-- db/C_Rcommands_set-table-connections.R with the `sysndd_db`. qualifier
-- stripped and SQL SECURITY INVOKER added (matching migration 025) so a fresh
-- DB boots without a specific DEFINER account. Keep this migration and that
-- script in sync if either view definition changes.
--
-- Idempotent: CREATE OR REPLACE VIEW is safe to run multiple times.

CREATE OR REPLACE
  ALGORITHM = UNDEFINED SQL SECURITY INVOKER
  VIEW `ndd_review_phenotype_connect_view` AS
    SELECT
        `ndd_review_phenotype_connect`.`entity_id` AS `entity_id`,
        `ndd_review_phenotype_connect`.`review_id` AS `review_id`,
        `ndd_review_phenotype_connect`.`phenotype_id` AS `phenotype_id`,
        `ndd_review_phenotype_connect`.`modifier_id` AS `modifier_id`,
        `phenotype_list`.`HPO_term` AS `HPO_term`,
        `modifier_list`.`modifier_name` AS `modifier_name`,
        CONCAT(`modifier_list`.`modifier_name`,
                ': ',
                `phenotype_list`.`HPO_term`) AS `modifier_phenotype_name`,
        CONCAT(`ndd_review_phenotype_connect`.`modifier_id`,
                '-',
                `ndd_review_phenotype_connect`.`phenotype_id`) AS `modifier_phenotype_id`,
        `ndd_review_phenotype_connect`.`phenotype_date` AS `phenotype_date`
    FROM
        (((`ndd_review_phenotype_connect`
        JOIN `modifier_list` ON ((`ndd_review_phenotype_connect`.`modifier_id` = `modifier_list`.`modifier_id`)))
        JOIN `phenotype_list` ON ((`ndd_review_phenotype_connect`.`phenotype_id` = `phenotype_list`.`phenotype_id`)))
        JOIN `ndd_entity_review` ON ((`ndd_review_phenotype_connect`.`review_id` = `ndd_entity_review`.`review_id`)))
    WHERE
        ((`ndd_review_phenotype_connect`.`is_active` = 1)
            AND (`ndd_entity_review`.`is_primary` = 1)
            AND (`ndd_entity_review`.`review_approved` = 1));

CREATE OR REPLACE
  ALGORITHM = UNDEFINED SQL SECURITY INVOKER
  VIEW `ndd_review_variant_connect_view` AS
    SELECT
        `ndd_review_variation_ontology_connect`.`entity_id` AS `entity_id`,
        `ndd_review_variation_ontology_connect`.`review_id` AS `review_id`,
        `ndd_review_variation_ontology_connect`.`vario_id` AS `vario_id`,
        `ndd_review_variation_ontology_connect`.`modifier_id` AS `modifier_id`,
        `variation_ontology_list`.`vario_name` AS `vario_name`,
        CONCAT(`variation_ontology_list`.`vario_name`, ': ', `variation_ontology_list`.`definition`) AS `vario_label`,
        CONCAT(`ndd_review_variation_ontology_connect`.`modifier_id`, '-', `ndd_review_variation_ontology_connect`.`vario_id`) AS `modifier_variant_id`,
        `ndd_review_variation_ontology_connect`.`variation_ontology_date` AS `variation_ontology_date`
    FROM
        ((`ndd_review_variation_ontology_connect`
        JOIN `variation_ontology_list`
          ON (`ndd_review_variation_ontology_connect`.`vario_id` = `variation_ontology_list`.`vario_id`))
        JOIN `ndd_entity_review`
          ON (`ndd_review_variation_ontology_connect`.`review_id` = `ndd_entity_review`.`review_id`))
    WHERE
        (`ndd_review_variation_ontology_connect`.`is_active` = 1
         AND `ndd_entity_review`.`is_primary` = 1
         AND `ndd_entity_review`.`review_approved` = 1);
