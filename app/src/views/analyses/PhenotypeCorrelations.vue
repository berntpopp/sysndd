<template>
  <div class="container-fluid bg-gradient">
    <b-container fluid>
      <b-row class="justify-content-md-center py-2">
        <b-col
          col
          md="12"
        >
          <div>
            <b-tabs
              v-model="tabIndex"
              content-class="mt-3"
            >
              <b-tab
                title="Phenotype correlogram"
                active
              >
                <AnalysesPhenotypeCorrelogram />
              </b-tab>

              <b-tab
                title="Phenotype counts"
                lazy
              >
                <AnalysesPhenotypeCounts />
              </b-tab>

              <b-tab
                title="Phenotype clustering"
                lazy
              >
                <AnalysesPhenotypeClusters />
              </b-tab>
            </b-tabs>
          </div>
        </b-col>
      </b-row>
    </b-container>
  </div>
</template>

<script>
import toastMixin from '@/assets/js/mixins/toastMixin';

import * as d3 from 'd3';

export default {
  name: 'PhenotypeCorrelations',
  mixins: [toastMixin],
  metaInfo: {
    // if no subcomponents specify a metaInfo.title, this title will be used
    title: 'Phenotype correlations',
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
        content:
          'The Phenotype analysis can be used to compare the correlations between phenotypes and with their associated inheritance patterns in neurodevelopmental disorders (including attention-deficit/hyperactivity disorder (ADHD), autism spectrum disorders (ASD), learning disabilities and intellectual disability).',
      },
    ],
  },
  data() {
    return {
      tabIndex: 0,
    };
  },
  mounted() {},
  methods: {},
};
</script>

<style scoped>
</style>
