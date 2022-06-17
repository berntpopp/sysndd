<template>
  <div class="container-fluid">

  <!-- Load Genes table component element -->
    <TablesGenes
    >
    </TablesGenes>
  <!-- Load Genes table component element -->

  </div>
</template>


<script>
import TablesGenes from '@/components/tables/TablesGenes.vue';

export default {
  components: {TablesGenes,
    },
  name: 'Genes',
  metaInfo: {
    // if no subcomponents specify a metaInfo.title, this title will be used
    title: 'Genes',
    // all titles will be injected into this template
    titleTemplate: '%s | SysNDD - The expert curated database of gene disease relationships in neurodevelopmental disorders',
    htmlAttrs: {
      lang: 'en'
    },
    meta: [
      { vmid: 'description', name: 'description', content: 'The Genes table view allows browsing NDD associations by gene.' }
    ]
  },
  }
</script>


<style scoped>

</style>