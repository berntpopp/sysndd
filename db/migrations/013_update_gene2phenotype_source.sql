-- Migration 013: Update Gene2Phenotype source URL and format
--
-- Gene2Phenotype moved from legacy download to API-based endpoint.
-- The new endpoint returns plain CSV (not gzipped).
--
-- Old URL: https://www.ebi.ac.uk/gene2phenotype/downloads/DDG2P.csv.gz
-- New URL: https://www.ebi.ac.uk/gene2phenotype/api/panel/DD/download
-- Old format: csv.gz
-- New format: csv
--
-- Idempotent: UPDATE with WHERE clause is naturally idempotent.
-- Running multiple times sets same values; second run affects 0 rows but does not error.
--
-- Fixes: https://github.com/berntpopp/sysndd/issues/156

UPDATE comparisons_config
SET source_url = 'https://www.ebi.ac.uk/gene2phenotype/api/panel/DD/download',
    file_format = 'csv'
WHERE source_name = 'gene2phenotype';
