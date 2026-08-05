-- 050_variant_view_entity_agreement.sql
-- Recreate ndd_review_variant_connect_view with the entity-agreement join, so the
-- public variant browse agrees with the entity page
-- (berntpopp/sysndd-administration#18).
--
-- THE DEFECT
--   ndd_review_variation_ontology_connect stores which entity a row belongs to
--   TWICE: directly in its own `entity_id`, and indirectly via the entity that
--   owns its `review_id`. Production has 256 active rows where those disagree
--   (206 on a primary, approved review) -- e.g. entity 3402's row citing review
--   3310, which belongs to entity 3403.
--
--   Traced to the 2022-06-09 bulk seed in
--   db/12_Rcommands_sysndd_db_table_variation_ontology_set.R, which took its
--   review_id -> entity_id pairing from `ndd_entity_review_files$value[1]` after
--   an ASCENDING date sort -- i.e. the OLDEST snapshot CSV, where it wanted the
--   newest. Stale input, not a bad algorithm, which is why the damage is one
--   contiguous block (entities 3395-3650) rather than scattered.
--
-- WHY THIS VIEW AND NOT THE OTHERS
--   svc_entity_variation() (api/services/entity-read-endpoint-service.R) already
--   requires BOTH predicates: the connect row's entity_id must equal the requested
--   entity AND the review must be one of that entity's primary-approved reviews.
--   This view joined on review_id ALONE, so the same 206 rows the entity page
--   drops were still surfacing in the public variant browse and the entity-list
--   vario filter. That disagreement is the bug being fixed here.
--
--   The sibling `ndd_review_phenotype_connect_view` is deliberately LEFT ALONE.
--   svc_entity_phenotypes() and svc_entity_publications() filter on review_id
--   only, so those views already agree with their own entity endpoints. Adding
--   this predicate there would HIDE 744 phenotype and 166 publication rows that
--   are currently displayed -- a user-visible data removal resting on an
--   unproven assumption about which column is authoritative. Do not "make it
--   consistent" without deciding that question first (admin#18).
--
-- SCOPE
--   This is a CONSISTENCY fix, not a data fix. It changes no row, and it does not
--   decide whether `entity_id` or `review_id` is the authoritative column for the
--   256 mismatched rows -- that remains open in admin#18. It only makes all three
--   variation surfaces (entity page, this view, seo-service.R) answer identically.
--   For every correct row the added predicate is already true, so nothing that
--   should be visible becomes hidden.
--
--   Keep in sync with db/C_Rcommands_set-table-connections.R and migration 042's
--   three gating predicates (is_active / is_primary / review_approved), which are
--   preserved verbatim below.

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
          ON (`ndd_review_variation_ontology_connect`.`review_id` = `ndd_entity_review`.`review_id`
              AND `ndd_review_variation_ontology_connect`.`entity_id` = `ndd_entity_review`.`entity_id`))
    WHERE
        (`ndd_review_variation_ontology_connect`.`is_active` = 1
         AND `ndd_entity_review`.`is_primary` = 1
         AND `ndd_entity_review`.`review_approved` = 1);
