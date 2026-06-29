-- db/fixtures/playwright_docs_screenshots.sql
-- Playwright-only documentation screenshot data. This file is sourced only by
-- `make docs-screenshots` after migrations and Playwright users are present.
-- It is synthetic UI fixture data and must never be referenced from production
-- migrations or imported into production data preparation paths.

INSERT INTO `non_alt_loci_set` (
  `hgnc_id`,
  `symbol`,
  `name`,
  `locus_group`,
  `locus_type`,
  `status`
) VALUES (
  'HGNC:20153',
  'CHD8',
  'chromodomain helicase DNA binding protein 8',
  'protein-coding gene',
  'gene with protein product',
  'Approved'
)
ON DUPLICATE KEY UPDATE
  `symbol` = VALUES(`symbol`),
  `name` = VALUES(`name`),
  `locus_group` = VALUES(`locus_group`),
  `locus_type` = VALUES(`locus_type`),
  `status` = VALUES(`status`);

-- Gene-detail UI/UX e2e fixtures (app/tests/e2e/genes-detail-ui-ux.spec.ts and
-- gene-page-own-data-priority.spec.ts). ARID1B carries real gnomAD v4 constraint
-- scores so the gnomAD constraint MATRIX renders (the dense-data layout the
-- overflow checks exercise); NAA10 has no constraint data so the no-data empty
-- state + "view on gnomAD" link render. Without these rows /Genes/ARID1B and
-- /Genes/NAA10 404 and the specs time out waiting for the gene heading.
INSERT INTO `non_alt_loci_set` (
  `hgnc_id`,
  `symbol`,
  `name`,
  `locus_group`,
  `locus_type`,
  `status`,
  `gnomad_constraints`
) VALUES
  (
    'HGNC:18040',
    'ARID1B',
    'AT-rich interaction domain 1B',
    'protein-coding gene',
    'gene with protein product',
    'Approved',
    '{"pLI":1,"oe_lof":0.15062,"oe_lof_lower":0.111,"oe_lof_upper":0.205,"oe_mis":0.95931,"oe_mis_lower":0.929,"oe_mis_upper":0.989,"oe_syn":1.1558,"oe_syn_lower":1.105,"oe_syn_upper":1.208,"exp_lof":192.54,"obs_lof":29,"exp_mis":2977.1,"obs_mis":2856,"exp_syn":1198.3,"obs_syn":1385,"lof_z":9.986,"mis_z":0.81072,"syn_z":-2.9392}'
  ),
  (
    'HGNC:18704',
    'NAA10',
    'N-alpha-acetyltransferase 10, NatA catalytic subunit',
    'protein-coding gene',
    'gene with protein product',
    'Approved',
    NULL
  )
ON DUPLICATE KEY UPDATE
  `symbol` = VALUES(`symbol`),
  `name` = VALUES(`name`),
  `locus_group` = VALUES(`locus_group`),
  `locus_type` = VALUES(`locus_type`),
  `status` = VALUES(`status`),
  `gnomad_constraints` = VALUES(`gnomad_constraints`);

INSERT INTO `mode_of_inheritance_list` (
  `hpo_mode_of_inheritance_term`,
  `hpo_mode_of_inheritance_term_name`,
  `hpo_mode_of_inheritance_term_definition`,
  `inheritance_filter`,
  `inheritance_short_text`,
  `is_active`,
  `sort`
) VALUES (
  'HP:0000006',
  'Autosomal dominant inheritance',
  'A mode of inheritance that is observed for traits related to a gene encoded on one of the autosomes.',
  'Dominant',
  'AD',
  1,
  1
)
ON DUPLICATE KEY UPDATE
  `hpo_mode_of_inheritance_term_name` = VALUES(`hpo_mode_of_inheritance_term_name`),
  `hpo_mode_of_inheritance_term_definition` = VALUES(`hpo_mode_of_inheritance_term_definition`),
  `inheritance_filter` = VALUES(`inheritance_filter`),
  `inheritance_short_text` = VALUES(`inheritance_short_text`),
  `is_active` = VALUES(`is_active`),
  `sort` = VALUES(`sort`);

