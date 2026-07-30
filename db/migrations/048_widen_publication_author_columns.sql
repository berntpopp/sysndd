-- Migration: 048_widen_publication_author_columns
-- Description: Widen publication.Lastname / publication.Firstname from VARCHAR(50) to
--   VARCHAR(255) so a PubMed corporate byline cannot roll back a review save (issue #614).
--
-- The defect: PubMed records a consortium author in <CollectiveName> rather than
--   <LastName>/<ForeName>, and api/functions/pubmed-xml-parser.R assigns that collective name
--   to BOTH lastname and firstname (there is no surname to fall back on), so both columns are
--   exposed, not just Lastname. Consortium bylines routinely exceed 50 characters --
--   "Deciphering Developmental Disorders Study", "Autism Sequencing Consortium", and the
--   74-character "Ministerial Meeting on Population of the Non-Aligned Movement (1993: Bali)"
--   that PMID 12345678 resolves to in db/fixtures/playwright_e2e_baseline.sql. The INSERT then
--   fails with "Data too long for column 'Lastname' at row 1 [1406]" and, because publication
--   ingestion runs inside the review-save transaction, the curator's ENTIRE save is rolled back
--   as an opaque 500. Consortium-authored papers are common in NDD genetics, so this is a
--   production defect and not a fixture artifact.
--
-- Why widen rather than truncate: the byline is citation metadata. Truncating it at the write
--   site would silently corrupt an author name to protect a column width, which is the wrong
--   trade for a curation database. A complementary clamp does exist in the parser
--   (pubmed_clamp_author_name(), api/functions/pubmed-xml-parser.R) as a belt-and-braces bound
--   so that an unbounded upstream string can never again take down a save -- but it clamps at
--   the width this migration establishes, and it warns when it fires. Widening is the fix;
--   the clamp is the backstop.
--
-- Charset ruling (same class as 047's, read before "simplifying"): MySQL's ALTER TABLE ...
--   MODIFY COLUMN does NOT preserve a column's own character set when the statement omits one --
--   it falls back to the TABLE default. The `publication` table is declared DEFAULT CHARSET
--   utf8mb3, so a naive `MODIFY Lastname VARCHAR(255)` would silently convert the column to
--   utf8mb3 in any environment where it has drifted to utf8mb4 (a restore, a manual ALTER, a
--   test fixture -- exactly the drift already documented for disease_ontology_mapping and
--   variation_ontology_list in AGENTS.md), which for a non-BMP byline means data loss or a
--   hard "Incorrect string value" error. The charset and collation are therefore read back from
--   information_schema.COLUMNS and re-stated verbatim, falling back to the base-schema default
--   only when the lookup yields nothing.
--
-- Idempotent and restore-drift safe: each ALTER is guarded on the column's current
--   CHARACTER_MAXIMUM_LENGTH, so a rerun (or an environment already at 255+) no-ops, and a
--   missing column is skipped rather than erroring.

-- --- Lastname ------------------------------------------------------------------------------
SET @pub_lastname_len := (
  SELECT CHARACTER_MAXIMUM_LENGTH FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'publication'
    AND COLUMN_NAME = 'Lastname'
);

SET @pub_lastname_charset := IFNULL((
  SELECT CHARACTER_SET_NAME FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'publication'
    AND COLUMN_NAME = 'Lastname'
), 'utf8mb3');

SET @pub_lastname_collation := IFNULL((
  SELECT COLLATION_NAME FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'publication'
    AND COLUMN_NAME = 'Lastname'
), 'utf8mb3_general_ci');

SET @ddl := IF(@pub_lastname_len IS NOT NULL AND @pub_lastname_len < 255,
  CONCAT(
    'ALTER TABLE `publication` MODIFY COLUMN `Lastname` VARCHAR(255) ',
    'CHARACTER SET ', @pub_lastname_charset, ' COLLATE ', @pub_lastname_collation,
    ' DEFAULT NULL'
  ),
  'SELECT 1');
PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

-- --- Firstname -----------------------------------------------------------------------------
SET @pub_firstname_len := (
  SELECT CHARACTER_MAXIMUM_LENGTH FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'publication'
    AND COLUMN_NAME = 'Firstname'
);

SET @pub_firstname_charset := IFNULL((
  SELECT CHARACTER_SET_NAME FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'publication'
    AND COLUMN_NAME = 'Firstname'
), 'utf8mb3');

SET @pub_firstname_collation := IFNULL((
  SELECT COLLATION_NAME FROM information_schema.COLUMNS
  WHERE TABLE_SCHEMA = DATABASE()
    AND TABLE_NAME = 'publication'
    AND COLUMN_NAME = 'Firstname'
), 'utf8mb3_general_ci');

SET @ddl := IF(@pub_firstname_len IS NOT NULL AND @pub_firstname_len < 255,
  CONCAT(
    'ALTER TABLE `publication` MODIFY COLUMN `Firstname` VARCHAR(255) ',
    'CHARACTER SET ', @pub_firstname_charset, ' COLLATE ', @pub_firstname_collation,
    ' DEFAULT NULL'
  ),
  'SELECT 1');
PREPARE stmt FROM @ddl;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
