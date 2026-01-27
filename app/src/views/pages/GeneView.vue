<template>
  <div class="container-fluid bg-gradient">
    <!-- Loading State (REDESIGN-05): Simple centered spinner per CONTEXT.md -->
    <div v-if="loading" class="d-flex justify-content-center align-items-center py-5">
      <BSpinner label="Loading gene data..." />
    </div>

    <!-- Gene Content (appears all at once when ready) -->
    <BContainer v-else fluid>
      <!-- Hero Section (REDESIGN-01) -->
      <GeneHero
        :symbol="geneSymbol"
        :name="geneName"
        :chromosome-location="chromosomeLocation"
      />

      <!-- Cards Grid (REDESIGN-09: Responsive layout) -->
      <BRow class="g-3 py-3">
        <!-- Identifier Card (REDESIGN-02) -->
        <BCol cols="12" lg="6">
          <IdentifierCard
            v-if="gene"
            :gene-data="gene"
          />
        </BCol>

        <!-- Clinical Resources Card (REDESIGN-03, REDESIGN-04) -->
        <BCol cols="12" lg="6">
          <ClinicalResourcesCard
            :symbol="geneSymbol"
            :hgnc-id="hgncId"
            :omim-id="omimId"
            :mgd-id="mgdId"
            :rgd-id="rgdId"
          />
        </BCol>
      </BRow>

      <!-- Associated Entities Table (preserved from original) -->
      <TablesEntities
        v-if="geneData.length !== 0"
        :show-filter-controls="false"
        :show-pagination-controls="false"
        header-label="Associated "
        :filter-input="filterInput"
      />
    </BContainer>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useHead } from '@unhead/vue';
import { useToast } from '@/composables';
import axios from 'axios';
import GeneHero from '@/components/gene/GeneHero.vue';
import IdentifierCard from '@/components/gene/IdentifierCard.vue';
import ClinicalResourcesCard from '@/components/gene/ClinicalResourcesCard.vue';
import TablesEntities from '@/components/tables/TablesEntities.vue';
import type { GeneApiData } from '@/types/gene';

const route = useRoute();
const router = useRouter();
const { makeToast } = useToast();

const loading = ref(true);
const geneData = ref<GeneApiData[]>([]);

// Computed properties (use computed for all derived data — do NOT access nested arrays in template)
const gene = computed(() => geneData.value[0] || null);
const geneSymbol = computed(() => gene.value?.symbol?.[0] || '');
const geneName = computed(() => gene.value?.name?.[0] || '');
const chromosomeLocation = computed(() => gene.value?.bed_hg38?.[0] || '');
const hgncId = computed(() => gene.value?.hgnc_id?.[0] || '');
const omimId = computed(() => gene.value?.omim_id?.[0] || '');
const mgdId = computed(() => gene.value?.mgd_id?.[0] || '');
const rgdId = computed(() => gene.value?.rgd_id?.[0] || '');
const filterInput = computed(() =>
  geneData.value.length > 0
    ? `equals(symbol,${geneData.value[0].symbol})`
    : ''
);

// Data loading (preserve existing logic)
async function loadGeneInfo() {
  loading.value = true;
  const symbol = route.params.symbol as string;
  const apiBase = import.meta.env.VITE_API_URL;
  const apiGeneURL = `${apiBase}/api/gene/${symbol}?input_type=hgnc`;
  const apiGeneSymbolURL = `${apiBase}/api/gene/${symbol}?input_type=symbol`;

  try {
    const responseGene = await axios.get(apiGeneURL);
    const responseSymbol = await axios.get(apiGeneSymbolURL);

    if (responseGene.data.length === 0 && responseSymbol.data.length === 0) {
      router.push('/PageNotFound');
    } else if (responseGene.data.length === 0) {
      geneData.value = responseSymbol.data;
    } else {
      geneData.value = responseGene.data;
    }
  } catch (e) {
    makeToast(e as string, 'Error', 'danger');
  }
  loading.value = false;
}

// Dynamic page title
useHead({
  title: computed(() => geneSymbol.value ? `Gene: ${geneSymbol.value}` : 'Gene'),
  meta: [
    {
      name: 'description',
      content: computed(() =>
        geneSymbol.value
          ? `Gene information for ${geneSymbol.value} (${geneName.value})`
          : 'This Gene view shows specific information for a gene.'
      ),
    },
  ],
});

// Lifecycle
onMounted(() => {
  loadGeneInfo();
});

// Route watcher (handle navigation between genes without full page reload)
watch(() => route.params.symbol, (newSymbol) => {
  if (newSymbol) {
    loadGeneInfo();
  }
});
</script>

<style scoped>
/* Page-level styles only - component styles are in their respective files */
</style>
