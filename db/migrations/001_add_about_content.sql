-- Create about_content table for CMS draft/publish workflow
-- This table stores About page content with version history
--
-- Features:
-- - Per-user draft storage (one draft per user)
-- - Published content versioning
-- - JSON storage for flexible section structure
-- - Indexed for efficient querying

CREATE TABLE IF NOT EXISTS `about_content` (
  `id` INT AUTO_INCREMENT PRIMARY KEY,
  `user_id` INT NOT NULL,
  `sections_json` JSON NOT NULL,
  `status` ENUM('draft', 'published') NOT NULL DEFAULT 'draft',
  `version` INT DEFAULT NULL,
  `published_at` TIMESTAMP NULL,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  INDEX idx_user_status (user_id, status),
  INDEX idx_status_version (status, version DESC),
  FOREIGN KEY (user_id) REFERENCES user(user_id) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Seed initial published content from current About.vue
-- This provides the baseline content for the CMS
INSERT INTO `about_content` (
  `user_id`,
  `sections_json`,
  `status`,
  `version`,
  `published_at`
) VALUES (
  1, -- admin user
  JSON_ARRAY(
    JSON_OBJECT(
      'section_id', 'creators',
      'title', 'About SysNDD and its creators',
      'icon', 'bi-people',
      'content', 'The SysNDD database is based on some content of its predecessor database, SysID (http://sysid.cmbi.umcn.nl/, more recently https://www.sysid.dbmr.unibe.ch/). The concept for a curated gene collection and database with the goal to facilitate research and diagnostics into NDDs has been conceived by Annette Schenck and Christiane Zweier.\n\nIn 2009, they established SysID with a manually curated catalog of published genes implicated in neurodevelopmental disorders (NDDs), classified into primary and candidate genes according to the degree of underlying evidence. Furthermore, expert curated information on associated diseases and phenotypes was provided.\n\nChristiane Zweier has been updating SysID from its start in 2009. Together with her, Bernt Popp has now developed and programmed the new SysNDD database.\n\nTo allow interoperability and mapping between gene-, phenotype- or disease-oriented databases, SysNDD is centered around curated gene-inheritance-disease units, so called entities, which are classified based on three evidence categories. This can account for the increased complexity of NDDs and allows to address a broader spectrum of diagnostic and research questions.\n\nFuture functionality will be expanded to annotation of variant and network analyses. Another goal is to incorporate the SysID/SysNDD data into other gene/disease-relationship databases like the Orphanet Rare Disease ontology database.\n\n## Affiliations\n\n- **Christiane Zweier:** previously: Institute of Human Genetics, University Hospital, FAU Erlangen, Germany; now: Human Genetics at the University/University Hospital Bern, Switzerland\n- **Bernt Popp:** senior physician at the Berlin Institute of Health (BIH) at Charite Berlin, Germany and scientist at the Institute of Human Genetics at the University Hospital Leipzig, Germany\n- **Annette Schenck:** Radboud university medical center, Nijmegen, the Netherlands',
      'sort_order', 0
    ),
    JSON_OBJECT(
      'section_id', 'citation',
      'title', 'Citation Policy',
      'icon', 'bi-journal-text',
      'content', '**Primary Citation:**\n\nKochinke K, Zweier C, Nijhof B, Fenckova M, Cizek P, Honti F, Keerthikumar S, Oortveld MA, Kleefstra T, Kramer JM, Webber C, Huynen MA, Schenck A. Systematic Phenomics Analysis Deconvolutes Genes Mutated in Intellectual Disability into Biologically Coherent Modules. Am J Hum Genet. 2016 Jan 7;98(1):149-64. doi: 10.1016/j.ajhg.2015.11.024. PMID: 26748517; PMCID: PMC4716705.\n\nURL: https://pubmed.ncbi.nlm.nih.gov/26748517/\n\nPlease cite above publication. We are currently working on a new manuscript reporting SysNDD and the development of the NDD landscape over the past years. A link will be provided here upon publication.',
      'sort_order', 1
    ),
    JSON_OBJECT(
      'section_id', 'funding',
      'title', 'Support and Funding',
      'icon', 'bi-cash-stack',
      'content', '## Current SysNDD database development is supported by:\n\n- DFG (Deutsche Forschungsgemeinschaft) grant PO2366/2-1 to Bernt Popp (https://orcid.org/0000-0002-3679-1081)\n- DFG (Deutsche Forschungsgemeinschaft) grant ZW184/6-1 to Christiane Zweier (https://orcid.org/0000-0001-8002-2020)\n- ITHACA ERN through Alain Verloes (https://orcid.org/0000-0003-4819-0264)\n\n## Previous SysID database and data curation was supported by:\n\n- The European Union\'s FP7 large scale integrated network GenCoDys (HEALTH-241995) - Martijn A Huynen (https://orcid.org/0000-0001-6189-5491) and Annette Schenck (https://orcid.org/0000-0002-6918-3314)\n- VIDI and TOP grants (917-96-346, 912-12-109) from The Netherlands Organisation for Scientific Research (NWO) to Annette Schenck (https://orcid.org/0000-0002-6918-3314)\n- DFG (Deutsche Forschungsgemeinschaft) grants ZW184/1-1 and -2 to Christiane Zweier (https://orcid.org/0000-0001-8002-2020)\n- the IZKF (Interdisziplinares Zentrum fur Klinische Forschung) Erlangen to Christiane Zweier (https://orcid.org/0000-0001-8002-2020)\n- ZonMw grant (NWO, 907-00-365) to Tjitske Kleefstra (https://orcid.org/0000-0002-0956-0237)',
      'sort_order', 2
    ),
    JSON_OBJECT(
      'section_id', 'news',
      'title', 'News and Updates',
      'icon', 'bi-megaphone',
      'content', '**2022-05-07:** First SysNDD native data update. Deprecating SysID. SysNDD now in usable beta mode.\n\n**2021-11-09:** Several updates to the APP, API and DB preparing it for re-review mode.\n\n**2021-08-16:** SysNDD is currently in alpha development status and changes. We currently recommend using the stable SysID database (https://www.sysid.dbmr.unibe.ch/) for your work until a more stable beta status is reached.',
      'sort_order', 3
    ),
    JSON_OBJECT(
      'section_id', 'credits',
      'title', 'Credits and acknowledgement',
      'icon', 'bi-award',
      'content', 'We acknowledge Martijn Huynen and members of the Huynen and Schenck groups at the Radboud University Medical Center Nijmegen, The Netherlands, for building SysID and supporting it for many years.\n\nWe would also like to thank all past users for using SysID and for constructive feedback, thus making the sometimes tedious updates and re-organization into the new SysNDD database worthwhile.\n\nSince recently, Alain Verloes and ERN ITHACA provide valuable encouragement and support by initiating and supporting the data integration with Orphanet and helping with the recruitment of expert curators.',
      'sort_order', 4
    ),
    JSON_OBJECT(
      'section_id', 'disclaimer',
      'title', 'Disclaimer',
      'icon', 'bi-shield-exclamation',
      'content', '**IMPORTANT:** The Department of Human Genetics (University Hospital, University Bern, Bern, Switzerland) makes no representation about the suitability or accuracy of this software or data for any purpose, and makes no warranties, including fitness for a particular purpose or that the use of this software will not infringe any third party patents, copyrights, trademarks or other rights.\n\n**Responsible for this website:**\nBernt Popp (admin [at] sysndd.org)\n\n**Responsible for this project:**\nChristiane Zweier (curator [at] sysndd.org)\n\n**Address:**\nUniversitatsklinik fur Humangenetik, Inselspital, Universitatsspital Bern, Freiburgstrasse 15, 3010 Bern, Switzerland',
      'sort_order', 5
    ),
    JSON_OBJECT(
      'section_id', 'contact',
      'title', 'Contact',
      'icon', 'bi-envelope',
      'content', 'If you have technical problems using SysNDD or requests regarding the data or functionality, please contact us at:\n\n**support [at] sysndd.org**',
      'sort_order', 6
    )
  ),
  'published',
  1,
  NOW()
);
