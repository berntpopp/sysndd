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
                title="Overlap"
                active
              >
                <AnalysesCurationUpset />
              </b-tab>

              <b-tab
                title="Similarity"
                lazy
              >
                <AnalysesCurationMatrixPlot />
              </b-tab>

              <b-tab
                title="Table"
                lazy
              >
                <AnalysesCurationComparisonsTable
                  :sort-input="sort"
                  :filter-input="filter"
                  :fields-input="fields"
                  :page-after-input="pageAfter"
                  :page-size-input="pageSize"
                  :fspec-input="fspec"
                />
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

export default {
  name: 'CurationComparisons',
  mixins: [toastMixin],
  props: {
    sort: { type: String, default: '+symbol' },
    filter: { type: String, default: 'filter=' },
    fields: { type: String, default: null },
    pageAfter: { type: String, default: '0' },
    pageSize: { type: String, default: '10' },
    fspec: {
      type: String,
      default:
        'symbol,SysNDD,radboudumc_ID,gene2phenotype,panelapp,sfari,geisinger_DBD,omim_ndd,orphanet_id',
    },
  },
  metaInfo: {
    // if no subcomponents specify a metaInfo.title, this title will be used
    title: 'Curation comparisons',
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
          'The Comparisons analysis can be used to compare different curation efforts for neurodevelopmental disorders (including attention-deficit/hyperactivity disorder (ADHD), autism spectrum disorders (ASD), learning disabilities and intellectual disability) based on UpSet plots, similarity matrix or tabular views.',
      },
    ],
  },
  data() {
    return {
      tabIndex: 0,
    };
  },
  computed: {},
  watch: {},
  mounted() {},
  methods: {},
};
</script>

<style scoped>
</style>
