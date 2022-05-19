<template>
  <div class="container-fluid bg-gradient">
    <b-container fluid>

      <b-row class="justify-content-md-center py-2">
        <b-col col md="12">

          <div>
          <b-tabs content-class="mt-3" v-model="tabIndex">

            <b-tab title="Phenotype correlogram" active>
              <AnalysesPhenotypeCorrelogram />
            </b-tab>

            <b-tab title="Phenotype counts">
              <AnalysesPhenotypeCounts />
            </b-tab>

            <b-tab title="MCA phenotypes & inheritance">

            </b-tab>

          </b-tabs>
          </div>
          
        </b-col>
      </b-row>

    </b-container>
  </div>
</template>


<script>
  import AnalysesPhenotypeCorrelogram from '@/components/analyses/AnalysesPhenotypeCorrelogram.vue';
  import AnalysesPhenotypeCounts from '@/components/analyses/AnalysesPhenotypeCounts.vue';

  import toastMixin from '@/assets/js/mixins/toastMixin.js'

  import * as d3 from 'd3';

  export default {
  components: {AnalysesPhenotypeCorrelogram,
    AnalysesPhenotypeCounts
    },
  name: 'PhenotypeCorrelations',
  mixins: [toastMixin],
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
.bg-gradient {
  margin:0px;
  height:100%;
  min-height:calc(100vh - 100px);
  background-image: linear-gradient(-225deg, #E3FDF5 0%, #FFE6FA 100%);
}
</style>