<template>
  <div class="container-fluid bg-gradient">
    <!-- Loading State (REDESIGN-05): Simple centered spinner per CONTEXT.md -->
    <div v-if="loading" class="d-flex justify-content-center align-items-center py-5">
      <BSpinner label="Loading gene data..." />
    </div>

    <!-- Gene Content (appears all at once when ready) -->
    <template v-else>
      <!-- Gene info card — wrapped to match TablesEntities container nesting -->
      <div class="container-fluid">
        <BContainer fluid>
          <BRow class="justify-content-md-center pt-2">
            <BCol col md="12">
              <BCard body-class="p-0" header-class="p-1" border-variant="dark">
                <template #header>
                  <div class="d-flex align-items-center gap-1 flex-wrap">
                    <GeneBadge
                      :symbol="geneSymbol"
                      size="sm"
                      :link-to="undefined"
                      :show-title="false"
                    />
                    <span class="gene-card-name ms-1">{{ geneName }}</span>
                    <span v-if="chromosomeLocation && chromosomeLocation !== 'null'" class="gene-card-location text-muted ms-1">
                      {{ chromosomeLocation }}
                    </span>
                  </div>
                </template>

                <!-- External resources as inline badges -->
                <div class="px-3 py-1 border-bottom bg-light">
                  <ClinicalResourcesCard
                    compact
                    :symbol="geneSymbol"
                    :hgnc-id="hgncId"
                    :omim-id="omimId"
                    :mgd-id="mgdId"
                    :rgd-id="rgdId"
                  />
                </div>

                <!-- Identifiers as inline badges -->
                <div class="px-3 py-1">
                  <IdentifierCard
                    v-if="gene"
                    :gene-data="gene"
                    compact
                  />
                </div>
              </BCard>
            </BCol>
          </BRow>
        </BContainer>
      </div>

      <!-- External genomic data cards -->
      <div class="container-fluid">
        <BContainer fluid>
          <BRow class="justify-content-md-center pt-2">
            <BCol cols="12" md="6" class="mb-2">
              <GeneConstraintCard
                :gene-symbol="geneSymbol"
                :constraints-json="gnomadConstraintsJson"
              />
            </BCol>
            <BCol cols="12" md="6" class="mb-2">
              <GeneClinVarCard
                :gene-symbol="geneSymbol"
                :loading="clinvar.loading.value"
                :error="clinvar.error.value"
                :data="clinvar.data.value"
                @retry="retryExternalData"
              />
            </BCol>
          </BRow>
        </BContainer>
      </div>

      <!-- Protein Domain Lollipop Plot -->
      <div class="container-fluid">
        <BContainer fluid>
          <BRow class="justify-content-md-center pt-2">
            <BCol cols="12">
              <ProteinDomainLollipopCard
                :uniprot-data="uniprotData"
                :clinvar-variants="clinvar.data.value"
                :uniprot-loading="uniprotLoading"
                :clinvar-loading="clinvar.loading.value"
                :uniprot-error="uniprotError"
                :clinvar-error="clinvar.error.value"
                :gene-symbol="geneSymbol"
                @retry="retryAllExternalData"
              />
            </BCol>
          </BRow>
        </BContainer>
      </div>

      <!-- Gene Structure Visualization (GENSTRUCT-01 through GENSTRUCT-04) -->
      <div class="container-fluid">
        <BContainer fluid>
          <BRow class="justify-content-md-center pt-2">
            <BCol col md="12">
              <GeneStructureCard
                v-if="geneSymbol"
                :gene-symbol="geneSymbol"
              />
            </BCol>
          </BRow>
        </BContainer>
      </div>

      <!-- Associated Entities Table -->
      <TablesEntities
        v-if="geneData.length !== 0"
        :show-filter-controls="false"
        :show-pagination-controls="false"
        header-label="Associated "
        :filter-input="filterInput"
        :disable-url-sync="true"
      />
    </template>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useHead } from '@unhead/vue';
