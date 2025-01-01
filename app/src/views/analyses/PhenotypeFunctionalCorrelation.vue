<template>
  <div class="container-fluid bg-gradient">
    <b-container fluid>
      <b-row class="justify-content-md-center py-2">
        <b-col md="12">
          <b-tab
            title="Pheno-Func Correlation"
            active
          >
            <!-- Use the child component here -->
            <AnalysesPhenotypeFunctionalCorrelation />
          </b-tab>
        </b-col>
      </b-row>
    </b-container>
  </div>
</template>

<script>
import toastMixin from '@/assets/js/mixins/toastMixin';
// IMPORTANT: Import your child
import AnalysesPhenotypeFunctionalCorrelation from '@/components/analyses/AnalysesPhenotypeFunctionalCorrelation.vue';

export default {
  name: 'PhenotypeFunctionalCorrelation',
  components: {
    AnalysesPhenotypeFunctionalCorrelation,
  },
  mixins: [toastMixin],
  metaInfo: {
    title: 'Pheno-Func Correlation',
    titleTemplate:
      '%s | SysNDD - The expert curated database of gene disease relationships in neurodevelopmental disorders',
    htmlAttrs: { lang: 'en' },
    meta: [
      {
        vmid: 'description',
        name: 'description',
        content:
          'Shows the correlation between phenotype-based clusters and functional clusters, plus optional SFARI genes, in a heatmap format.',
      },
    ],
  },
  data() {
    return {
      tabIndex: 0,
    };
  },
  mounted() {
    // no special logic needed here
  },
};
</script>

<style scoped>
</style>
