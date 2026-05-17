-- 021_add_publication_date_source.sql
-- Adds provenance for publication.Publication_date so the MCP can report
-- date confidence as a stored fact instead of a heuristic.
-- Values: 'pubmed' (full structured PubDate), 'pubmed_partial' (day/month
-- defaulted), 'medline_date' (parsed from <MedlineDate>), 'unknown' (no
-- parseable date). NULL on legacy rows until the backfill script runs.

ALTER TABLE `publication`
  ADD COLUMN `publication_date_source` VARCHAR(20) NULL DEFAULT NULL
  AFTER `Publication_date`;
