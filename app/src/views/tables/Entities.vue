<template>
  <div class="container-fluid">
    <!-- Load Entities table component element -->
    <TablesEntities
      :sort-input="sort"
      :filter-input="filter"
      :fields-input="fields"
      :page-after-input="page_after"
      :page-size-input="page_size"
      :fspec-input="fspec"
    />
    <!-- Load Entities table component element -->
  </div>
</template>

<script>
export default {
  name: 'Entities',
  props: {
    sort: { type: String, default: '+entity_id' },
    filter: { type: String, default: null },
    fields: { type: String, default: null },
    page_after: { type: String, default: '0' },
    page_size: { type: String, default: '10' },
    fspec: {
      type: String,
      default:
        'entity_id,symbol,disease_ontology_name,hpo_mode_of_inheritance_term_name,category,ndd_phenotype_word,details',
    },
  },
  metaInfo: {
    // if no subcomponents specify a metaInfo.title, this title will be used
    title: 'Entities',
    // all titles will be injected into this template
    titleTemplate:
      '%s | SysNDD - The expert curated database of gene disease relationships in neurodevelopmental disorders',
    htmlAttrs: {
      lang: 'en',
    },
    meta: [
      {
        vmid: 'description',
        name: 'description',
        content: 'An expert curated resource of neurodevelopmental disorders.',
      },
    ],
  },
};
</script>

<style scoped>
</style>
