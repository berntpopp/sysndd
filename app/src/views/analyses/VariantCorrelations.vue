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
              title="Variant correlations"
              no-body
            >
              <b-card-header header-tag="nav">
                <b-nav
                  card-header
                  tabs
                >
                  <!-- Child routes for variant analyses -->
                  <b-nav-item
                    to="/VariantCorrelations"
                    exact
                    exact-active-class="active"
                  >
                    Variant correlogram
                  </b-nav-item>
                  <b-nav-item
                    to="/VariantCorrelations/VariantCounts"
                    exact
                    exact-active-class="active"
                  >
                    Variant counts
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
  name: 'VariantCorrelations',
  mixins: [toastMixin],
  setup() {
    useHead({
      title: 'Variant correlations',
      meta: [
        {
          name: 'description',
          content:
            'The Variant analysis can be used to compare the correlations between genetic variants observed in neurodevelopmental disorders.',
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
    // Placeholder if needed for future enhancements
  },
  methods: {},
};
</script>

<style scoped>
</style>
