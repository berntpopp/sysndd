-- Migration 000: initialize the foundational legacy schema on pristine DBs
--
-- Production smoke boots the API against an empty MySQL volume. Incremental
-- migrations such as 001/004/005/009/018 assume the long-lived SysNDD base
-- tables already exist, so a pristine database must be brought to that
-- baseline before the numbered follow-up migrations run.
--
-- This migration deliberately creates only the durable legacy foundation:
-- core entity/user/reference tables, lookup tables, PubTator cache tables,
-- logging, and the approved-status view used by later migrations.
--
-- It is safe on existing deployments because every object uses IF NOT EXISTS
-- (or CREATE OR REPLACE for the view) and seed inserts are idempotent.

SET FOREIGN_KEY_CHECKS = 0;

CREATE TABLE IF NOT EXISTS `allowed_list` (
  `allowed_id` int NOT NULL,
  `type` varchar(10) DEFAULT NULL,
  `analysis` varchar(20) DEFAULT NULL,
  `value` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`allowed_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `boolean_list` (
  `boolean_id` int NOT NULL,
  `boolean_number` int DEFAULT NULL,
  `boolean_word` varchar(5) DEFAULT NULL,
  `word_english` varchar(5) DEFAULT NULL,
  `logical` tinyint DEFAULT NULL,
  PRIMARY KEY (`boolean_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `disease_ontology_set` (
  `disease_ontology_id_version` varchar(20) NOT NULL,
  `disease_ontology_id` varchar(15) DEFAULT NULL,
  `disease_ontology_name` varchar(500) DEFAULT NULL,
  `disease_ontology_source` varchar(15) DEFAULT NULL,
  `disease_ontology_date` timestamp NULL DEFAULT NULL,
  `disease_ontology_is_specific` tinyint DEFAULT NULL,
  `hgnc_id` varchar(10) DEFAULT NULL,
  `hpo_mode_of_inheritance_term` varchar(10) DEFAULT NULL,
  `DOID` varchar(200) DEFAULT NULL,
  `MONDO` varchar(200) DEFAULT NULL,
  `Orphanet` varchar(200) DEFAULT NULL,
  `EFO` varchar(200) DEFAULT NULL,
  `is_active` tinyint DEFAULT NULL,
  `update_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`disease_ontology_id_version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `json_storage` (
  `id` int NOT NULL AUTO_INCREMENT,
  `name` varchar(255) NOT NULL,
  `json_data` json NOT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `updated_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS `logging` (
  `id` int NOT NULL AUTO_INCREMENT,
  `timestamp` datetime NOT NULL,
  `address` varchar(255) NOT NULL,
  `agent` text,
  `host` varchar(255) DEFAULT NULL,
  `request_method` varchar(10) DEFAULT NULL,
  `path` text,
  `query` text,
  `post` text,
  `status` int DEFAULT NULL,
  `duration` float DEFAULT NULL,
  `file` varchar(255) DEFAULT NULL,
  `modified` timestamp NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS `mode_of_inheritance_list` (
  `hpo_mode_of_inheritance_term` varchar(10) NOT NULL,
  `hpo_mode_of_inheritance_term_name` varchar(100) DEFAULT NULL,
  `hpo_mode_of_inheritance_term_definition` varchar(1000) DEFAULT NULL,
  `inheritance_filter` varchar(20) DEFAULT NULL,
  `inheritance_short_text` varchar(5) DEFAULT NULL,
  `is_active` tinyint DEFAULT NULL,
  `sort` int DEFAULT NULL,
  `update_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`hpo_mode_of_inheritance_term`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `modifier_list` (
  `modifier_id` int NOT NULL,
  `modifier_name` varchar(15) DEFAULT NULL,
  `allowed_phenotype` tinyint DEFAULT NULL,
  `allowed_variation` tinyint DEFAULT NULL,
  PRIMARY KEY (`modifier_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `ndd_databases_links` (
  `name` varchar(22) NOT NULL,
  `link` varchar(98) DEFAULT NULL,
  `format` varchar(4) DEFAULT NULL,
  `list_output` varchar(19) DEFAULT NULL,
  `file_saved` varchar(37) DEFAULT NULL,
  PRIMARY KEY (`name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `non_alt_loci_set` (
  `hgnc_id` varchar(10) NOT NULL,
  `symbol` varchar(50) DEFAULT NULL,
  `name` varchar(200) DEFAULT NULL,
  `locus_group` varchar(50) DEFAULT NULL,
  `locus_type` varchar(50) DEFAULT NULL,
  `status` varchar(10) DEFAULT NULL,
  `location` varchar(50) DEFAULT NULL,
  `location_sortable` varchar(50) DEFAULT NULL,
  `alias_symbol` varchar(200) DEFAULT NULL,
  `alias_name` varchar(1000) DEFAULT NULL,
  `prev_symbol` varchar(200) DEFAULT NULL,
  `prev_name` varchar(1000) DEFAULT NULL,
  `gene_group` varchar(1000) DEFAULT NULL,
  `gene_group_id` varchar(50) DEFAULT NULL,
  `date_approved_reserved` timestamp NULL DEFAULT NULL,
  `date_symbol_changed` timestamp NULL DEFAULT NULL,
  `date_name_changed` timestamp NULL DEFAULT NULL,
  `date_modified` timestamp NULL DEFAULT NULL,
  `entrez_id` varchar(15) DEFAULT NULL,
  `ensembl_gene_id` varchar(15) DEFAULT NULL,
  `vega_id` varchar(20) DEFAULT NULL,
  `ucsc_id` varchar(15) DEFAULT NULL,
  `ena` varchar(100) DEFAULT NULL,
  `refseq_accession` varchar(100) DEFAULT NULL,
  `ccds_id` varchar(1000) DEFAULT NULL,
  `uniprot_ids` varchar(100) DEFAULT NULL,
  `pubmed_id` varchar(100) DEFAULT NULL,
  `mgd_id` varchar(1000) DEFAULT NULL,
  `rgd_id` varchar(50) DEFAULT NULL,
  `lsdb` varchar(1000) DEFAULT NULL,
  `cosmic` varchar(15) DEFAULT NULL,
  `omim_id` varchar(10) DEFAULT NULL,
  `mirbase` varchar(15) DEFAULT NULL,
  `homeodb` varchar(10) DEFAULT NULL,
  `snornabase` varchar(15) DEFAULT NULL,
  `bioparadigms_slc` varchar(15) DEFAULT NULL,
  `orphanet` varchar(10) DEFAULT NULL,
  `pseudogene.org` varchar(20) DEFAULT NULL,
  `horde_id` varchar(10) DEFAULT NULL,
  `merops` varchar(10) DEFAULT NULL,
  `imgt` varchar(20) DEFAULT NULL,
  `iuphar` varchar(20) DEFAULT NULL,
  `kznf_gene_catalog` varchar(10) DEFAULT NULL,
  `mamit-trnadb` varchar(10) DEFAULT NULL,
  `cd` varchar(10) DEFAULT NULL,
  `lncrnadb` varchar(50) DEFAULT NULL,
  `enzyme_id` varchar(50) DEFAULT NULL,
  `intermediate_filament_db` varchar(20) DEFAULT NULL,
  `rna_central_ids` varchar(10) DEFAULT NULL,
  `lncipedia` varchar(20) DEFAULT NULL,
  `gtrnadb` varchar(50) DEFAULT NULL,
  `agr` varchar(20) DEFAULT NULL,
  `mane_select` varchar(50) DEFAULT NULL,
  `gencc` varchar(20) DEFAULT NULL,
  `update_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `STRING_id` varchar(200) DEFAULT NULL,
  `bed_hg19` varchar(100) DEFAULT NULL,
  `bed_hg38` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`hgnc_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `ontology_set` (
  `disease_ontology_id_version` varchar(14) NOT NULL,
  `disease_ontology_id` varchar(13) DEFAULT NULL,
  `disease_ontology_name` varchar(125) DEFAULT NULL,
  `disease_ontology_source` varchar(9) DEFAULT NULL,
  `disease_ontology_date` timestamp NULL DEFAULT NULL,
  `disease_ontology_is_specific` tinyint(1) DEFAULT NULL,
  `hgnc_id` varchar(10) DEFAULT NULL,
  `hpo_mode_of_inheritance_term` varchar(10) DEFAULT NULL,
  `DOID` varchar(35) DEFAULT NULL,
  `MONDO` varchar(27) DEFAULT NULL,
  `Orphanet` varchar(151) DEFAULT NULL,
  `UMLS` varchar(27) DEFAULT NULL,
  `EFO` varchar(35) DEFAULT NULL,
  `is_active` tinyint(1) DEFAULT NULL,
  `update_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`disease_ontology_id_version`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `phenotype_list` (
  `phenotype_id` varchar(10) NOT NULL,
  `HPO_term` varchar(100) DEFAULT NULL,
  `HPO_term_definition` varchar(1000) DEFAULT NULL,
  `HPO_term_synonyms` varchar(1000) DEFAULT NULL,
  `comment` varchar(1000) DEFAULT NULL,
  PRIMARY KEY (`phenotype_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `publication` (
  `publication_id` varchar(15) NOT NULL,
  `publication_type` varchar(50) DEFAULT NULL,
  `other_publication_id` varchar(250) DEFAULT NULL,
  `Title` varchar(1000) DEFAULT NULL,
  `Abstract` text,
  `Fulltext` text,
  `Publication_date` date DEFAULT NULL,
  `Journal_abbreviation` varchar(50) DEFAULT NULL,
  `Journal` varchar(200) DEFAULT NULL,
  `Keywords` text,
  `Lastname` varchar(50) DEFAULT NULL,
  `Firstname` varchar(50) DEFAULT NULL,
  `update_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`publication_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `pubtator_annotation_cache` (
  `annotation_id` int NOT NULL AUTO_INCREMENT,
  `search_id` int DEFAULT NULL,
  `pmid` int NOT NULL,
  `id` varchar(255) DEFAULT NULL,
  `text` text,
  `identifier` varchar(255) DEFAULT NULL,
  `type` varchar(100) DEFAULT NULL,
  `ncbi_homologene` varchar(50) DEFAULT NULL,
  `valid` tinyint(1) DEFAULT NULL,
  `normalized` text,
  `database` varchar(100) DEFAULT NULL,
  `normalized_id` varchar(255) DEFAULT NULL,
  `biotype` varchar(100) DEFAULT NULL,
  `name` text,
  `accession` varchar(255) DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`annotation_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS `pubtator_query_cache` (
  `query_id` int NOT NULL AUTO_INCREMENT,
  `query_text` text NOT NULL,
  `query_hash` varchar(64) NOT NULL,
  `query_date` datetime DEFAULT CURRENT_TIMESTAMP,
  `total_page_number` int NOT NULL,
  `queried_page_number` int NOT NULL,
  `page_size` int NOT NULL,
  PRIMARY KEY (`query_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS `pubtator_search_cache` (
  `search_id` int NOT NULL AUTO_INCREMENT,
  `query_id` int NOT NULL,
  `id` varchar(255) DEFAULT NULL,
  `pmid` int DEFAULT NULL,
  `doi` varchar(255) DEFAULT NULL,
  `title` text,
  `journal` varchar(255) DEFAULT NULL,
  `date` date DEFAULT NULL,
  `score` float DEFAULT NULL,
  `text_hl` text,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`search_id`),
  KEY `pmid` (`pmid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS `results_csv_table` (
  `results_file_id` tinyint unsigned NOT NULL,
  `file_name` varchar(52) DEFAULT NULL,
  `table_name` varchar(37) DEFAULT NULL,
  `table_date` char(10) DEFAULT NULL,
  `extension` char(3) DEFAULT NULL,
  `import_date` char(10) DEFAULT NULL,
  `md5sum_file` char(32) DEFAULT NULL,
  PRIMARY KEY (`results_file_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `table_hash` (
  `hash_id` int NOT NULL AUTO_INCREMENT,
  `hash_256` varchar(64) DEFAULT NULL,
  `json_text` text,
  `target_endpoint` varchar(100) DEFAULT NULL,
  `entry_date` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`hash_id`),
  UNIQUE KEY `hash_256_UNIQUE` (`hash_256`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

CREATE TABLE IF NOT EXISTS `user` (
  `user_id` int NOT NULL AUTO_INCREMENT,
  `user_name` varchar(50) DEFAULT NULL,
  `password` varchar(50) DEFAULT NULL,
  `email` varchar(50) DEFAULT NULL,
  `orcid` varchar(50) DEFAULT NULL,
  `abbreviation` varchar(50) DEFAULT NULL,
  `first_name` varchar(100) DEFAULT NULL,
  `family_name` varchar(100) DEFAULT NULL,
  `user_role` char(15) NOT NULL DEFAULT 'Viewer',
  `comment` varchar(250) DEFAULT NULL,
  `terms_agreed` tinyint DEFAULT NULL,
  `approved` tinyint DEFAULT '0',
  `rereview_request` tinyint DEFAULT NULL,
  `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `password_reset_date` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`user_id`),
  UNIQUE KEY `user_name` (`user_name`),
  UNIQUE KEY `orcid` (`orcid`),
  UNIQUE KEY `email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `variation_ontology_list` (
  `vario_id` varchar(10) NOT NULL,
  `vario_name` varchar(100) DEFAULT NULL,
  `definition` varchar(1000) DEFAULT NULL,
  `obsolete` tinyint DEFAULT NULL,
  `is_active` tinyint DEFAULT NULL,
  `sort` int DEFAULT NULL,
  `update_date` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`vario_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `ndd_entity` (
  `entity_id` int NOT NULL AUTO_INCREMENT,
  `hgnc_id` varchar(10) DEFAULT NULL,
  `hpo_mode_of_inheritance_term` varchar(10) DEFAULT NULL,
  `disease_ontology_id_version` varchar(20) DEFAULT NULL,
  `ndd_phenotype` tinyint DEFAULT NULL,
  `entry_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `entry_source` char(100) NOT NULL DEFAULT 'sysndd',
  `entry_user_id` int NOT NULL,
  `is_active` tinyint DEFAULT '1',
  `replaced_by` int DEFAULT NULL,
  PRIMARY KEY (`entity_id`),
  UNIQUE KEY `entity_quadruple` (`hgnc_id`, `hpo_mode_of_inheritance_term`, `disease_ontology_id_version`, `ndd_phenotype`),
  KEY `hpo_mode_of_inheritance_term` (`hpo_mode_of_inheritance_term`),
  KEY `disease_ontology_id_version` (`disease_ontology_id_version`),
  KEY `entry_user_id` (`entry_user_id`),
  KEY `replaced_by` (`replaced_by`),
  CONSTRAINT `ndd_entity_ibfk_1` FOREIGN KEY (`hgnc_id`) REFERENCES `non_alt_loci_set` (`hgnc_id`),
  CONSTRAINT `ndd_entity_ibfk_2` FOREIGN KEY (`hpo_mode_of_inheritance_term`) REFERENCES `mode_of_inheritance_list` (`hpo_mode_of_inheritance_term`),
  CONSTRAINT `ndd_entity_ibfk_3` FOREIGN KEY (`disease_ontology_id_version`) REFERENCES `disease_ontology_set` (`disease_ontology_id_version`),
  CONSTRAINT `ndd_entity_ibfk_4` FOREIGN KEY (`entry_user_id`) REFERENCES `user` (`user_id`),
  CONSTRAINT `ndd_entity_ibfk_5` FOREIGN KEY (`replaced_by`) REFERENCES `ndd_entity` (`entity_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `ndd_entity_review` (
  `review_id` int NOT NULL AUTO_INCREMENT,
  `entity_id` int DEFAULT NULL,
  `synopsis` text,
  `is_primary` tinyint NOT NULL DEFAULT '0',
  `review_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `review_user_id` int NOT NULL,
  `review_approved` tinyint DEFAULT '0',
  `approving_user_id` int DEFAULT NULL,
  `comment` varchar(1000) DEFAULT NULL,
  PRIMARY KEY (`review_id`),
  KEY `entity_id` (`entity_id`),
  KEY `review_user_id` (`review_user_id`),
  KEY `approving_user_id` (`approving_user_id`),
  CONSTRAINT `ndd_entity_review_ibfk_1` FOREIGN KEY (`entity_id`) REFERENCES `ndd_entity` (`entity_id`),
  CONSTRAINT `ndd_entity_review_ibfk_2` FOREIGN KEY (`review_user_id`) REFERENCES `user` (`user_id`),
  CONSTRAINT `ndd_entity_review_ibfk_3` FOREIGN KEY (`approving_user_id`) REFERENCES `user` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `ndd_entity_status_categories_list` (
  `category_id` int NOT NULL,
  `category` varchar(15) DEFAULT NULL,
  PRIMARY KEY (`category_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `ndd_entity_status` (
  `status_id` int NOT NULL AUTO_INCREMENT,
  `entity_id` int DEFAULT NULL,
  `category_id` double DEFAULT '1',
  `is_active` tinyint NOT NULL DEFAULT '0',
  `status_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `status_user_id` int NOT NULL,
  `status_approved` tinyint DEFAULT '0',
  `approving_user_id` int DEFAULT NULL,
  `comment` varchar(1000) DEFAULT NULL,
  `problematic` tinyint DEFAULT '0',
  PRIMARY KEY (`status_id`),
  KEY `entity_id` (`entity_id`),
  KEY `status_user_id` (`status_user_id`),
  KEY `approving_user_id` (`approving_user_id`),
  CONSTRAINT `ndd_entity_status_ibfk_1` FOREIGN KEY (`entity_id`) REFERENCES `ndd_entity` (`entity_id`),
  CONSTRAINT `ndd_entity_status_ibfk_2` FOREIGN KEY (`status_user_id`) REFERENCES `user` (`user_id`),
  CONSTRAINT `ndd_entity_status_ibfk_3` FOREIGN KEY (`approving_user_id`) REFERENCES `user` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `ndd_review_phenotype_connect` (
  `review_phenotype_id` int NOT NULL AUTO_INCREMENT,
  `review_id` int DEFAULT NULL,
  `phenotype_id` varchar(10) DEFAULT NULL,
  `modifier_id` double DEFAULT '1',
  `entity_id` int DEFAULT NULL,
  `phenotype_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `is_active` tinyint DEFAULT '1',
  PRIMARY KEY (`review_phenotype_id`),
  UNIQUE KEY `phenotype_quintuple` (`review_id`, `phenotype_id`, `modifier_id`, `entity_id`, `is_active`),
  KEY `phenotype_id` (`phenotype_id`),
  CONSTRAINT `ndd_review_phenotype_connect_ibfk_1` FOREIGN KEY (`review_id`) REFERENCES `ndd_entity_review` (`review_id`),
  CONSTRAINT `ndd_review_phenotype_connect_ibfk_2` FOREIGN KEY (`phenotype_id`) REFERENCES `phenotype_list` (`phenotype_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `ndd_review_publication_join` (
  `review_publication_id` int NOT NULL AUTO_INCREMENT,
  `review_id` int DEFAULT NULL,
  `entity_id` int DEFAULT NULL,
  `publication_id` varchar(15) DEFAULT NULL,
  `publication_type` varchar(50) DEFAULT NULL,
  `is_reviewed` tinyint DEFAULT '1',
  PRIMARY KEY (`review_publication_id`),
  UNIQUE KEY `review_triple` (`review_id`, `entity_id`, `publication_id`),
  KEY `publication_id` (`publication_id`),
  CONSTRAINT `ndd_review_publication_join_ibfk_1` FOREIGN KEY (`review_id`) REFERENCES `ndd_entity_review` (`review_id`),
  CONSTRAINT `ndd_review_publication_join_ibfk_2` FOREIGN KEY (`publication_id`) REFERENCES `publication` (`publication_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `ndd_review_variation_ontology_connect` (
  `review_vario_id` int NOT NULL AUTO_INCREMENT,
  `review_id` int DEFAULT NULL,
  `vario_id` varchar(10) DEFAULT NULL,
  `modifier_id` int DEFAULT NULL,
  `entity_id` int DEFAULT NULL,
  `variation_ontology_date` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `is_active` tinyint DEFAULT '1',
  PRIMARY KEY (`review_vario_id`),
  UNIQUE KEY `phenotype_quintuple` (`review_id`, `vario_id`, `modifier_id`, `entity_id`, `is_active`),
  KEY `vario_id` (`vario_id`),
  CONSTRAINT `ndd_review_variation_ontology_connect_ibfk_1` FOREIGN KEY (`review_id`) REFERENCES `ndd_entity_review` (`review_id`),
  CONSTRAINT `ndd_review_variation_ontology_connect_ibfk_2` FOREIGN KEY (`vario_id`) REFERENCES `variation_ontology_list` (`vario_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `re_review_assignment` (
  `assignment_id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `re_review_batch` int DEFAULT NULL,
  PRIMARY KEY (`assignment_id`),
  KEY `user_id` (`user_id`),
  CONSTRAINT `re_review_assignment_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `user` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

CREATE TABLE IF NOT EXISTS `re_review_entity_connect` (
  `re_review_entity_id` int NOT NULL AUTO_INCREMENT,
  `entity_id` int DEFAULT NULL,
  `re_review_batch` int DEFAULT NULL,
  `re_review_review_saved` tinyint DEFAULT NULL,
  `re_review_status_saved` tinyint DEFAULT NULL,
  `re_review_submitted` tinyint DEFAULT NULL,
  `re_review_approved` tinyint DEFAULT NULL,
  `approving_user_id` int DEFAULT NULL,
  `status_id` int DEFAULT NULL,
  `review_id` int DEFAULT NULL,
  PRIMARY KEY (`re_review_entity_id`),
  KEY `entity_id` (`entity_id`),
  KEY `approving_user_id` (`approving_user_id`),
  CONSTRAINT `re_review_entity_connect_ibfk_1` FOREIGN KEY (`entity_id`) REFERENCES `ndd_entity` (`entity_id`),
  CONSTRAINT `re_review_entity_connect_ibfk_2` FOREIGN KEY (`approving_user_id`) REFERENCES `user` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb3;

INSERT INTO `allowed_list` (`allowed_id`, `type`, `analysis`, `value`) VALUES
  (1, 'input', 'inheritance', 'X-linked'),
  (2, 'input', 'inheritance', 'Dominant'),
  (3, 'input', 'inheritance', 'Recessive'),
  (4, 'input', 'inheritance', 'Other'),
  (5, 'input', 'inheritance', 'All'),
  (6, 'output', 'panels', 'category'),
  (7, 'output', 'panels', 'inheritance'),
  (8, 'output', 'panels', 'symbol'),
  (9, 'output', 'panels', 'hgnc_id'),
  (10, 'output', 'panels', 'entrez_id'),
  (11, 'output', 'panels', 'ensembl_gene_id'),
  (12, 'output', 'panels', 'ucsc_id'),
  (13, 'output', 'panels', 'bed_hg19'),
  (14, 'output', 'panels', 'bed_hg38'),
  (15, 'input', 'user', 'Administrator'),
  (16, 'input', 'user', 'Curator'),
  (17, 'input', 'user', 'Reviewer'),
  (18, 'input', 'user', 'Viewer')
ON DUPLICATE KEY UPDATE
  `type` = VALUES(`type`),
  `analysis` = VALUES(`analysis`),
  `value` = VALUES(`value`);

INSERT INTO `boolean_list` (`boolean_id`, `boolean_number`, `boolean_word`, `word_english`, `logical`) VALUES
  (1, 0, '0', 'No', 0),
  (2, 1, '1', 'Yes', 1)
ON DUPLICATE KEY UPDATE
  `boolean_number` = VALUES(`boolean_number`),
  `boolean_word` = VALUES(`boolean_word`),
  `word_english` = VALUES(`word_english`),
  `logical` = VALUES(`logical`);

INSERT INTO `modifier_list` (`modifier_id`, `modifier_name`, `allowed_phenotype`, `allowed_variation`) VALUES
  (1, 'present', 1, 1),
  (2, 'uncertain', 1, 0),
  (3, 'variable', 1, 0),
  (4, 'rare', 1, 0),
  (5, 'absent', 1, 1)
ON DUPLICATE KEY UPDATE
  `modifier_name` = VALUES(`modifier_name`),
  `allowed_phenotype` = VALUES(`allowed_phenotype`),
  `allowed_variation` = VALUES(`allowed_variation`);

INSERT INTO `ndd_entity_status_categories_list` (`category_id`, `category`) VALUES
  (1, 'Definitive'),
  (2, 'Moderate'),
  (3, 'Limited'),
  (4, 'Refuted'),
  (5, 'not applicable')
ON DUPLICATE KEY UPDATE
  `category` = VALUES(`category`);

INSERT INTO `user` (
  `user_id`,
  `user_name`,
  `password`,
  `email`,
  `orcid`,
  `abbreviation`,
  `first_name`,
  `family_name`,
  `user_role`,
  `comment`,
  `terms_agreed`,
  `approved`,
  `rereview_request`
) VALUES (
  1,
  'system',
  NULL,
  'system@sysndd.invalid',
  NULL,
  'SYS',
  'System',
  'User',
  'Administrator',
  'Bootstrap system user for pristine schema migrations',
  1,
  1,
  0
)
ON DUPLICATE KEY UPDATE
  `user_name` = VALUES(`user_name`),
  `email` = VALUES(`email`),
  `abbreviation` = VALUES(`abbreviation`),
  `first_name` = VALUES(`first_name`),
  `family_name` = VALUES(`family_name`),
  `user_role` = VALUES(`user_role`),
  `comment` = VALUES(`comment`),
  `terms_agreed` = VALUES(`terms_agreed`),
  `approved` = VALUES(`approved`),
  `rereview_request` = VALUES(`rereview_request`);

CREATE OR REPLACE VIEW `ndd_entity_status_approved_view` AS
SELECT
  `ndd_entity_status`.`status_id` AS `status_id`,
  `ndd_entity_status`.`entity_id` AS `entity_id`,
  `ndd_entity_status`.`category_id` AS `category_id`,
  `ndd_entity_status`.`is_active` AS `is_active`,
  `ndd_entity_status`.`status_date` AS `status_date`,
  `ndd_entity_status`.`status_user_id` AS `status_user_id`,
  `ndd_entity_status`.`status_approved` AS `status_approved`,
  `ndd_entity_status`.`approving_user_id` AS `approving_user_id`,
  `ndd_entity_status`.`comment` AS `comment`,
  `ndd_entity_status`.`problematic` AS `problematic`
FROM `ndd_entity_status`
WHERE `ndd_entity_status`.`status_approved` = 1
  AND `ndd_entity_status`.`is_active` = 1;

SET FOREIGN_KEY_CHECKS = 1;
