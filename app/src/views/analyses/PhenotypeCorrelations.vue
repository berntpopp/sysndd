<!-- src/views/analyses/PhenotypeCorrelations.vue -->
<template>
  <div class="container-fluid bg-gradient">
    <BContainer fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol col md="12">
          <div>
            <BCard title="Phenotype correlations" no-body>
              <BCardHeader header-tag="nav">
                <BNav card-header tabs>
                  <!-- <BNavItem>'s with child routes. Note the trailing slash on the first <BNavItem> -->
                  <BNavItem to="/PhenotypeCorrelations" exact exact-active-class="active">
                    Phenotype correlogram
                  </BNavItem>
                  <BNavItem
                    to="/PhenotypeCorrelations/PhenotypeCounts"
                    exact
                    exact-active-class="active"
                  >
                    Phenotype counts
                  </BNavItem>
                  <BNavItem
                    to="/PhenotypeCorrelations/PhenotypeClusters"
                    exact
                    exact-active-class="active"
                  >
                    Phenotype clustering
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

export default {
  name: 'PhenotypeCorrelations',
  setup() {
    const { makeToast } = useToast();
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

    return { makeToast };
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

<style scoped></style>
