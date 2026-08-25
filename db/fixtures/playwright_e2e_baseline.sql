-- db/fixtures/playwright_e2e_baseline.sql
-- Shared Playwright E2E baseline fixture. Sourced by `make playwright-stack`
-- (via `_playwright-seed-e2e-baseline`) and re-seeded before every
-- `npx playwright test` run (global-setup.ts), so the data-dependent baseline
-- specs (public table filters, curation comparisons, gene-detail cards,
-- slow-provider resilience, Modify Entity) have rows to assert against. Also
-- sourced by `make docs-screenshots` (which layers no extra data on top).
--
-- It provisions minimal, self-contained fixture rows AND replaces the heavy
-- production read views with simplified equivalents so the small fixture
-- surfaces through the app. It is synthetic UI fixture data and must never be
-- referenced from production migrations or imported into production data
-- preparation paths.

INSERT INTO `non_alt_loci_set` (
  `hgnc_id`,
  `symbol`,
  `name`,
  `locus_group`,
  `locus_type`,
  `status`
) VALUES (
  'HGNC:20153',
  'CHD8',
  'chromodomain helicase DNA binding protein 8',
  'protein-coding gene',
  'gene with protein product',
  'Approved'
)
ON DUPLICATE KEY UPDATE
  `symbol` = VALUES(`symbol`),
  `name` = VALUES(`name`),
  `locus_group` = VALUES(`locus_group`),
  `locus_type` = VALUES(`locus_type`),
  `status` = VALUES(`status`);

-- Gene-detail UI/UX e2e fixtures (app/tests/e2e/genes-detail-ui-ux.spec.ts and
-- gene-page-own-data-priority.spec.ts). ARID1B carries real gnomAD v4 constraint
-- scores so the gnomAD constraint MATRIX renders (the dense-data layout the
-- overflow checks exercise); NAA10 has no constraint data so the no-data empty
-- state + "view on gnomAD" link render. Without these rows /Genes/ARID1B and
-- /Genes/NAA10 404 and the specs time out waiting for the gene heading.
INSERT INTO `non_alt_loci_set` (
  `hgnc_id`,
  `symbol`,
  `name`,
  `locus_group`,
  `locus_type`,
  `status`,
  `gnomad_constraints`
) VALUES
  (
    'HGNC:18040',
    'ARID1B',
    'AT-rich interaction domain 1B',
    'protein-coding gene',
    'gene with protein product',
    'Approved',
    '{"pLI":1,"oe_lof":0.15062,"oe_lof_lower":0.111,"oe_lof_upper":0.205,"oe_mis":0.95931,"oe_mis_lower":0.929,"oe_mis_upper":0.989,"oe_syn":1.1558,"oe_syn_lower":1.105,"oe_syn_upper":1.208,"exp_lof":192.54,"obs_lof":29,"exp_mis":2977.1,"obs_mis":2856,"exp_syn":1198.3,"obs_syn":1385,"lof_z":9.986,"mis_z":0.81072,"syn_z":-2.9392}'
  ),
  (
    'HGNC:18704',
    'NAA10',
    'N-alpha-acetyltransferase 10, NatA catalytic subunit',
    'protein-coding gene',
    'gene with protein product',
    'Approved',
    NULL
  )
ON DUPLICATE KEY UPDATE
  `symbol` = VALUES(`symbol`),
  `name` = VALUES(`name`),
  `locus_group` = VALUES(`locus_group`),
  `locus_type` = VALUES(`locus_type`),
  `status` = VALUES(`status`),
  `gnomad_constraints` = VALUES(`gnomad_constraints`);