INSERT INTO `disease_ontology_set` (
  `disease_ontology_id_version`,
  `disease_ontology_id`,
  `disease_ontology_name`,
  `disease_ontology_source`,
  `disease_ontology_is_specific`,
  `MONDO`,
  `is_active`
) VALUES (
  'MONDO:0100038_2026',
  'MONDO:0100038',
  'CHD8-related neurodevelopmental disorder',
  'MONDO',
  1,
  'MONDO:0100038',
  1
)
ON DUPLICATE KEY UPDATE
  `disease_ontology_id` = VALUES(`disease_ontology_id`),
  `disease_ontology_name` = VALUES(`disease_ontology_name`),
  `disease_ontology_source` = VALUES(`disease_ontology_source`),
  `disease_ontology_is_specific` = VALUES(`disease_ontology_is_specific`),
  `MONDO` = VALUES(`MONDO`),
  `is_active` = VALUES(`is_active`);

INSERT INTO `phenotype_list` (
  `phenotype_id`,
  `HPO_term`,
  `HPO_term_definition`,
  `HPO_term_synonyms`
) VALUES (
  'HP:0001263',
  'Global developmental delay',
  'A delay in the achievement of motor or mental milestones in the domains of development of a child.',
  'Developmental delay'
)
ON DUPLICATE KEY UPDATE
  `HPO_term` = VALUES(`HPO_term`),
  `HPO_term_definition` = VALUES(`HPO_term_definition`),
  `HPO_term_synonyms` = VALUES(`HPO_term_synonyms`);

INSERT INTO `variation_ontology_list` (
  `vario_id`,
  `vario_name`,
  `definition`,
  `obsolete`,
  `is_active`,
  `sort`
) VALUES (
  'VariO:0001',
  'loss of function variant',
  'Synthetic Playwright-only fixture term used to exercise the review modal.',
  0,
  1,
  1
)
ON DUPLICATE KEY UPDATE
  `vario_name` = VALUES(`vario_name`),
  `definition` = VALUES(`definition`),
  `obsolete` = VALUES(`obsolete`),
  `is_active` = VALUES(`is_active`),
  `sort` = VALUES(`sort`);

INSERT INTO `publication` (
  `publication_id`,
  `publication_type`,
  `Title`,
  `Abstract`,
  `Publication_date`,
  `Journal_abbreviation`,
  `Journal`
) VALUES (
  '12345678',
  'PMID',
  'Synthetic CHD8 review fixture for documentation screenshots',
  'Synthetic Playwright-only publication fixture.',
  '2026-01-01 00:00:00',
  'SysNDD Docs',
  'SysNDD Documentation Fixtures'
)
ON DUPLICATE KEY UPDATE
  `publication_type` = VALUES(`publication_type`),
  `Title` = VALUES(`Title`),
  `Abstract` = VALUES(`Abstract`),
  `Publication_date` = VALUES(`Publication_date`),
  `Journal_abbreviation` = VALUES(`Journal_abbreviation`),
  `Journal` = VALUES(`Journal`);

INSERT INTO `ndd_entity` (
  `entity_id`,
  `hgnc_id`,
  `hpo_mode_of_inheritance_term`,
  `disease_ontology_id_version`,
  `ndd_phenotype`,
  `entry_source`,
  `entry_user_id`,
  `is_active`
) VALUES (
  123,
  'HGNC:20153',
  'HP:0000006',
  'MONDO:0100038_2026',
  1,
  'playwright_docs_screenshots',
  1,
  1
)
ON DUPLICATE KEY UPDATE
  `hgnc_id` = VALUES(`hgnc_id`),
  `hpo_mode_of_inheritance_term` = VALUES(`hpo_mode_of_inheritance_term`),
  `disease_ontology_id_version` = VALUES(`disease_ontology_id_version`),
  `ndd_phenotype` = VALUES(`ndd_phenotype`),
  `entry_source` = VALUES(`entry_source`),
  `entry_user_id` = VALUES(`entry_user_id`),
  `is_active` = VALUES(`is_active`);

INSERT INTO `ndd_entity_review` (
  `review_id`,
  `entity_id`,
  `synopsis`,
  `is_primary`,
  `review_date`,
  `review_user_id`,
  `review_approved`,
  `approving_user_id`,
  `comment`
) VALUES (
  123,
  123,
  'CHD8-related neurodevelopmental disorder is represented here as a Playwright-only documentation fixture.',
  1,
  '2026-01-01 00:00:00',
  1,
  1,
  1,
  'Synthetic documentation screenshot fixture.'
)
ON DUPLICATE KEY UPDATE
  `entity_id` = VALUES(`entity_id`),
  `synopsis` = VALUES(`synopsis`),
  `is_primary` = VALUES(`is_primary`),
  `review_date` = VALUES(`review_date`),
  `review_user_id` = VALUES(`review_user_id`),
  `review_approved` = VALUES(`review_approved`),
  `approving_user_id` = VALUES(`approving_user_id`),
  `comment` = VALUES(`comment`);

