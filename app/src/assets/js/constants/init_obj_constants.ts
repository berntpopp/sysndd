// init_obj_constants.ts

/**
 * Constants for initializing various objects used in the application.
 * Provides type-safe initial state for statistics and news displays.
 */

import type { StatisticsMeta, CategoryStat, NewsItem } from '@/types';

/**
 * Statistics initialization structure
 */
interface StatisticsInit {
  meta: StatisticsMeta[];
  data: CategoryStat[];
}

/**
 * Initial objects for application state
 */
const INIT_OBJECTS = {
  /**
   * Initial structure for entity statistics.
   * Used to pre-populate UI before API data loads.
   */
  ENTITY_STAT_INIT: {
    meta: [
      {
        last_update: '2010-12-01 00:00:00',
        executionTime: null,
      },
    ],
    data: [
      {
        category: 'Definitive',
        n: 398,
        inheritance: 'All',
        groups: [
          {
            category: 'Definitive',
            category_id: 1,
            inheritance: 'Autosomal recessive',
            n: 0,
          },
          {
            category: 'Definitive',
            category_id: 1,
            inheritance: 'Autosomal dominant',
            n: 0,
          },
          {
            category: 'Definitive',
            category_id: 1,
            inheritance: 'X-linked',
            n: 0,
          },
          {
            category: 'Definitive',
            category_id: 1,
            inheritance: 'Other',
            n: 0,
          },
        ],
      },
      {
        category: 'Moderate',
        n: 16,
        inheritance: 'All',
        groups: [
          {
            category: 'Moderate',
            category_id: 2,
            inheritance: 'Autosomal dominant',
            n: 0,
          },
          {
            category: 'Moderate',
            category_id: 2,
            inheritance: 'Autosomal recessive',
            n: 0,
          },
          {
            category: 'Moderate',
            category_id: 2,
            inheritance: 'X-linked',
            n: 0,
          },
        ],
      },
      {
        category: 'Limited',
        n: 33,
        inheritance: 'All',
        groups: [
          {
            category: 'Limited',
            category_id: 3,
            inheritance: 'Autosomal recessive',
            n: 0,
          },
          {
            category: 'Limited',
            category_id: 3,
            inheritance: 'Autosomal dominant',
            n: 0,
          },
          {
            category: 'Limited',
            category_id: 3,
            inheritance: 'X-linked',
            n: 0,
          },
          {
            category: 'Limited',
            category_id: 3,
            inheritance: 'Other',
            n: 0,
          },
        ],
      },
    ],
  } satisfies StatisticsInit,

  /**
   * Initial structure for gene statistics.
   * Similar structure as entity statistics.
   */
  GENE_STAT_INIT: {
    meta: [
      {
        last_update: '2010-12-01 00:00:00',
        executionTime: null,
      },
    ],
    data: [
      {
        category: 'Definitive',
        n: 344,
        inheritance: 'All',
        groups: [
          {
            category: 'Definitive',
            category_id: 1,
            inheritance: 'Autosomal recessive',
            n: 0,
          },
          {
            category: 'Definitive',
            category_id: 1,
            inheritance: 'Autosomal dominant',
            n: 0,
          },
          {
            category: 'Definitive',
            category_id: 1,
            inheritance: 'X-linked',
            n: 0,
          },
          {
            category: 'Definitive',
            category_id: 1,
            inheritance: 'Other',
            n: 0,
          },
        ],
      },
      {
        category: 'Moderate',
        n: 23,
        inheritance: 'All',
        groups: [
          {
            category: 'Moderate',
            category_id: 2,
            inheritance: 'Autosomal dominant',
            n: 0,
          },
          {
            category: 'Moderate',
            category_id: 2,
            inheritance: 'Autosomal recessive',
            n: 0,
          },
          {
            category: 'Moderate',
            category_id: 2,
            inheritance: 'X-linked',
            n: 0,
          },
        ],
      },
      {
        category: 'Limited',
        n: 35,
        inheritance: 'All',
        groups: [
          {
            category: 'Limited',
            category_id: 3,
            inheritance: 'Autosomal recessive',
            n: 0,
          },
          {
            category: 'Limited',
            category_id: 3,
            inheritance: 'Autosomal dominant',
            n: 0,
          },
          {
            category: 'Limited',
            category_id: 3,
            inheritance: 'X-linked',
            n: 0,
          },
          {
            category: 'Limited',
            category_id: 3,
            inheritance: 'Other',
            n: 0,
          },
        ],
      },
    ],
  } satisfies StatisticsInit,

  /**
   * Initial list of news items (recent entities).
   * Used to pre-populate news feed before API data loads.
   * Note: Using 'as unknown as' to bypass branded type requirements for constants
   */
  NEWS_INIT: [
    {
      entity_id: 771,
      hgnc_id: 'HGNC:2183',
      symbol: 'VPS13B',
      disease_ontology_id_version: 'OMIM:216550',
      disease_ontology_name: 'Cohen syndrome',
      hpo_mode_of_inheritance_term: 'HP:0000007',
      hpo_mode_of_inheritance_term_name: 'Autosomal recessive inheritance',
      inheritance_filter: 'Autosomal recessive',
      ndd_phenotype: 1,
      ndd_phenotype_word: 'Yes',
      entry_date: '2010-11-23 00:00:00',
      category: 'Definitive',
      category_id: 1,
    },
    {
      entity_id: 775,
      hgnc_id: 'HGNC:20509',
      symbol: 'ZC3H14',
      disease_ontology_id_version: 'OMIM:617125',
      disease_ontology_name: 'Intellectual developmental disorder, autosomal recessive 56',
      hpo_mode_of_inheritance_term: 'HP:0000007',
      hpo_mode_of_inheritance_term_name: 'Autosomal recessive inheritance',
      inheritance_filter: 'Autosomal recessive',
      ndd_phenotype: 1,
      ndd_phenotype_word: 'Yes',
      entry_date: '2010-11-23 00:00:00',
      category: 'Definitive',
      category_id: 1,
    },
    {
      entity_id: 776,
      hgnc_id: 'HGNC:18475',
      symbol: 'ZDHHC9',
      disease_ontology_id_version: 'OMIM:300799',
      disease_ontology_name: 'Intellectual developmental disorder, X-linked syndromic, Raymond type',
      hpo_mode_of_inheritance_term: 'HP:0001419',
      hpo_mode_of_inheritance_term_name: 'X-linked recessive inheritance',
      inheritance_filter: 'X-linked',
      ndd_phenotype: 1,
      ndd_phenotype_word: 'Yes',
      entry_date: '2010-11-23 00:00:00',
      category: 'Definitive',
      category_id: 1,
    },
    {
      entity_id: 779,
      hgnc_id: 'HGNC:12873',
      symbol: 'ZIC2',
      disease_ontology_id_version: 'OMIM:609637',
      disease_ontology_name: 'Holoprosencephaly 5',
      hpo_mode_of_inheritance_term: 'HP:0000006',
      hpo_mode_of_inheritance_term_name: 'Autosomal dominant inheritance',
      inheritance_filter: 'Autosomal dominant',
      ndd_phenotype: 1,
      ndd_phenotype_word: 'Yes',
      entry_date: '2010-11-23 00:00:00',
      category: 'Definitive',
      category_id: 1,
    },
    {
      entity_id: 783,
      hgnc_id: 'HGNC:13128',
      symbol: 'ZNF711',
      disease_ontology_id_version: 'OMIM:300803',
      disease_ontology_name: 'Intellectual developmental disorder, X-linked 97',
      hpo_mode_of_inheritance_term: 'HP:0001417',
      hpo_mode_of_inheritance_term_name: 'X-linked other inheritance',
      inheritance_filter: 'X-linked',
      ndd_phenotype: 1,
      ndd_phenotype_word: 'Yes',
      entry_date: '2010-11-23 00:00:00',
      category: 'Definitive',
      category_id: 1,
    },
  ] as unknown as NewsItem[],
} as const;

export default INIT_OBJECTS;

/** Type for accessing initial objects configuration */
export type InitObjectsConfig = typeof INIT_OBJECTS;
