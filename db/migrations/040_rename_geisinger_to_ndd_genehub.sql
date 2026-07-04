-- Migration 040: Rename the comparison source key geisinger_DBD -> ndd_genehub
--
-- The Developmental Brain Disorders database moved off Geisinger to NDD GeneHub
-- (nddgenehub.org, migration 038). The source is now surfaced everywhere as
-- "NDD GeneHub", so the internal source key/`list` value is renamed to
-- `ndd_genehub` to remove the stale "geisinger" identifier from the API `list`
-- field, exports, and column keys. Code (parser, dispatch, frontend columns)
-- uses the new key; this migration renames the existing data + config to match.
--
-- Idempotent: UPDATE ... WHERE renames only the old rows; a second run matches 0.

UPDATE comparisons_config
SET source_name = 'ndd_genehub'
WHERE source_name = 'geisinger_DBD';

UPDATE ndd_database_comparison
SET list = 'ndd_genehub'
WHERE list = 'geisinger_DBD';
