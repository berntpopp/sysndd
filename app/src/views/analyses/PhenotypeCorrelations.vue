<!-- src/views/analyses/PhenotypeCorrelations.vue -->
<template>
  <div class="container-fluid bg-gradient">
    <b-container fluid>
      <b-row class="justify-content-md-center py-2">
        <b-col
          col
          md="12"
        >
          <div>
            <b-card
              title="Phenotype correlations"
              no-body
            >
              <b-card-header header-tag="nav">
                <b-nav
                  card-header
                  tabs
                >
                  <!-- <b-nav-item>'s with child routes. Note the trailing slash on the first <b-nav-item> -->
                  <b-nav-item
                    to="/PhenotypeCorrelations"
                    exact
                    exact-active-class="active"
                  >
                    Phenotype correlogram
                  </b-nav-item>
                  <b-nav-item
                    to="/PhenotypeCorrelations/PhenotypeCounts"
                    exact
                    exact-active-class="active"
                  >
                    Phenotype counts
                  </b-nav-item>
                  <b-nav-item
                    to="/PhenotypeCorrelations/PhenotypeClusters"
                    exact
                    exact-active-class="active"
                  >
                    Phenotype clustering
                  </b-nav-item>
                </b-nav>
              </b-card-header>

              <b-card-body>
                <router-view />
              </b-card-body>
            </b-card>
          </div>
        </b-col>
      </b-row>
    </b-container>
  </div>
</template>

<script>
import { useHead } from '@unhead/vue';
import toastMixin from '@/assets/js/mixins/toastMixin';

import * as d3 from 'd3';

export default {
  name: 'PhenotypeCorrelations',
  mixins: [toastMixin],
  setup() {
    useHead({
      title: 'Phenotype correlations',
      meta: [
        {
          name: 'description',
          content:
            'The Phenotype analysis can be used to compare the correlations between phenotypes and with their associated inheritance patterns in neurodevelopmental disorders (including attention-deficit/hyperactivity disorder (ADHD), autism spectrum disorders (ASD), learning disabilities and intellectual disability).',
        },
      ],
    });
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
