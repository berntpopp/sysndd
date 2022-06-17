<template>
  <div class="container-fluid">

    <TablesEntities
    >
    </TablesEntities>

  </div>
</template>


<script>
import TablesEntities from '@/components/tables/TablesEntities.vue';

export default {
  components: {TablesEntities,
    },
  name: 'Entities',
  metaInfo: {
    // if no subcomponents specify a metaInfo.title, this title will be used
    title: 'Entities',
    // all titles will be injected into this template
    titleTemplate: '%s | SysNDD - The expert curated database of gene disease relationships in neurodevelopmental disorders',
    htmlAttrs: {
      lang: 'en'
    },
    meta: [
      { vmid: 'description', name: 'description', content: 'An expert curated resource of neurodevelopmental disorders.' }
    ]
  },
  }
</script>


<style scoped>

</style>