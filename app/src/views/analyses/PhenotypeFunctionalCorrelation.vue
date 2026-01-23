<template>
  <div class="container-fluid bg-gradient">
    <BContainer fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol md="12">
          <!-- Use the child component here -->
          <AnalysesPhenotypeFunctionalCorrelation />
        </BCol>
      </BRow>
    </BContainer>
  </div>
</template>

<script>
import { useHead } from '@unhead/vue';
import toastMixin from '@/assets/js/mixins/toastMixin';
// IMPORTANT: Import your child
import AnalysesPhenotypeFunctionalCorrelation from '@/components/analyses/AnalysesPhenotypeFunctionalCorrelation.vue';

export default {
  name: 'PhenotypeFunctionalCorrelation',
  components: {
    AnalysesPhenotypeFunctionalCorrelation,
  },
  mixins: [toastMixin],
  setup() {
    useHead({
      title: 'Pheno-Func Correlation',
      meta: [
        {
          name: 'description',
          content:
            'Shows the correlation between phenotype-based clusters and functional clusters, plus optional SFARI genes, in a heatmap format.',
        },
      ],
    });
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
