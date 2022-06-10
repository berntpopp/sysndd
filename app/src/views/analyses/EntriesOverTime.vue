<template>
  <div class="container-fluid bg-gradient">
    <b-container fluid>

      <b-row class="justify-content-md-center py-2">
        <b-col col md="12">
          <div>
            <b-tab title="Entities over time" active>
              <AnalysesTimePlot />
            </b-tab>
          </div>
          
        </b-col>
      </b-row>

    </b-container>
  </div>
</template>


<script>
  import AnalysesTimePlot from '@/components/analyses/AnalysesTimePlot.vue';

  import toastMixin from '@/assets/js/mixins/toastMixin.js'

  export default {
  components: {AnalysesTimePlot,
    },
  name: 'EntriesOverTime',
  mixins: [toastMixin],
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
  },
  data() {
    return {
      tabIndex: 0,
      };
    },
    mounted() {
    },
    methods: {
    }
  };
</script>


<style scoped>

</style>
