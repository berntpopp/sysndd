<template>
  <div class="container-fluid">
    <b-container fluid>

      Content comming

    </b-container>
  </div>
</template>


<script>
  export default {
  name: 'EntriesOverTime',
  metaInfo: {
    // if no subcomponents specify a metaInfo.title, this title will be used
    title: 'Entries over time',
    // all titles will be injected into this template
    titleTemplate: '%s | SysNDD - The expert curated database of gene disease relationships in neurodevelopmental disorders',
    htmlAttrs: {
      lang: 'en'
    },
    meta: [
      { vmid: 'description', name: 'description', content: 'This analysis shows the development of database entries over time for neurodevelopmental disorders curated in SysNDD.' }
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
