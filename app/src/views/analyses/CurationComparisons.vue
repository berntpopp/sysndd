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

              <b-tab title="Similarity">
                <AnalysesCurationMatrixPlot />
              </b-tab>

              <b-tab title="Table">
                <AnalysesCurationComparisonsTable />
              </b-tab>
            </b-tabs>
          </div>
        </b-col>
      </b-row>
    </b-container>
  </div>
</template>


<script>
import AnalysesCurationUpset from "@/components/analyses/AnalysesCurationUpset.vue";
import AnalysesCurationMatrixPlot from "@/components/analyses/AnalysesCurationMatrixPlot.vue";
import AnalysesCurationComparisonsTable from "@/components/analyses/AnalysesCurationComparisonsTable.vue";

import toastMixin from "@/assets/js/mixins/toastMixin.js";

export default {
  name: "CurationComparisons",
  components: {
    AnalysesCurationUpset,
    AnalysesCurationMatrixPlot,
    AnalysesCurationComparisonsTable,
  },
  mixins: [toastMixin],
  metaInfo: {
    // if no subcomponents specify a metaInfo.title, this title will be used
    title: "Curation comparisons",
    // all titles will be injected into this template
    titleTemplate:
      "%s | SysNDD - The expert curated database of gene disease relationships in neurodevelopmental disorders",
    htmlAttrs: {
      lang: "en",
    },
    meta: [
      {
        vmid: "description",
        name: "description",
        content:
          "The Comparisions analysis can be used to compare different curation efforts for neurodevelopmental disorders (inlucing attention-deficit/hyperactivity disorder (ADHD), autism spectrum disorders (ASD), learning disabilities and intellectual disability) based on UpSet plots, similarity matrix or tabular views.",
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