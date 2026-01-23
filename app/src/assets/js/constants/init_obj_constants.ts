// init_obj_constants.js

/**
 * @fileoverview Constants for initializing various objects used in the application.
 */

export default {
  /**
   * Initial structure for entity statistics.
   * @type {Object}
   * @property {Array} meta - Meta information for the entity statistics.
   * @property {string} meta[].last_update - The last update time of the statistics.
   * @property {?number} meta[].executionTime - The time taken for the execution, if available.
   * @property {Array} data - The actual statistical data.
   * @property {string} data[].category - The category of the entity.
   * @property {number} data[].n - Number of entities in this category.
   * @property {string} data[].inheritance - Type of inheritance associated with this category.
   * @property {Object[]} data[].groups - Group details within the category.
   * @property {string} data[].groups[].category - Category name for the group.
   * @property {number} data[].groups[].category_id - Identifier for the category.
   * @property {string} data[].groups[].inheritance - Type of inheritance for the group.
   * @property {number} data[].groups[].n - Number of entities in this group.
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
  },

  /**
   * Initial structure for gene statistics.
   * @type {Object}
   * Similar structure and properties as ENTITY_STAT_INIT.
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
  },

  /**
   * Initial list of news items.
   * @type {Object[]}
   * @property {number} entity_id - Identifier for the news entity.
   * @property {string} hgnc_id - HGNC ID associated with the entity.
   * @property {string} symbol - Symbolic representation of the entity.
   * @property {string} disease_ontology_id_version - Disease ontology ID and version.
   * @property {string} disease_ontology_name - Name of the disease ontology.
   * @property {string} hpo_mode_of_inheritance_term - HPO term for mode of inheritance.
   * @property {string} hpo_mode_of_inheritance_term_name - Name of the HPO term for mode of inheritance.
   * @property {string} inheritance_filter - Type of inheritance filter applied.
   * @property {number} ndd_phenotype - NDD phenotype indicator (numeric).
   * @property {string} ndd_phenotype_word - NDD phenotype indicator (word).
   * @property {string} entry_date - Date of entry into the system.
   * @property {string} category - The category of the news item.
   * @property {number} category_id - Identifier for the category of the news item.
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
  ],
};
