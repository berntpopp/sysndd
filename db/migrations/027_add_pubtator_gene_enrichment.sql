-- Migration 027: PubtatorNDD gene-count enrichment normalization
--
-- GitHub issue #175: the gene-prioritization table ranks genes by RAW
-- publication co-occurrence with NDD terms, which conflates true NDD relevance
-- with research-popularity bias. Heavily-studied genes (TP53, APP, MAPT, APOE)
-- surface in the top 10 with no specific NDD role (~40% top-10 false positives).
-- Normalizing a gene's NDD co-occurrence count by its TOTAL PubTator
-- publication count separates true NDD genes (0.1-0.6% NDD/Total) from
-- popularity noise (0.001-0.01%) by ~two orders of magnitude.
--
-- This migration adds the durable storage for that normalization layer:
--
--   * pubtator_corpus_stats     -- one row per refresh snapshot, recording the
--                                  NDD corpus size and total corpus size used,
--                                  with exactly one is_current = 1 row.
--   * pubtator_gene_enrichment  -- per-gene observed/background counts plus the
--                                  computed metrics (enrichment ratio, NPMI,
--                                  Fisher p-value, BH-FDR q-value).
--   * pubtator_gene_enrichment_view -- read view used by the API to join the
--                                  current metrics onto the gene view.
--
-- Counts are collected by the durable async worker job
-- `pubtator_enrichment_refresh` (network egress to PubTator); the web API never
-- computes these on a public request. Metric math lives in
-- api/functions/pubtator-enrichment-metrics.R (pure, unit-tested).
--
-- Idempotent: CREATE TABLE IF NOT EXISTS + CREATE OR REPLACE VIEW.

-- ---------------------------------------------------------------------------
-- Corpus-level snapshot. is_current_slot is a generated column giving a
-- partial-unique guarantee: at most one row may be the current snapshot.
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `pubtator_corpus_stats` (
  `corpus_stats_id` INT NOT NULL AUTO_INCREMENT,
  `ndd_corpus_size` INT NOT NULL,
  `total_corpus_size` BIGINT NOT NULL,
  `total_is_fallback` TINYINT NOT NULL DEFAULT 0,
  `genes_scored` INT NOT NULL DEFAULT 0,
  `refreshed_by` INT DEFAULT NULL,
  `is_current` TINYINT NOT NULL DEFAULT 0,
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  `is_current_slot` TINYINT
      GENERATED ALWAYS AS (CASE WHEN `is_current` = 1 THEN 1 ELSE NULL END) STORED,
  PRIMARY KEY (`corpus_stats_id`),
  UNIQUE KEY `idx_pubtator_corpus_stats_current` (`is_current_slot`),
  KEY `idx_pubtator_corpus_stats_created` (`created_at`),
  CONSTRAINT `fk_pubtator_corpus_stats_refreshed_by`
      FOREIGN KEY (`refreshed_by`) REFERENCES `user` (`user_id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- Per-gene normalized metrics for the current snapshot.
--   observed         -- NDD-corpus publications mentioning the gene
--   background_count -- total PubTator publications mentioning the gene
--   enrichment_ratio -- observed / (ndd_corpus * background / total_corpus)
--   npmi             -- normalized pointwise mutual information, [-1, 1]
--   fisher_p         -- one-sided (enrichment) Fisher exact p-value
--   fdr_bh           -- Benjamini-Hochberg adjusted q-value across all genes
-- ---------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS `pubtator_gene_enrichment` (
  `gene_enrichment_id` INT NOT NULL AUTO_INCREMENT,
  `corpus_stats_id` INT NOT NULL,
  `hgnc_id` VARCHAR(20) DEFAULT NULL,
  `gene_symbol` VARCHAR(64) NOT NULL,
  `observed` INT NOT NULL,
  `background_count` INT DEFAULT NULL,
  `enrichment_ratio` DOUBLE DEFAULT NULL,
  `npmi` DOUBLE DEFAULT NULL,
  `fisher_p` DOUBLE DEFAULT NULL,
  `fdr_bh` DOUBLE DEFAULT NULL,
  `created_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`gene_enrichment_id`),
  UNIQUE KEY `idx_pubtator_gene_enrichment_symbol` (`gene_symbol`),
  KEY `idx_pubtator_gene_enrichment_hgnc` (`hgnc_id`),
  KEY `idx_pubtator_gene_enrichment_corpus` (`corpus_stats_id`),
  KEY `idx_pubtator_gene_enrichment_ratio` (`enrichment_ratio`),
  KEY `idx_pubtator_gene_enrichment_npmi` (`npmi`),
  CONSTRAINT `fk_pubtator_gene_enrichment_corpus`
      FOREIGN KEY (`corpus_stats_id`) REFERENCES `pubtator_corpus_stats` (`corpus_stats_id`)
      ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------------
-- Serving view: per-gene current metrics with the corpus context attached.
-- The API left-joins this onto the gene listing so genes without a metric yet
-- (e.g. before the first refresh) still appear, with NULL metric columns.
-- Keep in sync with db/C_Rcommands_set-table-connections.R.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE
  ALGORITHM = UNDEFINED SQL SECURITY INVOKER
  VIEW `pubtator_gene_enrichment_view` AS
    SELECT
      ge.`gene_symbol` AS `gene_symbol`,
      ge.`hgnc_id` AS `hgnc_id`,
      ge.`observed` AS `observed`,
      ge.`background_count` AS `background_count`,
      ge.`enrichment_ratio` AS `enrichment_ratio`,
      ge.`npmi` AS `npmi`,
      ge.`fisher_p` AS `fisher_p`,
      ge.`fdr_bh` AS `fdr_bh`,
      cs.`ndd_corpus_size` AS `ndd_corpus_size`,
      cs.`total_corpus_size` AS `total_corpus_size`,
      cs.`total_is_fallback` AS `total_is_fallback`,
      cs.`created_at` AS `enrichment_refreshed_at`
    FROM `pubtator_gene_enrichment` ge
    JOIN `pubtator_corpus_stats` cs
      ON ge.`corpus_stats_id` = cs.`corpus_stats_id`
     AND cs.`is_current` = 1;
