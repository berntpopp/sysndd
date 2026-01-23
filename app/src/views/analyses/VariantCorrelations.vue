<template>
  <div class="container-fluid bg-gradient">
    <BContainer fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol
          col
          md="12"
        >
          <div>
            <BCard
              title="Variant correlations"
              no-body
            >
              <BCardHeader header-tag="nav">
                <BNav
                  card-header
                  tabs
                >
                  <!-- Child routes for variant analyses -->
                  <BNavItem
                    to="/VariantCorrelations"
                    exact
                    exact-active-class="active"
                  >
                    Variant correlogram
                  </BNavItem>
                  <BNavItem
                    to="/VariantCorrelations/VariantCounts"
                    exact
                    exact-active-class="active"
                  >
                    Variant counts
                  </BNavItem>
                </BNav>
              </BCardHeader>

              <BCardBody>
                <router-view />
              </BCardBody>
            </BCard>
          </div>
        </BCol>
      </BRow>
    </BContainer>
  </div>
</template>

<script>
import { useHead } from '@unhead/vue';
import useToast from '@/composables/useToast';
import * as d3 from 'd3';

export default {
  name: 'VariantCorrelations',
  setup() {
    const { makeToast } = useToast();
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

    return { makeToast };
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
