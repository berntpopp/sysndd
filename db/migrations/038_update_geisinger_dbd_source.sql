-- Migration 038: Update Geisinger DBD source URL to NDD GeneHub
--
-- The original Developmental Brain Disorders database (dbd.geisingeradmi.org)
-- was retired and migrated to NDD GeneHub (nddgenehub.org). The legacy CSV
-- endpoint now 404s, which — because the comparisons refresh was historically
-- all-or-nothing — blocked every production comparison-source update.
--
-- NDD GeneHub publishes the canonical case-level "Full-Data.csv" export at a
-- stable path. It is the direct successor to the legacy DBD-Genes-Full-Data.csv
-- (one row per curated case: Gene Symbol, PubMed ID, the ID/ASD/EP/ADHD/SCZ/BD/CP
-- phenotype flags, and per-variant inheritance/chromosome). The parser
-- parse_geisinger_csv() in api/functions/comparisons-functions.R was rewritten
-- to aggregate these case-level rows to one row per gene (phenotype union,
-- distinct PubMed IDs, derived inheritance).
--
-- Old URL: https://dbd.geisingeradmi.org/downloads/DBD-Genes-Full-Data.csv (404)
-- New URL: https://nddgenehub.org/files/Full-Data.csv
-- Format unchanged: csv
--
-- Idempotent: UPDATE with a WHERE clause is naturally idempotent. Running it
-- again sets the same value; a second run affects 0 rows without error.
--
-- Fixes: https://github.com/berntpopp/sysndd/issues/502 (comparison-source repair)

UPDATE comparisons_config
SET source_url = 'https://nddgenehub.org/files/Full-Data.csv',
    file_format = 'csv'
WHERE source_name = 'geisinger_DBD';
