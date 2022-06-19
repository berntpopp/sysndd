<template>
  <div class="container-fluid">
    <!-- Load Genes table component element -->
    <TablesGenes
      :sort_input="sort"
      :filter_input="filter"
      :fields_input="fields"
      :page_after_input="page_after"
      :page_size_input="page_size"
      :fspec_input="fspec"
    />
    <!-- Load Genes table component element -->
  </div>
</template>


<script>
import TablesGenes from "@/components/tables/TablesGenes.vue";

export default {
  name: "Genes",
  components: { TablesGenes },
  props: {
    sort: { type: String, default: "symbol" },
    filter: { type: String, default: null },
    fields: { type: String, default: null },
    page_after: { type: String, default: "0" },
    page_size: { type: String, default: "10" },
    fspec: {
      type: String,
      default:
        "symbol,category,hpo_mode_of_inheritance_term_name,ndd_phenotype_word,entities_count,details",
    },
  },
  metaInfo: {
    // if no subcomponents specify a metaInfo.title, this title will be used
    title: "Genes",
    // all titles will be injected into this template
    titleTemplate:
      "%s | SysNDD - The expert curated database of gene disease relationships in neurodevelopmental disorders",
    htmlAttrs: {
      lang: "en",
    },
    meta: [
      {
        vmid: "description",
        name: "description",
        content:
          "The Genes table view allows browsing NDD associations by gene.",
      },
    ],
  },
  mounted() {},
};
</script>


<style scoped>
</style>