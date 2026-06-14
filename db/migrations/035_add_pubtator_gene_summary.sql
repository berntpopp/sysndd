-- Migration 035: PubtatorNDD precomputed per-gene summary table
--
-- The `GET /api/publication/pubtator/genes` endpoint collected the whole
-- `pubtator_human_gene_entity_view` and nested it in R (tidyr::nest + per-gene
-- purrr::map_int) on EVERY request. Profiling showed the raw view query is
-- ~50-100ms but the endpoint is ~800ms: the cost is the per-request R nesting,
-- not SQL. The frontend never consumes the nested publications/entities (it
-- requests flat fields and lazy-fetches per-gene publications via
-- /pubtator/table on row expand), so the nesting is pure overhead.
--
-- This table stores the flat per-gene aggregates so the endpoint can read them
-- directly (one indexed scan of ~350 rows) and LEFT JOIN enrichment, with no
-- R nesting. It is refreshed by the worker (pubtator_gene_summary_refresh),
-- which the nightly orchestrator (functions/pubtatornidd-nightly.R) calls after
-- the publication update + enrichment refresh. The endpoint falls back to the
-- live nest path when this table is empty (cold start before the first
-- refresh), so correctness never depends on the table being populated.
--
-- Idempotent: CREATE TABLE IF NOT EXISTS.

CREATE TABLE IF NOT EXISTS `pubtator_gene_summary` (
  `gene_symbol` VARCHAR(64) NOT NULL,
  `gene_name` VARCHAR(255) DEFAULT NULL,
  `hgnc_id` VARCHAR(20) DEFAULT NULL,
  `gene_normalized_id` VARCHAR(255) DEFAULT NULL,
  `publication_count` INT NOT NULL DEFAULT 0,
  `entities_count` INT NOT NULL DEFAULT 0,
  `is_novel` TINYINT NOT NULL DEFAULT 0,
  `oldest_pub_date` DATE DEFAULT NULL,
  `pmids` MEDIUMTEXT DEFAULT NULL,
  `refreshed_at` DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (`gene_symbol`),
  KEY `idx_pubtator_gene_summary_pubcount` (`publication_count`),
  KEY `idx_pubtator_gene_summary_novel` (`is_novel`),
  KEY `idx_pubtator_gene_summary_hgnc` (`hgnc_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
