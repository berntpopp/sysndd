// tableDataMixin.js
/**
 * Mixin for shared data properties in table components.
 */
export default {
  data() {
    return {
      items: [],
      totalRows: 0,
      currentPage: 1,
      currentItemID: this.pageAfterInput,
      prevItemID: null,
      nextItemID: null,
      lastItemID: null,
      executionTime: 0,
      perPage: this.pageSizeInput,
      pageOptions: ['10', '25', '50', '100'],
      sortBy: '',
      sortDesc: true,
      sort: this.sortInput,
      filter: {
        any: { content: null, join_char: null, operator: 'contains' },
        entity_id: { content: null, join_char: null, operator: 'contains' },
        symbol: { content: null, join_char: null, operator: 'contains' },
        disease_ontology_name: { content: null, join_char: null, operator: 'contains' },
        disease_ontology_id_version: { content: null, join_char: null, operator: 'contains' },
        hpo_mode_of_inheritance_term_name: { content: null, join_char: ',', operator: 'any' },
        hpo_mode_of_inheritance_term: { content: null, join_char: ',', operator: 'any' },
        ndd_phenotype_word: { content: null, join_char: null, operator: 'contains' },
        category: { content: null, join_char: ',', operator: 'any' },
        entities_count: { content: null, join_char: ',', operator: 'any' },
      },
      filter_string: '',
      filterOn: [],
      downloading: false,
      loading: true,
      isBusy: false,
      // Add any other shared data properties here
    };
  },
  computed: {
    removeFiltersButtonVariant() {
      return (this.filter_string === '' || this.filter_string === null || this.filter_string === 'null') ? 'info' : 'warning';
    },
    removeFiltersButtonTitle() {
      let title = 'The table is ';
      title += (this.filter_string === '' || this.filter_string === null || this.filter_string === 'null') ? 'not ' : '';
      title += 'filtered.';
      if (this.filter_string !== '' && this.filter_string !== null && this.filter_string !== 'null') {
        title += ' Click to remove all filters.';
      }
      return title;
    },
  },
};
