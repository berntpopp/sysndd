<template>
  <div class="container-fluid">
    <b-container fluid>

      <b-row class="justify-content-md-center py-2">
        <b-col col md="12">
          <div>
            <b-tab title="Functional clusters" active>
              <AnalyseGeneClusters />
            </b-tab>
          </div>
          
        </b-col>
      </b-row>

    </b-container>
  </div>
</template>


<script>
  import AnalyseGeneClusters from '@/components/analyses/AnalyseGeneClusters.vue';

  import toastMixin from '@/assets/js/mixins/toastMixin.js'

  export default {
  components: {AnalyseGeneClusters,
    },
  name: 'GeneNetworks',
  mixins: [toastMixin],
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
