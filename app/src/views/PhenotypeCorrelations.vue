<template>
  <div class="container-fluid">
    <b-container fluid>

      Content comming

    </b-container>
  </div>
</template>


<script>
  export default {
  name: 'PhenotypeCorrelations',
  metaInfo: {
    // if no subcomponents specify a metaInfo.title, this title will be used
    title: 'Phenotype correlations',
    // all titles will be injected into this template
    titleTemplate: '%s | SysNDD - The expert curated database of gene disease relationships in neurodevelopmental disorders',
    htmlAttrs: {
      lang: 'en'
    },
    meta: [
      { vmid: 'description', name: 'description', content: 'The Phenotype analysis can be used to compare the correltations between phenotypes and with their associated inheritance patterns in neurodevelopmental disorders (inlucing attention-deficit/hyperactivity disorder (ADHD), autism spectrum disorders (ASD), learning disabilities and intellectual disability).' }
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
