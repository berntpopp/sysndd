-- app/tests/docs-screenshots/docs-overlay.sql
-- Documentation-screenshot data overlay. Applied by the docs global setup AFTER the
-- shared E2E baseline (db/fixtures/playwright_e2e_baseline.sql) on the isolated
-- `playwright` compose stack only. Never source this from migrations or production.
--
-- Purpose: the curator and reviewer screenshots need realistic queues (pending
-- reviews and statuses, re-review batches, a refused entity, user applications) and
-- must not show fixture wording ("Playwright-only ..."). Gene symbols, OMIM ids and
-- disease names are real; people are fictional (example.org mail; the one ORCID shown is
-- ORCID's own fictitious test record). Ids live in the 9100+ range and every block deletes before inserting, so the
-- overlay is idempotent.

-- ---------------------------------------------------------------------------
-- Replace fixture wording in the baseline CHD8 entity (entity 123).
-- ---------------------------------------------------------------------------
UPDATE `ndd_entity_review`
SET `synopsis` = 'Heterozygous de novo loss-of-function variants in CHD8 cause a neurodevelopmental disorder with autism, macrocephaly, a distinctive facial appearance and gastrointestinal problems; intellectual disability is variable.',
    `comment` = 'Phenotype and literature checked at re-review.'
WHERE `review_id` = 123;

UPDATE `ndd_entity_status`
SET `comment` = 'Multiple unrelated individuals with de novo variants and consistent phenotype.'
WHERE `status_id` = 123;

UPDATE `variation_ontology_list` SET `definition` = 'A variation that decreases or abolishes the function of the gene product.' WHERE `vario_id` = 'VariO:0001';
UPDATE `variation_ontology_list` SET `definition` = 'A variation that shortens the protein product, for example by introducing a premature stop codon.' WHERE `vario_id` = 'VariO:0015';
UPDATE `variation_ontology_list` SET `definition` = 'A variation that changes the amino acid sequence of the protein.' WHERE `vario_id` = 'VariO:0017';
UPDATE `variation_ontology_list` SET `definition` = 'A variation that affects RNA splicing.' WHERE `vario_id` = 'VariO:0508';

-- A real CHD8 publication replaces the synthetic PMID in the CHD8 review.
INSERT INTO `publication` (`publication_id`, `publication_type`, `Title`, `Publication_date`, `Journal_abbreviation`, `Journal`, `Lastname`, `Firstname`)
VALUES ('PMID:24998929', 'additional_references', 'Disruptive CHD8 mutations define a subtype of autism early in development.', '2014-07-17', 'Cell', 'Cell', 'Bernier', 'Raphael')
ON DUPLICATE KEY UPDATE `Title` = VALUES(`Title`);
UPDATE `ndd_review_publication_join` SET `publication_id` = 'PMID:24998929' WHERE `entity_id` = 123 AND `publication_id` = 'PMID:12345678';

INSERT INTO `phenotype_list` (`phenotype_id`, `HPO_term`, `HPO_term_definition`, `HPO_term_synonyms`) VALUES
  ('HP:0001249', 'Intellectual disability', 'Subnormal intellectual functioning which originates during the developmental period.', ''),
  ('HP:0001250', 'Seizure', 'A seizure is an intermittent abnormality of nervous system physiology.', ''),
  ('HP:0000717', 'Autism', 'Autism is a neurodevelopmental disorder characterized by impaired social interaction and communication.', ''),
  ('HP:0000256', 'Macrocephaly', 'Occipitofrontal (head) circumference greater than 97th centile.', ''),
  ('HP:0001252', 'Hypotonia', 'Hypotonia is an abnormally low muscle tone.', '')
ON DUPLICATE KEY UPDATE `HPO_term` = VALUES(`HPO_term`);

DELETE FROM `ndd_review_phenotype_connect` WHERE `review_phenotype_id` BETWEEN 9100 AND 9199;
INSERT INTO `ndd_review_phenotype_connect` (`review_phenotype_id`, `review_id`, `phenotype_id`, `modifier_id`, `entity_id`, `is_active`) VALUES
  (9101, 123, 'HP:0000717', 1, 123, 1),
  (9102, 123, 'HP:0000256', 1, 123, 1);

-- ---------------------------------------------------------------------------
-- Genes, inheritance and diseases for the extra entities and the Create entity wizard.
-- ---------------------------------------------------------------------------
INSERT INTO `non_alt_loci_set` (`hgnc_id`, `symbol`, `name`, `locus_group`, `locus_type`, `status`, `location`, `entrez_id`, `ensembl_gene_id`, `omim_id`) VALUES
  ('HGNC:29140', 'MAU2', 'MAU2 sister chromatid cohesion factor', 'protein-coding gene', 'gene with protein product', 'Approved', '19p13.11', '23383', 'ENSG00000129933', '614560'),
  ('HGNC:29529', 'TBL1XR1', 'TBL1X/Y related 1', 'protein-coding gene', 'gene with protein product', 'Approved', '3q26.32', '79718', 'ENSG00000177565', '608628'),
  ('HGNC:2745', 'DDX3X', 'DEAD-box helicase 3 X-linked', 'protein-coding gene', 'gene with protein product', 'Approved', 'Xp11.4', '1654', 'ENSG00000215301', '300160')
ON DUPLICATE KEY UPDATE `symbol` = VALUES(`symbol`), `name` = VALUES(`name`);

INSERT INTO `mode_of_inheritance_list` (`hpo_mode_of_inheritance_term`, `hpo_mode_of_inheritance_term_name`, `hpo_mode_of_inheritance_term_definition`, `inheritance_filter`, `inheritance_short_text`, `is_active`, `sort`) VALUES
  ('HP:0000007', 'Autosomal recessive inheritance', 'A mode of inheritance that is observed for traits related to a gene encoded on one of the autosomes in which a trait manifests in homozygotes.', 'Recessive', 'AR', 1, 2),
  ('HP:0001417', 'X-linked inheritance', 'A mode of inheritance that is observed for traits related to a gene encoded on the X chromosome.', 'X-linked', 'X', 1, 3)
ON DUPLICATE KEY UPDATE `hpo_mode_of_inheritance_term_name` = VALUES(`hpo_mode_of_inheritance_term_name`);

INSERT INTO `disease_ontology_set` (`disease_ontology_id_version`, `disease_ontology_id`, `disease_ontology_name`, `disease_ontology_source`, `disease_ontology_is_specific`, `hgnc_id`, `hpo_mode_of_inheritance_term`, `MONDO`, `is_active`) VALUES
  ('OMIM:135900_1', 'OMIM:135900', 'Coffin-Siris syndrome 1', 'mim2gene', 1, 'HGNC:18040', 'HP:0000006', 'MONDO:0007617', 1),
  ('OMIM:613721_1', 'OMIM:613721', 'Developmental and epileptic encephalopathy 11', 'mim2gene', 1, 'HGNC:10588', 'HP:0000006', 'MONDO:0013442', 1),
  ('OMIM:300855_1', 'OMIM:300855', 'Ogden syndrome', 'mim2gene', 1, 'HGNC:18704', 'HP:0001417', 'MONDO:0010438', 1),
  ('OMIM:621570_1', 'OMIM:621570', 'Cornelia de Lange syndrome 7', 'mim2gene', 1, 'HGNC:29140', 'HP:0000006', NULL, 1),
  ('OMIM:616944_1', 'OMIM:616944', 'Intellectual developmental disorder, autosomal dominant 41', 'mim2gene', 1, 'HGNC:29529', 'HP:0000006', 'MONDO:0014834', 1),
  ('OMIM:300958_1', 'OMIM:300958', 'Intellectual developmental disorder, X-linked syndromic, Snijders Blok type', 'mim2gene', 1, 'HGNC:2745', 'HP:0001417', NULL, 1)
ON DUPLICATE KEY UPDATE `disease_ontology_name` = VALUES(`disease_ontology_name`), `is_active` = 1;

-- ---------------------------------------------------------------------------
-- Fictional people. Approved curators/reviewers author the pending work; two
-- unapproved applicants fill the Application Queue. Passwords reuse a fixture hash.
-- ---------------------------------------------------------------------------
DELETE FROM `re_review_assignment` WHERE `re_review_batch` BETWEEN 9100 AND 9199;
DELETE FROM `re_review_entity_connect` WHERE `re_review_entity_id` BETWEEN 9100 AND 9199;
DELETE FROM `ndd_review_publication_join` WHERE `review_publication_id` BETWEEN 9100 AND 9199;
DELETE FROM `ndd_entity_review` WHERE `review_id` BETWEEN 9100 AND 9199;
DELETE FROM `ndd_entity_status` WHERE `status_id` BETWEEN 9100 AND 9199;
DELETE FROM `ndd_entity` WHERE `entity_id` BETWEEN 9100 AND 9199;
UPDATE `ndd_entity_review` SET `review_user_id` = 1 WHERE `review_user_id` BETWEEN 9101 AND 9199;
UPDATE `ndd_entity_status` SET `status_user_id` = 1 WHERE `status_user_id` BETWEEN 9101 AND 9199;
DELETE FROM `user` WHERE `user_id` BETWEEN 9101 AND 9199;
INSERT INTO `user` (`user_id`, `user_name`, `password`, `email`, `orcid`, `abbreviation`, `first_name`, `family_name`, `user_role`, `comment`, `terms_agreed`, `approved`, `rereview_request`, `created_at`)
SELECT v.id, v.uname, u.`password`, v.mail, v.orcid, v.abbr, v.fname, v.lname, v.urole, v.ucomment, 1, v.appr, 0, v.created
FROM (
  SELECT 9101 AS id, 'akessler' AS uname, 'anna.kessler@example.org' AS mail, CAST(NULL AS CHAR(50)) AS orcid, 'AK' AS abbr, 'Anna' AS fname, 'Kessler' AS lname, 'Reviewer' AS urole, 'Clinical geneticist' AS ucomment, 1 AS appr, '2025-03-02 10:00:00' AS created
  UNION ALL SELECT 9102, 'mrossi', 'marco.rossi@example.org', NULL, 'MR', 'Marco', 'Rossi', 'Curator', 'Neuropaediatrician', 1, '2024-11-12 10:00:00'
  UNION ALL SELECT 9103, 'lberg', 'lena.berg@example.org', '0000-0002-1825-0097', 'LB', 'Lena', 'Berg', 'Reviewer', 'Genetic counsellor, university hospital; interested in epilepsy genes.', 0, '2026-11-17 09:30:00'
  UNION ALL SELECT 9104, 'tnakamura', 'taro.nakamura@example.org', NULL, 'TN', 'Taro', 'Nakamura', 'Viewer', 'PhD student, neurodevelopmental genomics.', 0, '2026-11-19 14:05:00'
) v
JOIN `user` u ON u.`user_name` = 'pw_user';

-- ---------------------------------------------------------------------------
-- Entities with approved status and review, plus pending work for the queues.
-- ---------------------------------------------------------------------------

INSERT INTO `ndd_entity` (`entity_id`, `hgnc_id`, `hpo_mode_of_inheritance_term`, `disease_ontology_id_version`, `ndd_phenotype`, `entry_date`, `entry_source`, `entry_user_id`, `is_active`) VALUES
  (9101, 'HGNC:18040', 'HP:0000006', 'OMIM:135900_1', 1, '2022-05-04 00:00:00', 'docs_overlay', 9102, 1),
  (9102, 'HGNC:10588', 'HP:0000006', 'OMIM:613721_1', 1, '2022-05-04 00:00:00', 'docs_overlay', 9102, 1),
  (9103, 'HGNC:18704', 'HP:0001417', 'OMIM:300855_1', 1, '2022-05-04 00:00:00', 'docs_overlay', 9102, 1),
  (9104, 'HGNC:29529', 'HP:0000006', 'OMIM:616944_1', 1, '2022-05-04 00:00:00', 'docs_overlay', 9102, 1);

INSERT INTO `ndd_entity_status` (`status_id`, `entity_id`, `category_id`, `is_active`, `status_date`, `status_user_id`, `status_approved`, `approving_user_id`, `comment`, `problematic`) VALUES
  (9101, 9101, 1, 1, '2022-05-04 00:00:00', 9102, 1, 9102, NULL, 0),
  (9102, 9102, 1, 1, '2022-05-04 00:00:00', 9102, 1, 9102, NULL, 0),
  (9103, 9103, 2, 1, '2022-05-04 00:00:00', 9102, 1, 9102, NULL, 0),
  (9104, 9104, 1, 1, '2022-05-04 00:00:00', 9102, 1, 9102, NULL, 0),
  -- pending status changes (Status Queue; the CHD8 one also flags the review row)
  (9111, 123, 1, 0, '2026-11-18 11:20:00', 9101, 0, NULL, 'Confirmed at re-review; more than three unrelated families published.', 0),
  (9112, 9103, 3, 0, '2026-11-18 15:42:00', 9101, 0, NULL, 'Most reported variants are from one extended family; downgrade suggested.', 1),
  (9113, 9102, 1, 0, '2026-11-19 08:05:00', 9102, 0, NULL, 'Re-review: category unchanged.', 0);

INSERT INTO `ndd_entity_review` (`review_id`, `entity_id`, `synopsis`, `is_primary`, `review_date`, `review_user_id`, `review_approved`, `approving_user_id`, `comment`) VALUES
  (9101, 9101, 'Heterozygous loss-of-function variants in ARID1B cause Coffin-Siris syndrome with intellectual disability, speech delay, coarse facial features and hypoplastic fifth digits or nails.', 1, '2022-05-04 00:00:00', 9102, 1, 9102, NULL),
  (9102, 9102, 'De novo missense variants in SCN2A cause early-onset developmental and epileptic encephalopathy; later-onset epilepsy and autism with intellectual disability are also reported.', 1, '2022-05-04 00:00:00', 9102, 1, 9102, NULL),
  (9103, 9103, 'Hemizygous missense variants in NAA10 cause Ogden syndrome with global developmental delay, hypotonia, cardiac arrhythmia and an aged appearance in affected boys.', 1, '2022-05-04 00:00:00', 9102, 1, 9102, NULL),
  (9104, 9104, 'De novo missense and truncating variants in TBL1XR1 cause intellectual disability with autism features; a recurrent missense variant causes Pierpont syndrome.', 1, '2022-05-04 00:00:00', 9102, 1, 9102, NULL),
  -- pending reviews (Review Queue)
  (9111, 123, 'Heterozygous de novo loss-of-function variants in CHD8 cause a neurodevelopmental disorder with autism, macrocephaly, a distinctive facial appearance, sleep problems and gastrointestinal symptoms; intellectual disability is present in about half of individuals.', 0, '2026-11-18 11:18:00', 9101, 0, NULL, 'Synopsis updated with sleep and GI features.'),
  (9112, 9101, 'Heterozygous loss-of-function variants in ARID1B cause Coffin-Siris syndrome and nonsyndromic intellectual disability with speech delay, hypertrichosis and hypoplastic fifth nails.', 0, '2026-11-19 09:40:00', 9101, 0, NULL, 'Added nonsyndromic ID presentation.'),
  (9113, 9102, 'De novo missense variants in SCN2A cause developmental and epileptic encephalopathy with neonatal or infantile onset; gain-of-function variants respond to sodium channel blockers.', 0, '2026-11-19 08:03:00', 9102, 0, NULL, NULL);

-- ---------------------------------------------------------------------------
-- Re-review batches: 9101 assigned to akessler (one submitted entity, for Curation
-- mode), 9102 unassigned, 9103 assigned to akessler with a refused entity.
-- ---------------------------------------------------------------------------
INSERT INTO `re_review_assignment` (`user_id`, `re_review_batch`) VALUES (9101, 9101);
INSERT INTO `re_review_assignment` (`user_id`, `re_review_batch`) VALUES (9101, 9103);

INSERT INTO `re_review_entity_connect` (`re_review_entity_id`, `entity_id`, `re_review_batch`, `re_review_review_saved`, `re_review_status_saved`, `re_review_submitted`, `re_review_approved`, `re_review_refused`, `re_review_refusal_comment`, `re_review_refused_user_id`, `re_review_refused_date`, `status_id`, `review_id`)
SELECT 9101, 9101, 9101, 1, 1, 1, 0, 0, NULL, NULL, NULL, 9101, 9112
UNION ALL SELECT 9102, 9102, 9102, 0, 0, 0, 0, 0, NULL, NULL, NULL, 9102, 9102
UNION ALL SELECT 9104, 9104, 9102, 0, 0, 0, 0, 0, NULL, NULL, NULL, 9104, 9104
UNION ALL SELECT 9103, 9103, 9103, 0, 0, 0, 0, 1,
  'X-linked inheritance with affected heterozygous females; needs a specialist in X-linked disorders.',
  9101, '2026-11-19 16:12:00', 9103, 9103;

-- ---------------------------------------------------------------------------
-- Attribute the baseline CHD8 review/status to fictional people instead of the
-- `system` account, and make the needs-confirmation variation assertion the
-- strongest so it sorts first in the Variation suggestions queue.
-- ---------------------------------------------------------------------------
UPDATE `ndd_entity_review` SET `review_user_id` = 9101 WHERE `review_id` = 123;
UPDATE `ndd_entity_status` SET `status_user_id` = 9102 WHERE `status_id` = 123;
UPDATE `variation_ontology_evidence` SET `evidence_strength` = 3, `evidence_summary` = '4 ClinVar records, max 3 stars' WHERE `evidence_id` = 9617;
UPDATE `variation_ontology_evidence` SET `evidence_strength` = 2, `evidence_summary` = '3 ClinVar records, max 2 stars' WHERE `evidence_id` = 9608;