INSERT INTO `ndd_entity_status` (
  `status_id`,
  `entity_id`,
  `category_id`,
  `is_active`,
  `status_date`,
  `status_user_id`,
  `status_approved`,
  `approving_user_id`,
  `comment`,
  `problematic`
) VALUES (
  123,
  123,
  1,
  1,
  '2026-01-01 00:00:00',
  1,
  1,
  1,
  'Synthetic documentation screenshot fixture.',
  0
)
ON DUPLICATE KEY UPDATE
  `entity_id` = VALUES(`entity_id`),
  `category_id` = VALUES(`category_id`),
  `is_active` = VALUES(`is_active`),
  `status_date` = VALUES(`status_date`),
  `status_user_id` = VALUES(`status_user_id`),
  `status_approved` = VALUES(`status_approved`),
  `approving_user_id` = VALUES(`approving_user_id`),
  `comment` = VALUES(`comment`),
  `problematic` = VALUES(`problematic`);

INSERT INTO `ndd_review_phenotype_connect` (
  `review_phenotype_id`,
  `review_id`,
  `phenotype_id`,
  `modifier_id`,
  `entity_id`,
  `is_active`
) VALUES (
  123,
  123,
  'HP:0001263',
  1,
  123,
  1
)
ON DUPLICATE KEY UPDATE
  `review_id` = VALUES(`review_id`),
  `phenotype_id` = VALUES(`phenotype_id`),
  `modifier_id` = VALUES(`modifier_id`),
  `entity_id` = VALUES(`entity_id`),
  `is_active` = VALUES(`is_active`);

INSERT INTO `ndd_review_variation_ontology_connect` (
  `review_vario_id`,
  `review_id`,
  `vario_id`,
  `modifier_id`,
  `entity_id`,
  `is_active`
) VALUES (
  123,
  123,
  'VariO:0001',
  1,
  123,
  1
)
ON DUPLICATE KEY UPDATE
  `review_id` = VALUES(`review_id`),
  `vario_id` = VALUES(`vario_id`),
  `modifier_id` = VALUES(`modifier_id`),
  `entity_id` = VALUES(`entity_id`),
  `is_active` = VALUES(`is_active`);

INSERT INTO `ndd_review_publication_join` (
  `review_publication_id`,
  `review_id`,
  `entity_id`,
  `publication_id`,
  `publication_type`,
  `is_reviewed`
) VALUES (
  123,
  123,
  123,
  '12345678',
  'PMID',
  1
)
ON DUPLICATE KEY UPDATE
  `review_id` = VALUES(`review_id`),
  `entity_id` = VALUES(`entity_id`),
  `publication_id` = VALUES(`publication_id`),
  `publication_type` = VALUES(`publication_type`),
  `is_reviewed` = VALUES(`is_reviewed`);

DELETE FROM `re_review_assignment` WHERE `re_review_batch` = 9001;

INSERT INTO `re_review_assignment` (`user_id`, `re_review_batch`)
SELECT `user_id`, 9001
FROM `user`
WHERE `user_name` = 'pw_reviewer';

INSERT INTO `re_review_entity_connect` (
  `re_review_entity_id`,
  `entity_id`,
  `re_review_batch`,
  `re_review_review_saved`,
  `re_review_status_saved`,
  `re_review_submitted`,
  `re_review_approved`,
  `status_id`,
  `review_id`
) VALUES (
  9001,
  123,
  9001,
  0,
  0,
  0,
  0,
  123,
  123
)
ON DUPLICATE KEY UPDATE
  `entity_id` = VALUES(`entity_id`),
  `re_review_batch` = VALUES(`re_review_batch`),
  `re_review_review_saved` = VALUES(`re_review_review_saved`),
  `re_review_status_saved` = VALUES(`re_review_status_saved`),
  `re_review_submitted` = VALUES(`re_review_submitted`),
  `re_review_approved` = VALUES(`re_review_approved`),
  `status_id` = VALUES(`status_id`),
  `review_id` = VALUES(`review_id`);