-- Slow-provider resilience e2e fixture (app/tests/e2e/slow-provider-resilience.spec.ts).
-- The spec loads /Genes/SCN2A and stubs every /api/external/** call with a 20s
-- delay to prove the gene-page shell + external-card frames render without
-- waiting on the upstream. That gene must EXIST: an unseeded symbol renders the
-- gene shell briefly (h1 from the route) and then the missing-record fetch
-- redirects to the SPA 404 page, so the external-card column never mounts and
-- the spec flakes. A bare gene row (no entities/constraints needed) keeps the
-- gene page on-route and the resilience check deterministic.
INSERT INTO `non_alt_loci_set` (
  `hgnc_id`,
  `symbol`,
  `name`,
  `locus_group`,
  `locus_type`,
  `status`
) VALUES (
  'HGNC:10588',
  'SCN2A',
  'sodium voltage-gated channel alpha subunit 2',
  'protein-coding gene',
  'gene with protein product',
  'Approved'
)
ON DUPLICATE KEY UPDATE
  `symbol` = VALUES(`symbol`),
  `name` = VALUES(`name`),
  `locus_group` = VALUES(`locus_group`),
  `locus_type` = VALUES(`locus_type`),
  `status` = VALUES(`status`);

INSERT INTO `mode_of_inheritance_list` (
  `hpo_mode_of_inheritance_term`,
  `hpo_mode_of_inheritance_term_name`,
  `hpo_mode_of_inheritance_term_definition`,
  `inheritance_filter`,
  `inheritance_short_text`,
  `is_active`,
  `sort`
) VALUES (
  'HP:0000006',
  'Autosomal dominant inheritance',
  'A mode of inheritance that is observed for traits related to a gene encoded on one of the autosomes.',
  'Dominant',
  'AD',
  1,
  1
)
ON DUPLICATE KEY UPDATE
  `hpo_mode_of_inheritance_term_name` = VALUES(`hpo_mode_of_inheritance_term_name`),
  `hpo_mode_of_inheritance_term_definition` = VALUES(`hpo_mode_of_inheritance_term_definition`),
  `inheritance_filter` = VALUES(`inheritance_filter`),
  `inheritance_short_text` = VALUES(`inheritance_short_text`),
  `is_active` = VALUES(`is_active`),
  `sort` = VALUES(`sort`);

INSERT INTO `disease_ontology_set` (
  `disease_ontology_id_version`,
  `disease_ontology_id`,
  `disease_ontology_name`,
  `disease_ontology_source`,
  `disease_ontology_is_specific`,
  `MONDO`,
  `is_active`
) VALUES (
  'MONDO:0100038_2026',
  'MONDO:0100038',
  'CHD8-related neurodevelopmental disorder',
  'MONDO',
  1,
  'MONDO:0100038',
  1
)
ON DUPLICATE KEY UPDATE
  `disease_ontology_id` = VALUES(`disease_ontology_id`),
  `disease_ontology_name` = VALUES(`disease_ontology_name`),
  `disease_ontology_source` = VALUES(`disease_ontology_source`),
  `disease_ontology_is_specific` = VALUES(`disease_ontology_is_specific`),
  `MONDO` = VALUES(`MONDO`),
  `is_active` = VALUES(`is_active`);

INSERT INTO `phenotype_list` (
  `phenotype_id`,
  `HPO_term`,
  `HPO_term_definition`,
  `HPO_term_synonyms`
) VALUES (
  'HP:0001263',
  'Global developmental delay',
  'A delay in the achievement of motor or mental milestones in the domains of development of a child.',
  'Developmental delay'
)
ON DUPLICATE KEY UPDATE
  `HPO_term` = VALUES(`HPO_term`),
  `HPO_term_definition` = VALUES(`HPO_term_definition`),
  `HPO_term_synonyms` = VALUES(`HPO_term_synonyms`);

INSERT INTO `variation_ontology_list` (
  `vario_id`,
  `vario_name`,
  `definition`,
  `obsolete`,
  `is_active`,
  `sort`
) VALUES (
  'VariO:0001',
  'loss of function variant',
  'Synthetic Playwright-only fixture term used to exercise the review modal.',
  0,
  1,
  1
)
ON DUPLICATE KEY UPDATE
  `vario_name` = VALUES(`vario_name`),
  `definition` = VALUES(`definition`),
  `obsolete` = VALUES(`obsolete`),
  `is_active` = VALUES(`is_active`),
  `sort` = VALUES(`sort`);

-- Variation-ontology provenance fixture terms (#608). Three extra VariO terms so
-- the curation three-zone picker has DISTINCT content in each zone and the public
-- entity card can show a curator-authored term next to machine-derived ones:
--   VariO:0015 -> curated + `confirmed`          -> Confirmed zone
--   VariO:0017 -> curated + `active_unconfirmed`  -> Needs confirmation zone
--   VariO:0508 -> NOT curated + `suggested`       -> Suggested zone
-- VariO:0001 (above) deliberately gets NO assertion row, so it stays the
-- curator-authored (`provenance: null`) control case.
-- Real VariO ids/names; the definitions are synthetic Playwright-only text,
-- matching the VariO:0001 row.
INSERT INTO `variation_ontology_list` (
  `vario_id`,
  `vario_name`,
  `definition`,
  `obsolete`,
  `is_active`,
  `sort`
) VALUES
  (
    'VariO:0015',
    'protein truncation',
    'Synthetic Playwright-only fixture term used to exercise the confirmed provenance zone.',
    0,
    1,
    2
  ),
  (
    'VariO:0017',
    'nonsynonymous variation',
    'Synthetic Playwright-only fixture term used to exercise the needs-confirmation provenance zone.',
    0,
    1,
    3
  ),
  (
    'VariO:0508',
    'splice variation',
    'Synthetic Playwright-only fixture term used to exercise the suggested provenance zone.',
    0,
    1,
    4
  )
ON DUPLICATE KEY UPDATE
  `vario_name` = VALUES(`vario_name`),
  `definition` = VALUES(`definition`),
  `obsolete` = VALUES(`obsolete`),
  `is_active` = VALUES(`is_active`),
  `sort` = VALUES(`sort`);

-- PMID 12345678 is a real PubMed record whose only author is a 74-character
-- `CollectiveName` ("Ministerial Meeting on Population of the Non-Aligned Movement
-- (1993: Bali)"). That used to overflow `publication`.`Lastname` VARCHAR(50) and roll
-- back the whole review save as an opaque 500; migration 048 widened both author
-- columns to VARCHAR(255) (#614), so it no longer does. It stays as the fixture PMID
-- deliberately -- it is the repo's only regression pressure on that path. Do NOT swap
-- in a short-authored PMID.
--
-- SHAPE MATTERS (#635). `publication_id` carries the `PMID:` prefix and
-- `publication_type` is `additional_references` | `gene_review`, exactly as production
-- stores them (verified live: 8148 / 1099 rows, zero of any other type). This fixture
-- previously seeded `'12345678'` / `'PMID'`, which matches NEITHER filter in
-- `useReviewForm.loadReviewData()`, so the row rendered as no chip at all -- which is
-- why the #635 publication-removal bug shipped without end-to-end coverage. Seeding it
-- production-shaped is what lets `app/tests/e2e/review.publication-removal.spec.ts`
-- exist.
--
-- Because the row is already in `publication`, `publication_write_prepare()` finds it
-- by id and skips the PubMed fetch entirely, so a review save is offline and
-- deterministic.
INSERT INTO `publication` (
  `publication_id`,
  `publication_type`,
  `Title`,
  `Abstract`,
  `Publication_date`,
  `Journal_abbreviation`,
  `Journal`
) VALUES (
  'PMID:12345678',
  'additional_references',
  'Synthetic CHD8 review fixture for documentation screenshots',
  'Synthetic Playwright-only publication fixture.',
  '2026-01-01 00:00:00',
  'SysNDD Docs',
  'SysNDD Documentation Fixtures'
)
ON DUPLICATE KEY UPDATE
  `publication_type` = VALUES(`publication_type`),
  `Title` = VALUES(`Title`),
  `Abstract` = VALUES(`Abstract`),
  `Publication_date` = VALUES(`Publication_date`),
  `Journal_abbreviation` = VALUES(`Journal_abbreviation`),
  `Journal` = VALUES(`Journal`);

INSERT INTO `ndd_entity` (
  `entity_id`,
  `hgnc_id`,
  `hpo_mode_of_inheritance_term`,
  `disease_ontology_id_version`,
  `ndd_phenotype`,
  `entry_source`,
  `entry_user_id`,
  `is_active`
) VALUES (
  123,
  'HGNC:20153',
  'HP:0000006',
  'MONDO:0100038_2026',
  1,
  'playwright_e2e_baseline',
  1,
  1
)
ON DUPLICATE KEY UPDATE
  `hgnc_id` = VALUES(`hgnc_id`),
  `hpo_mode_of_inheritance_term` = VALUES(`hpo_mode_of_inheritance_term`),
  `disease_ontology_id_version` = VALUES(`disease_ontology_id_version`),
  `ndd_phenotype` = VALUES(`ndd_phenotype`),
  `entry_source` = VALUES(`entry_source`),
  `entry_user_id` = VALUES(`entry_user_id`),
  `is_active` = VALUES(`is_active`);

INSERT INTO `ndd_entity_review` (
  `review_id`,
  `entity_id`,
  `synopsis`,
  `is_primary`,
  `review_date`,
  `review_user_id`,
  `review_approved`,
  `approving_user_id`,
  `comment`
) VALUES (
  123,
  123,
  'CHD8-related neurodevelopmental disorder is represented here as a Playwright-only documentation fixture.',
  1,
  '2026-01-01 00:00:00',
  1,
  1,
  1,
  'Synthetic documentation screenshot fixture.'
)
ON DUPLICATE KEY UPDATE
  `entity_id` = VALUES(`entity_id`),
  `synopsis` = VALUES(`synopsis`),
  `is_primary` = VALUES(`is_primary`),
  `review_date` = VALUES(`review_date`),
  `review_user_id` = VALUES(`review_user_id`),
  `review_approved` = VALUES(`review_approved`),
  `approving_user_id` = VALUES(`approving_user_id`),
  `comment` = VALUES(`comment`);

INSERT INTO `ndd_entity_status` (
  `status_id`,
  `entity_id`,
  `category_id`,
  `is_active`,
  `status_date`,
  `status_user_id`,
  `status_approved`,
  `approving_user_id`,
  `comment`,
  `problematic`
) VALUES (
  123,
  123,
  1,
  1,
  '2026-01-01 00:00:00',
  1,
  1,
  1,
  'Synthetic documentation screenshot fixture.',
  0
)
ON DUPLICATE KEY UPDATE
  `entity_id` = VALUES(`entity_id`),
  `category_id` = VALUES(`category_id`),
  `is_active` = VALUES(`is_active`),
  `status_date` = VALUES(`status_date`),
  `status_user_id` = VALUES(`status_user_id`),
  `status_approved` = VALUES(`status_approved`),
  `approving_user_id` = VALUES(`approving_user_id`),
  `comment` = VALUES(`comment`),
  `problematic` = VALUES(`problematic`);

INSERT INTO `ndd_review_phenotype_connect` (
  `review_phenotype_id`,
  `review_id`,
  `phenotype_id`,
  `modifier_id`,
  `entity_id`,
  `is_active`
) VALUES (
  123,
  123,
  'HP:0001263',
  1,
  123,
  1
)
ON DUPLICATE KEY UPDATE
  `review_id` = VALUES(`review_id`),
  `phenotype_id` = VALUES(`phenotype_id`),
  `modifier_id` = VALUES(`modifier_id`),
  `entity_id` = VALUES(`entity_id`),
  `is_active` = VALUES(`is_active`);

-- Reset the curated variation-ontology set for entity 123 before re-inserting it.
--
-- This DELETE is what makes re-seeding genuinely RESTORATIVE for this table, and
-- it is required rather than tidy. `ON DUPLICATE KEY UPDATE` on a fixed primary
-- key cannot undo what a review save does here:
--
--   * `variation_ontology_replace_for_review()` DELETEs every connect row for the
--     review and re-INSERTs the submitted terms, so the rows come back with fresh
--     AUTO_INCREMENT ids. The fixture's fixed ids (123, 9615, 9617) no longer
--     exist, so the upserts insert *duplicates* instead of restoring the originals.
--   * Accepting a suggested term (#608) adds a connect row the fixture never
--     declares — e.g. `VariO:0508`, or `VariO:0017` under modifier 5. Nothing in
--     an upsert-only fixture can remove it, so it leaks into every later test and
--     the public-read spec then sees a `suggested` term in the curated set.
--
-- Both were observed: after one run of the curation write specs this table held
-- five rows with ids 9617/9629/9630/9631/9632 instead of the seeded three.
-- The fixture owns entity 123 outright, so scoping the DELETE to it is safe.
DELETE FROM `ndd_review_variation_ontology_connect` WHERE `entity_id` = 123;

INSERT INTO `ndd_review_variation_ontology_connect` (
  `review_vario_id`,
  `review_id`,
  `vario_id`,
  `modifier_id`,
  `entity_id`,
  `is_active`
) VALUES (
  123,
  123,
  'VariO:0001',
  1,
  123,
  1
)
ON DUPLICATE KEY UPDATE
  `review_id` = VALUES(`review_id`),
  `vario_id` = VALUES(`vario_id`),
  `modifier_id` = VALUES(`modifier_id`),
  `entity_id` = VALUES(`entity_id`),
  `is_active` = VALUES(`is_active`);

-- Two more curated variation-ontology terms on review 123 so the public entity
-- card serves them alongside VariO:0001. There is deliberately NO connect row
-- for VariO:0508: a `suggested` assertion must stay OUT of the curated set so it
-- can be the Suggested-zone case, and it must never surface on the public read.
INSERT INTO `ndd_review_variation_ontology_connect` (
  `review_vario_id`,
  `review_id`,
  `vario_id`,
  `modifier_id`,
  `entity_id`,
  `is_active`
) VALUES
  (9615, 123, 'VariO:0015', 1, 123, 1),
  (9617, 123, 'VariO:0017', 1, 123, 1)
ON DUPLICATE KEY UPDATE
  `review_id` = VALUES(`review_id`),
  `vario_id` = VALUES(`vario_id`),
  `modifier_id` = VALUES(`modifier_id`),
  `entity_id` = VALUES(`entity_id`),
  `is_active` = VALUES(`is_active`);

-- migration 047's `chk_confirmed_attribution` CHECK REJECTS a `confirmed` row
-- with a NULL `confirmed_by`/`confirmed_at`, and `confirmed_by` is an FK to
-- `user`.`user_id`, whose values are AUTO_INCREMENT and therefore not fixed. So
-- resolve the attribution user by NAME (pw_curator, provisioned by
-- playwright_users.sql, which `make playwright-stack` and global-setup.ts both
-- seed BEFORE this file), falling back to the lowest existing user id so the
-- fixture still applies against a database seeded with different accounts.
SET @vario_confirmed_by := COALESCE(
  (SELECT `user_id` FROM `user` WHERE `user_name` = 'pw_curator' LIMIT 1),
  (SELECT MIN(`user_id`) FROM `user`)
);

-- Variation-ontology provenance assertions for entity 123 (#608).
--
-- DELIBERATE OMISSION — DO NOT "COMPLETE" THIS FIXTURE: there is NO assertion
-- row for VariO:0001. That absence IS the curator-authored case. The public read
-- serves `provenance: null` for it, the entity card must render it as the
-- pre-#608 chip with no provenance affordance, and the curation form must file it
-- under Confirmed as curator-authored. Adding an assertion for VariO:0001 would
-- silently delete the only control case in the fixture.
--
-- (VariO:0017, modifier 5) is included ON PURPOSE, in a DIFFERENT state from
-- (VariO:0017, modifier 1): modifier_list defines both `present` (1) and
-- `absent` (5) as valid for variation, and migration 047 makes modifier_id part
-- of the assertion identity because those are two different claims. Seeding the
-- same CURIE in two modifiers and two states proves the identity invariant in a
-- real browser — the same term appears in Needs-confirmation (modifier 1) and
-- Suggested (modifier 5) at once, which can only be keyed correctly on the full
-- `<modifier_id>-<vario_id>` tag. Keyed on vario_id alone, confirming one would
-- confirm the other and the zone partition would collapse.
INSERT INTO `variation_ontology_assertion` (
  `assertion_id`,
  `entity_id`,
  `vario_id`,
  `modifier_id`,
  `state`,
  `confirmed_by`,
  `confirmed_at`,
  `rejected_reason`
) VALUES
  (9615, 123, 'VariO:0015', 1, 'confirmed', @vario_confirmed_by, '2026-02-01 09:00:00', NULL),
  (9617, 123, 'VariO:0017', 1, 'active_unconfirmed', NULL, NULL, NULL),
  (9618, 123, 'VariO:0017', 5, 'suggested', NULL, NULL, NULL),
  (9608, 123, 'VariO:0508', 1, 'suggested', NULL, NULL, NULL)
ON DUPLICATE KEY UPDATE
  `entity_id` = VALUES(`entity_id`),
  `vario_id` = VALUES(`vario_id`),
  `modifier_id` = VALUES(`modifier_id`),
  `state` = VALUES(`state`),
  `confirmed_by` = VALUES(`confirmed_by`),
  `confirmed_at` = VALUES(`confirmed_at`),
  `rejected_reason` = VALUES(`rejected_reason`);

-- Evidence rows behind those assertions. `variation_ontology_evidence` is UNIQUE
-- on (assertion_id, source_key, batch_id) and `evidence_summary` is NOT NULL.
--
-- The `evidence_json` payloads carry ONLY fields the real import manifests are
-- documented to record: ClinVar variation ids, classification, review stars,
-- consequence, and the matched OMIM identifier. There are deliberately NO
-- HGVS/protein labels (e.g. `p.Thr215Pro`) — the importer never recorded them,
-- and fabricating one here would train the UI to render a field that does not
-- exist in production.
--
-- assertion 9617 (VariO:0017) is the load-bearing weak-evidence case from the
-- issue's worked example: 2 ClinVar records, both Likely pathogenic, both 1-star
-- single-submitter, `evidence_strength = 1`, summary "2 ClinVar records, max 1 star".
-- assertion 9615 additionally carries a SECOND source with a NULL
-- `evidence_strength`, which must render as "Not recorded" with NO stars (zero
-- stars would assert a score that was never taken) and, per the service's
-- `(evidence_strength IS NULL) ASC, evidence_strength DESC, source_key ASC`
-- ordering, must sort AFTER the scored source.
-- assertion 9608 (VariO:0508) is given a visibly stronger score (3) so
-- queue ordering and star rendering differ from 9617's single star.
INSERT INTO `variation_ontology_evidence` (
  `evidence_id`,
  `assertion_id`,
  `source_type`,
  `source_key`,
  `batch_id`,
  `source_version`,
  `evidence_summary`,
  `evidence_strength`,
  `evidence_json`
) VALUES
  (
    9615,
    9615,
    'external_database',
    'clinvar',
    'pw-fixture-2026-02',
    '2026-01',
    '3 ClinVar records, max 2 stars',
    2,
    '{"records":[{"variation_id":"VCV0000132","classification":"Pathogenic","review_stars":2,"consequence":"nonsense variant"},{"variation_id":"VCV0000418","classification":"Pathogenic","review_stars":2,"consequence":"frameshift variant"},{"variation_id":"VCV0000955","classification":"Likely pathogenic","review_stars":1,"consequence":"frameshift variant"}],"matched":["OMIM:615032"]}'
  ),
  (
    9616,
    9615,
    'literature',
    'pubtator',
    'pw-fixture-2026-02',
    NULL,
    'Co-mentioned in 4 publications; strength not scored',
    NULL,
    '{"matched":["OMIM:615032"]}'
  ),
  (
    9617,
    9617,
    'external_database',
    'clinvar',
    'pw-fixture-2026-02',
    '2026-01',
    '2 ClinVar records, max 1 star',
    1,
    '{"records":[{"variation_id":"VCV1343191","classification":"Likely pathogenic","review_stars":1,"consequence":"missense variant"},{"variation_id":"VCV1804020","classification":"Likely pathogenic","review_stars":1,"consequence":"missense variant"}],"matched":["OMIM:615032"]}'
  ),
  (
    9618,
    9618,
    'external_database',
    'clinvar',
    'pw-fixture-2026-02',
    '2026-01',
    '1 ClinVar record, max 1 star',
    1,
    '{"records":[{"variation_id":"VCV1902773","classification":"Uncertain significance","review_stars":1,"consequence":"missense variant"}],"matched":["OMIM:615032"]}'
  ),
  (
    9608,
    9608,
    'external_database',
    'clinvar',
    'pw-fixture-2026-02',
    '2026-01',
    '5 ClinVar records, max 3 stars',
    3,
    '{"records":[{"variation_id":"VCV0002210","classification":"Pathogenic","review_stars":3,"consequence":"splice donor variant"},{"variation_id":"VCV0002211","classification":"Pathogenic","review_stars":3,"consequence":"splice acceptor variant"},{"variation_id":"VCV0002212","classification":"Likely pathogenic","review_stars":2,"consequence":"splice donor variant"},{"variation_id":"VCV0002213","classification":"Likely pathogenic","review_stars":1,"consequence":"splice region variant"},{"variation_id":"VCV0002214","classification":"Uncertain significance","review_stars":1,"consequence":"splice region variant"}],"matched":["OMIM:615032"]}'
  )
ON DUPLICATE KEY UPDATE
  `assertion_id` = VALUES(`assertion_id`),
  `source_type` = VALUES(`source_type`),
  `source_key` = VALUES(`source_key`),
  `batch_id` = VALUES(`batch_id`),
  `source_version` = VALUES(`source_version`),
  `evidence_summary` = VALUES(`evidence_summary`),
  `evidence_strength` = VALUES(`evidence_strength`),
  `evidence_json` = VALUES(`evidence_json`);

INSERT INTO `ndd_review_publication_join` (
  `review_publication_id`,
  `review_id`,
  `entity_id`,
  `publication_id`,
  `publication_type`,
  `is_reviewed`
) VALUES (
  123,
  123,
  123,
  'PMID:12345678',
  'additional_references',
  1
)
ON DUPLICATE KEY UPDATE
  `review_id` = VALUES(`review_id`),
  `entity_id` = VALUES(`entity_id`),
  `publication_id` = VALUES(`publication_id`),
  `publication_type` = VALUES(`publication_type`),
  `is_reviewed` = VALUES(`is_reviewed`);

-- Transitional cleanup (#635): drop the pre-#635 unprefixed `12345678` publication row
-- if a database was seeded with the old fixture. Safe to run unconditionally -- the
-- join row above has just been repointed at `PMID:12345678`, so nothing references it,
-- and DELETE of an absent row is a no-op.
DELETE FROM `publication` WHERE `publication_id` = '12345678';

-- Batch 9001 is assigned to BOTH pw_reviewer and pw_curator.
--
-- pw_reviewer is the original assignee. pw_curator was added for the #608
-- variation-provenance curation specs: `GET /api/re_review/table` scopes the
-- default queue to `re_review_assignment.user_id = <requesting user>`, so only an
-- ASSIGNED user can open a row's Edit-review modal — which is the only surface
-- that renders the three-zone provenance picker (ReviewFormFields.vue is consumed
-- solely by Review.vue's ReviewEditModal). The curator-mode surface
-- (`curate=true`) is not an alternative: it additionally requires
-- `re_review_submitted = 1`, and the connect row below is 0.
-- The Suggested zone needs `GET /api/entity/<id>/variation/suggestions`, which is
-- gated at Curator — so a Reviewer-only assignment can never render all three
-- zones. Adding the curator does not change what pw_reviewer sees (the queue is
-- scoped per user, so there is no row fan-out).
DELETE FROM `re_review_assignment` WHERE `re_review_batch` = 9001;

INSERT INTO `re_review_assignment` (`user_id`, `re_review_batch`)
SELECT `user_id`, 9001
FROM `user`
WHERE `user_name` IN ('pw_reviewer', 'pw_curator');

INSERT INTO `re_review_entity_connect` (
  `re_review_entity_id`,
  `entity_id`,
  `re_review_batch`,
  `re_review_review_saved`,
  `re_review_status_saved`,
  `re_review_submitted`,
  `re_review_approved`,
  `status_id`,
  `review_id`
) VALUES (
  9001,
  123,
  9001,
  0,
  0,
  0,
  0,
  123,
  123
)
ON DUPLICATE KEY UPDATE
  `entity_id` = VALUES(`entity_id`),
  `re_review_batch` = VALUES(`re_review_batch`),
  `re_review_review_saved` = VALUES(`re_review_review_saved`),
  `re_review_status_saved` = VALUES(`re_review_status_saved`),
  `re_review_submitted` = VALUES(`re_review_submitted`),
  `re_review_approved` = VALUES(`re_review_approved`),
  `status_id` = VALUES(`status_id`),
  `review_id` = VALUES(`review_id`);

CREATE OR REPLACE VIEW `ndd_entity_status_approved_view` AS
SELECT
  `status_id`,
  `entity_id`,
  `category_id`,
  `is_active`,
  `status_date`,
  `status_user_id`,
  `status_approved`,
  `approving_user_id`,
  `comment`,
  `problematic`
FROM `ndd_entity_status`
WHERE `status_approved` = 1
  AND `is_active` = 1;

CREATE OR REPLACE VIEW `ndd_entity_view` AS
SELECT
  e.`entity_id`,
  e.`hgnc_id`,
  g.`symbol`,
  d.`disease_ontology_id_version`,
  d.`disease_ontology_name`,
  m.`hpo_mode_of_inheritance_term`,
  m.`hpo_mode_of_inheritance_term_name`,
  m.`inheritance_filter`,
  e.`ndd_phenotype`,
  b.`word_english` AS `ndd_phenotype_word`,
  e.`entry_date`,
  c.`category`,
  c.`category_id`
FROM `ndd_entity` e
JOIN `non_alt_loci_set` g
  ON e.`hgnc_id` = g.`hgnc_id`
JOIN `disease_ontology_set` d
  ON e.`disease_ontology_id_version` = d.`disease_ontology_id_version`
JOIN `mode_of_inheritance_list` m
  ON e.`hpo_mode_of_inheritance_term` = m.`hpo_mode_of_inheritance_term`
JOIN `ndd_entity_status_approved_view` s
  ON e.`entity_id` = s.`entity_id`
JOIN `ndd_entity_status_categories_list` c
  ON s.`category_id` = c.`category_id`
JOIN `boolean_list` b
  ON e.`ndd_phenotype` = b.`logical`
WHERE e.`is_active` = 1;

CREATE OR REPLACE VIEW `ndd_database_comparison_view` AS
SELECT
  e.`hgnc_id`,
  e.`disease_ontology_id_version` AS `disease_ontology_id`,
  e.`hpo_mode_of_inheritance_term` AS `inheritance`,
  c.`category`,
  '1' AS `pathogenicity_mode`,
  'SysNDD' AS `list`,
  'current' AS `version`
FROM `ndd_entity` e
JOIN `ndd_entity_status_approved_view` s
  ON e.`entity_id` = s.`entity_id`
JOIN `ndd_entity_status_categories_list` c
  ON s.`category_id` = c.`category_id`
WHERE e.`is_active` = 1
  AND e.`ndd_phenotype` = 1
UNION ALL
SELECT
  `hgnc_id`,
  `disease_ontology_id`,
  `inheritance`,
  `category`,
  `pathogenicity_mode`,
  `list`,
  `version`
FROM `ndd_database_comparison`;

CREATE OR REPLACE VIEW `ndd_review_phenotype_connect_view` AS
SELECT
  pc.`entity_id`,
  pc.`review_id`,
  pc.`phenotype_id`,
  pc.`modifier_id`,
  p.`HPO_term`,
  ml.`modifier_name`,
  CONCAT(ml.`modifier_name`, ': ', p.`HPO_term`) AS `modifier_phenotype_name`,
  CONCAT(pc.`modifier_id`, '-', pc.`phenotype_id`) AS `modifier_phenotype_id`,
  pc.`phenotype_date`
FROM `ndd_review_phenotype_connect` pc
JOIN `modifier_list` ml
  ON pc.`modifier_id` = ml.`modifier_id`
JOIN `phenotype_list` p
  ON pc.`phenotype_id` = p.`phenotype_id`
JOIN `ndd_entity_review` r
  ON pc.`review_id` = r.`review_id`
WHERE pc.`is_active` = 1
  AND r.`is_primary` = 1;

CREATE OR REPLACE VIEW `ndd_review_variant_connect_view` AS
SELECT
  vc.`entity_id`,
  vc.`review_id`,
  vc.`vario_id`,
  vc.`modifier_id`,
  v.`vario_name`,
  CONCAT(v.`vario_name`, ': ', v.`definition`) AS `vario_label`,
  CONCAT(vc.`modifier_id`, '-', vc.`vario_id`) AS `modifier_variant_id`,
  vc.`variation_ontology_date`
FROM `ndd_review_variation_ontology_connect` vc
JOIN `variation_ontology_list` v
  ON vc.`vario_id` = v.`vario_id`
JOIN `ndd_entity_review` r
  ON vc.`review_id` = r.`review_id`
WHERE vc.`is_active` = 1
  AND r.`is_primary` = 1;
