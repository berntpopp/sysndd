<!-- views/tables/Entities.vue -->
<template>
  <div class="container-fluid">
    <!-- Load Entities table component element -->
    <TablesEntities
      :sort-input="sort"
      :filter-input="filter"
      :fields-input="fields"
      :page-after-input="pageAfter"
      :page-size-input="pageSize"
      :fspec-input="fspec"
    />
    <!-- Load Entities table component element -->
  </div>
</template>

<script>
import { useHead } from '@unhead/vue';

export default {
  name: 'Entities',
  props: {
    sort: { type: String, default: '+entity_id' },
    filter: { type: String, default: null },
    fields: { type: String, default: null },
    pageAfter: { type: String, default: '0' },
    pageSize: { type: Number, default: 10 },
    fspec: {
      type: String,
      default:
        'entity_id,symbol,disease_ontology_name,hpo_mode_of_inheritance_term_name,category,ndd_phenotype_word,details',
    },
  },
  setup() {
    useHead({
      title: 'Entities',
      meta: [
        {
          name: 'description',
          content: 'An expert curated resource of neurodevelopmental disorders.',
        },
      ],
    });
  },
};
</script>

<style scoped>
</style>
