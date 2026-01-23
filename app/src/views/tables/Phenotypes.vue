<template>
  <div class="container-fluid">
    <!-- Load Phenotypes table component element -->
    <TablesPhenotypes
      :sort-input="sort"
      :filter-input="filter"
      :fields-input="fields"
      :page-after-input="pageAfter"
      :page-size-input="Number(pageSize)"
      :fspec-input="fspec"
    />
    <!-- Load Phenotypes table component element -->
  </div>
</template>

<script>
import { useHead } from '@unhead/vue';
import TablesPhenotypes from '@/components/tables/TablesPhenotypes.vue';

export default {
  name: 'Phenotypes',
  components: {
    TablesPhenotypes,
  },
  props: {
    sort: { type: String, default: 'entity_id' },
    filter: { type: String, default: 'all(modifier_phenotype_id,HP:0001249)' },
    fields: { type: String, default: null },
    pageAfter: { type: String, default: '0' },
    pageSize: { type: String, default: '10' },
    fspec: {
      type: String,
      default:
        'entity_id,symbol,disease_ontology_name,hpo_mode_of_inheritance_term_name,category,ndd_phenotype_word',
    },
  },
  setup() {
    useHead({
      title: 'Phenotypes',
      meta: [
        {
          name: 'description',
          content:
            'The Phenotypes table view allows browsing NDD associated entities by phenotype and filtering with download possibility.',
        },
      ],
    });
  },
};
</script>

<style scoped>
</style>
