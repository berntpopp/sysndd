-- 057_about_citation_preprint.sql
--
-- Publish the SysNDD preprint as the primary citation in the About page's
-- "Citation Policy" section.
--
-- WHY A MIGRATION
-- ---------------
-- The public About page renders the latest `published` row of `about_content`
-- (seeded by 001), not the hardcoded fallback in the frontend. That row still
-- says a manuscript is in preparation. The SysNDD preprint is now posted
-- (doi: 10.64898/2026.09.29.755401), so the citation policy must name it.
--
-- WHAT IT DOES
-- ------------
-- Appends a NEW published version: a copy of the latest published sections
-- with only the `citation` section's content replaced. Nothing is updated or
-- deleted, so the previous version stays in the CMS history and every other
-- section keeps whatever an administrator last published.
--
-- Guarded, so it is a no-op when
--   * there is no published row or no `citation` section, or
--   * the published citation section already names the preprint DOI
--     (an administrator updated it by hand, or this migration already ran).
--
-- Keep the citation text in step with app/src/constants/publication.ts.

INSERT INTO `about_content` (`user_id`, `sections_json`, `status`, `version`, `published_at`)
SELECT
  latest.`user_id`,
  JSON_SET(
    latest.`sections_json`,
    REPLACE(JSON_UNQUOTE(latest.`section_id_path`), '.section_id', '.content'),
    '**Primary Citation:**\n\nPopp B, Frueh S, Altay MF, Van Esch H, Caliebe A, Bramswig NC, Hummel F, Gverdtsiteli S, Kleefstra T, Schenck A, Tuemer Z, Verloes A, Zweier C. SysNDD: A Systematic Database for Neurodevelopmental Disorders. bioRxiv [Preprint]. 2026 Oct 1:2026.09.29.755401. doi: 10.64898/2026.09.29.755401\n\nURL: https://www.biorxiv.org/content/10.64898/2026.09.29.755401\n\nPlease cite this preprint when you use SysNDD.\n\n**Original SysID publication:**\n\nKochinke K, Zweier C, Nijhof B, Fenckova M, Cizek P, Honti F, Keerthikumar S, Oortveld MA, Kleefstra T, Kramer JM, Webber C, Huynen MA, Schenck A. Systematic Phenomics Analysis Deconvolutes Genes Mutated in Intellectual Disability into Biologically Coherent Modules. Am J Hum Genet. 2016 Jan 7;98(1):149-64. doi: 10.1016/j.ajhg.2015.11.024. PMID: 26748517; PMCID: PMC4716705.\n\nURL: https://pubmed.ncbi.nlm.nih.gov/26748517/\n\nCite it in addition when you refer to the predecessor database SysID.'
  ),
  'published',
  latest.`version` + 1,
  NOW()
FROM (
  SELECT
    `user_id`,
    `sections_json`,
    `version`,
    JSON_SEARCH(`sections_json`, 'one', 'citation', NULL, '$[*].section_id') AS `section_id_path`
  FROM `about_content`
  WHERE `status` = 'published'
  ORDER BY `version` DESC
  LIMIT 1
) AS latest
WHERE latest.`section_id_path` IS NOT NULL
  AND JSON_UNQUOTE(
        JSON_EXTRACT(
          latest.`sections_json`,
          REPLACE(JSON_UNQUOTE(latest.`section_id_path`), '.section_id', '.content')
        )
      ) NOT LIKE '%10.64898/2026.09.29.755401%';
