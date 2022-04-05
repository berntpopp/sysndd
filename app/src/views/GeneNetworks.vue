<template>
  <div class="container-fluid">
    <b-container fluid>

      Content coming

    </b-container>
  </div>
</template>


<script>
  export default {
  name: 'GeneNetworks',
  metaInfo: {
    // if no subcomponents specify a metaInfo.title, this title will be used
    title: 'Gene networks',
    // all titles will be injected into this template
    titleTemplate: '%s | SysNDD - The expert curated database of gene disease relationships in neurodevelopmental disorders',
    htmlAttrs: {
      lang: 'en'
    },
    meta: [
      { vmid: 'description', name: 'description', content: 'The Gene Networks analysis shows the interactions between genes associated with neurodevelopmental disorders and curated in SysNDD.' }
    ]
  }
  }
</script>

<style scoped>
  .btn-group-xs > .btn, .btn-xs {
    padding: .25rem .4rem;
    font-size: .875rem;
    line-height: .5;
    border-radius: .2rem;
  }
</style>