CREATE OR REPLACE VIEW `ndd_entity_status_approved_view` AS
SELECT
  `status_id`,
  `entity_id`,
  `category_id`,
  `is_active`,
  `status_date`,
  `status_user_id`,
  `status_approved`,
  `approving_user_id`,
  `comment`,
  `problematic`
FROM `ndd_entity_status`
WHERE `status_approved` = 1
  AND `is_active` = 1;

CREATE OR REPLACE VIEW `ndd_entity_view` AS
SELECT
  e.`entity_id`,
  e.`hgnc_id`,
  g.`symbol`,
  d.`disease_ontology_id_version`,
  d.`disease_ontology_name`,
  m.`hpo_mode_of_inheritance_term`,
  m.`hpo_mode_of_inheritance_term_name`,
  m.`inheritance_filter`,
  e.`ndd_phenotype`,
  b.`word_english` AS `ndd_phenotype_word`,
  e.`entry_date`,
  c.`category`,
  c.`category_id`
FROM `ndd_entity` e
JOIN `non_alt_loci_set` g
  ON e.`hgnc_id` = g.`hgnc_id`
JOIN `disease_ontology_set` d
  ON e.`disease_ontology_id_version` = d.`disease_ontology_id_version`
JOIN `mode_of_inheritance_list` m
  ON e.`hpo_mode_of_inheritance_term` = m.`hpo_mode_of_inheritance_term`
JOIN `ndd_entity_status_approved_view` s
  ON e.`entity_id` = s.`entity_id`
JOIN `ndd_entity_status_categories_list` c
  ON s.`category_id` = c.`category_id`
JOIN `boolean_list` b
  ON e.`ndd_phenotype` = b.`logical`
WHERE e.`is_active` = 1;

CREATE OR REPLACE VIEW `ndd_database_comparison_view` AS
SELECT
  e.`hgnc_id`,
  e.`disease_ontology_id_version` AS `disease_ontology_id`,
  e.`hpo_mode_of_inheritance_term` AS `inheritance`,
  c.`category`,
  '1' AS `pathogenicity_mode`,
  'SysNDD' AS `list`,
  'current' AS `version`
FROM `ndd_entity` e
JOIN `ndd_entity_status_approved_view` s
  ON e.`entity_id` = s.`entity_id`
JOIN `ndd_entity_status_categories_list` c
  ON s.`category_id` = c.`category_id`
WHERE e.`is_active` = 1
  AND e.`ndd_phenotype` = 1
UNION ALL
SELECT
  `hgnc_id`,
  `disease_ontology_id`,
  `inheritance`,
  `category`,
  `pathogenicity_mode`,
  `list`,
  `version`
FROM `ndd_database_comparison`;

CREATE OR REPLACE VIEW `ndd_review_phenotype_connect_view` AS
SELECT
  pc.`entity_id`,
  pc.`review_id`,
  pc.`phenotype_id`,
  pc.`modifier_id`,
  p.`HPO_term`,
  ml.`modifier_name`,
  CONCAT(ml.`modifier_name`, ': ', p.`HPO_term`) AS `modifier_phenotype_name`,
  CONCAT(pc.`modifier_id`, '-', pc.`phenotype_id`) AS `modifier_phenotype_id`,
  pc.`phenotype_date`
FROM `ndd_review_phenotype_connect` pc
JOIN `modifier_list` ml
  ON pc.`modifier_id` = ml.`modifier_id`
JOIN `phenotype_list` p
  ON pc.`phenotype_id` = p.`phenotype_id`
JOIN `ndd_entity_review` r
  ON pc.`review_id` = r.`review_id`
WHERE pc.`is_active` = 1
  AND r.`is_primary` = 1;

CREATE OR REPLACE VIEW `ndd_review_variant_connect_view` AS
SELECT
  vc.`entity_id`,
  vc.`review_id`,
  vc.`vario_id`,
  vc.`modifier_id`,
  v.`vario_name`,
  CONCAT(v.`vario_name`, ': ', v.`definition`) AS `vario_label`,
  CONCAT(vc.`modifier_id`, '-', vc.`vario_id`) AS `modifier_variant_id`,
  vc.`variation_ontology_date`
FROM `ndd_review_variation_ontology_connect` vc
JOIN `variation_ontology_list` v
  ON vc.`vario_id` = v.`vario_id`
JOIN `ndd_entity_review` r
  ON vc.`review_id` = r.`review_id`
WHERE vc.`is_active` = 1
  AND r.`is_primary` = 1;
