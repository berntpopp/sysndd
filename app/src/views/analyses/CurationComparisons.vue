<!-- views/analyses/CurationComparisons.vue -->
<template>
  <div class="container-fluid bg-gradient">
    <BContainer fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol col md="12">
          <div>
            <BCard title="Curation comparisons" no-body>
              <BCardHeader header-tag="nav">
                <BNav card-header tabs>
                  <!-- <BNavItem>'s with child routes. Note the trailing slash on the first <BNavItem> -->
                  <BNavItem to="/CurationComparisons" exact exact-active-class="active">
                    Overlap
                  </BNavItem>
                  <BNavItem to="/CurationComparisons/Similarity" exact exact-active-class="active">
                    Similarity
                  </BNavItem>
                  <BNavItem to="/CurationComparisons/Table" exact exact-active-class="active">
                    Table
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
  name: 'CurationComparisons',
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
  setup() {
    const { makeToast } = useToast();
    useHead({
      title: 'Curation comparisons',
      meta: [
        {
          name: 'description',
          content:
            'The Comparisons analysis can be used to compare different curation efforts for neurodevelopmental disorders (including attention-deficit/hyperactivity disorder (ADHD), autism spectrum disorders (ASD), learning disabilities and intellectual disability) based on UpSet plots, similarity matrix or tabular views.',
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
  computed: {},
  watch: {},
  mounted() {},
  methods: {},
};
</script>

<style scoped></style>
