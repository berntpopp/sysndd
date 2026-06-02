-- Migration 025: Codify core views for pristine database bootstrap
--
-- Audit finding 2026-05-31 #2: ndd_entity_view, users_view,
-- search_non_alt_loci_view, and search_disease_ontology_set were never
-- created by any migration. They existed only in the out-of-band legacy
-- script db/C_Rcommands_set-table-connections.R (users_view was not in
-- version control at all). A from-scratch DB boot therefore 500'd on the
-- first entity/gene/user/search query.
--
-- Fix: create all four views here so a pristine DB boots fully.
-- All four use ALGORITHM=UNDEFINED SQL SECURITY INVOKER so they run with
-- the querying user's privileges and do not require a specific DEFINER
-- account to be present on a fresh install.
--
-- Ordering:
--   1. search_non_alt_loci_view    (self-contained; queries non_alt_loci_set)
--   2. search_disease_ontology_set (self-contained; queries disease_ontology_set)
--   3. ndd_entity_view             (depends on ndd_entity_status_approved_view
--                                   which is created by migration 000)
--   4. users_view                  (self-contained; queries user table)
--
-- SELECT bodies for views 1-3 are copied verbatim from
-- db/C_Rcommands_set-table-connections.R (lines 386-402, 407-423, 347-371)
-- with the `sysndd_db`. schema qualifier stripped for portability.
-- users_view is authored from the user table DDL in
-- db/migrations/000_initialize_base_schema.sql (lines 282-302).
--
-- Idempotent: CREATE OR REPLACE VIEW is safe to run multiple times.

CREATE OR REPLACE
  ALGORITHM = UNDEFINED SQL SECURITY INVOKER
  VIEW `search_non_alt_loci_view` AS
    SELECT
        `non_alt_loci_set`.`symbol` AS `result`,
        `non_alt_loci_set`.`hgnc_id` AS `hgnc_id`,
        `non_alt_loci_set`.`symbol` AS `symbol`,
        `non_alt_loci_set`.`name` AS `name`,
        'symbol' AS `search`
    FROM
        `non_alt_loci_set`
    UNION SELECT
        `non_alt_loci_set`.`hgnc_id` AS `result`,
        `non_alt_loci_set`.`hgnc_id` AS `hgnc_id`,
        `non_alt_loci_set`.`symbol` AS `symbol`,
        `non_alt_loci_set`.`name` AS `name`,
        'hgnc_id' AS `search`
    FROM
        `non_alt_loci_set`;

CREATE OR REPLACE
  ALGORITHM = UNDEFINED SQL SECURITY INVOKER
  VIEW `search_disease_ontology_set` AS
    SELECT
        `disease_ontology_set`.`disease_ontology_name` AS `result`,
        `disease_ontology_set`.`disease_ontology_id_version` AS `disease_ontology_id_version`,
        `disease_ontology_set`.`disease_ontology_id` AS `disease_ontology_id`,
        `disease_ontology_set`.`disease_ontology_name` AS `disease_ontology_name`,
        'disease_ontology_name' AS `search`
    FROM
        `disease_ontology_set`
    UNION SELECT
        `disease_ontology_set`.`disease_ontology_id_version` AS `result`,
        `disease_ontology_set`.`disease_ontology_id_version` AS `disease_ontology_id_version`,
        `disease_ontology_set`.`disease_ontology_id` AS `disease_ontology_id`,
        `disease_ontology_set`.`disease_ontology_name` AS `disease_ontology_name`,
        'disease_ontology_id_version' AS `search`
    FROM
        `disease_ontology_set`;

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
    WHERE
        `ndd_entity`.`is_active` = 1;

CREATE OR REPLACE
  ALGORITHM = UNDEFINED SQL SECURITY INVOKER
  VIEW `users_view` AS
    SELECT
      `user`.`user_id`   AS `user_id`,
      `user`.`user_name` AS `user_name`,
      `user`.`email`     AS `user_email`,
      `user`.`user_role` AS `user_role`
    FROM `user`;
