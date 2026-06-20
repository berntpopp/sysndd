CREATE TABLE IF NOT EXISTS `mondo_term` (
  `mondo_id`        varchar(20)  NOT NULL,
  `label`           varchar(1000) DEFAULT NULL,
  `definition`      text         DEFAULT NULL,
  `is_obsolete`     tinyint(1)   NOT NULL DEFAULT 0,
  `replaced_by`     varchar(20)  DEFAULT NULL,
  `release_version` varchar(32)  DEFAULT NULL,
  `update_date`     timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`mondo_id`),
  KEY `idx_mondo_term_label` (`label`(100))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mondo_xref` (
  `id`              bigint       NOT NULL AUTO_INCREMENT,
  `mondo_id`        varchar(20)  NOT NULL,
  `target_prefix`   varchar(20)  NOT NULL,
  `target_id`       varchar(64)  NOT NULL,
  `target_id_upper` varchar(64)  NOT NULL,
  `target_label`    varchar(1000) DEFAULT NULL,
  `predicate`       varchar(20)  NOT NULL,
  `origin`          varchar(12)  NOT NULL,
  `source`          varchar(200) DEFAULT NULL,
  `release_version` varchar(32)  DEFAULT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_mondo_xref_mondo` (`mondo_id`),
  KEY `idx_mondo_xref_target` (`target_prefix`,`target_id_upper`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `disease_ontology_mapping` (
  `id`                  bigint       NOT NULL AUTO_INCREMENT,
  `disease_ontology_id` varchar(15)  CHARACTER SET utf8mb3 COLLATE utf8mb3_general_ci NOT NULL,
  `mondo_id`            varchar(20)  DEFAULT NULL,
  `target_prefix`       varchar(20)  NOT NULL,
  `target_id`           varchar(64)  NOT NULL,
  `target_label`        varchar(1000) DEFAULT NULL,
  `predicate`           varchar(20)  DEFAULT NULL,
  `source`              varchar(40)  NOT NULL,
  `release_version`     varchar(32)  DEFAULT NULL,
  `is_active`           tinyint(1)   NOT NULL DEFAULT 1,
  `update_date`         timestamp    NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_disease_target` (`disease_ontology_id`,`target_prefix`,`target_id`),
  KEY `idx_dom_disease` (`disease_ontology_id`),
  KEY `idx_dom_target` (`target_prefix`,`target_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `disease_ontology_mapping_meta` (
  `id`                    int          NOT NULL AUTO_INCREMENT,
  `mondo_release_version` varchar(32)  DEFAULT NULL,
  `mondo_obo_url`         varchar(500) DEFAULT NULL,
  `mondo_sssom_url`       varchar(500) DEFAULT NULL,
  `source_validators`     json         DEFAULT NULL,
  `mondo_term_count`      int          DEFAULT NULL,
  `mondo_xref_count`      int          DEFAULT NULL,
  `mapping_count`         int          DEFAULT NULL,
  `disease_covered_count` int          DEFAULT NULL,
  `status`                varchar(20)  DEFAULT NULL,
  `build_started_at`      timestamp    NULL DEFAULT NULL,
  `build_finished_at`     timestamp    NULL DEFAULT NULL,
  `build_duration_s`      float        DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

ALTER TABLE `disease_ontology_set`
  ADD COLUMN `UMLS`   varchar(200) DEFAULT NULL,
  ADD COLUMN `MedGen` varchar(200) DEFAULT NULL,
  ADD COLUMN `NCIT`   varchar(200) DEFAULT NULL,
  ADD COLUMN `GARD`   varchar(200) DEFAULT NULL,
  ADD COLUMN `ontology_mapping_release` varchar(32) DEFAULT NULL;