import { useToast } from '@/composables';
import { useGeneExternalData } from '@/composables/useGeneExternalData';
import axios from 'axios';
import GeneBadge from '@/components/ui/GeneBadge.vue';
import IdentifierCard from '@/components/gene/IdentifierCard.vue';
import ClinicalResourcesCard from '@/components/gene/ClinicalResourcesCard.vue';
import GeneConstraintCard from '@/components/gene/GeneConstraintCard.vue';
import GeneClinVarCard from '@/components/gene/GeneClinVarCard.vue';
import ProteinDomainLollipopCard from '@/components/gene/ProteinDomainLollipopCard.vue';
import GeneStructureCard from '@/components/gene/GeneStructureCard.vue';
import TablesEntities from '@/components/tables/TablesEntities.vue';
import type { GeneApiData } from '@/types/gene';

/**
 * UniProt domain feature from the API response
 */
interface UniProtDomainFeature {
  type: string;
  description?: string;
  begin: number | string;
  end: number | string;
}

/**
 * UniProt API response structure from /api/external/uniprot/domains/<symbol>
 */
interface UniProtData {
  source: string;
  gene_symbol: string;
  accession: string;
  protein_name: string;
  protein_length: number | string;
  domains: UniProtDomainFeature[];
}

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

// gnomAD constraint data from gene endpoint (pre-annotated in DB)
const gnomadConstraintsJson = computed(() => gene.value?.gnomad_constraints?.[0] || null);

// AlphaFold model identifier from gene endpoint (used by Phase 45 3D protein structure viewer)
// eslint-disable-next-line @typescript-eslint/no-unused-vars
const alphafoldId = computed(() => gene.value?.alphafold_id?.[0] || null);

// ClinVar data (fetched live from per-source endpoint)
const { clinvar, fetchData: fetchClinvarData, retry: retryExternalData } = useGeneExternalData(geneSymbol);

// UniProt domain data state (fetched inline since composable is ClinVar-only)
const uniprotData = ref<UniProtData | null>(null);
const uniprotLoading = ref(false);
const uniprotError = ref<string | null>(null);

/**
 * Fetch UniProt domain data for the protein lollipop plot
 * Separate from ClinVar because they have different cache TTLs and error modes
 */
async function fetchUniprotData(): Promise<void> {
  if (!geneSymbol.value) return;

  uniprotLoading.value = true;
  uniprotError.value = null;

  try {
    const apiBase = import.meta.env.VITE_API_URL;
    const response = await axios.get(
      `${apiBase}/api/external/uniprot/domains/${geneSymbol.value}`
    );

    // Check for valid response with domains
    if (response.data && response.data.domains) {
      uniprotData.value = response.data;
    } else {
      uniprotData.value = null;
    }
  } catch (err) {
    if (axios.isAxiosError(err) && err.response?.status === 404) {
      // Gene not found in UniProt - not an error, just no data
      uniprotData.value = null;
      uniprotError.value = null;
    } else {
      const message = err instanceof Error ? err.message : 'Failed to fetch UniProt data';
      uniprotError.value = message;
      uniprotData.value = null;
    }
  } finally {
    uniprotLoading.value = false;
  }
}

/**
 * Fetch all external data (ClinVar + UniProt)
 */
async function fetchExternalData(): Promise<void> {
  // Fetch both in parallel
  await Promise.all([fetchClinvarData(), fetchUniprotData()]);
}

/**
 * Retry fetching all external data
 */
async function retryAllExternalData(): Promise<void> {
  await fetchExternalData();
}

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

  // Fetch ClinVar data after gene data loads successfully
  if (geneData.value.length > 0) {
    fetchExternalData();
  }
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
.gene-card-name {
  font-weight: 600;
  font-size: 0.95rem;
  color: #333;
}
.gene-card-location {
  font-size: 0.8rem;
  font-family: 'Courier New', monospace;
}
</style>
