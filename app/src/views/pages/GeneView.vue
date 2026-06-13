<!-- app/src/views/pages/GeneView.vue (v11.3 W2 rewrite) -->
<!--
  Mount order:
    1. <TablesEntities> mounts on tick 0 with a URL-shape filter (§4.2.1).
    2. useGeneRecord(routeParam) fires in parallel; header card renders skeleton.
    3. ClinVar / AlphaFold / UniProt / MGI / RGD hooks fire in parallel; each
       owns its <SectionCard> skeleton + hide-when-empty.
    4. <GenomicVisualizationTabs> lazy-mounts inactive panels via <KeepAlive>.

  Spec: .planning/superpowers/specs/2026-04-26-v11.3-genes-entities-perf-ux-design.md
        §4.2 (entities-first), §4.3 (SectionCard wrapper), §4.5/§4.6 (URL-shape filter).
-->
<template>
  <div class="container-fluid bg-gradient">
    <!-- 1. Gene info header — production-parity BCard, header rendered while gene record hydrates -->
    <div class="container-fluid">
      <BContainer fluid>
        <BRow class="justify-content-md-center pt-2">
          <BCol col md="12">
            <BCard body-class="p-0" header-class="p-1" border-variant="dark">
              <template #header>
                <div class="d-flex align-items-center gap-1 flex-wrap">
                  <h1 class="gene-page-title mb-0">
                    <span v-if="geneSymbol">{{ geneSymbol }}</span>
                    <span v-else>Gene</span>
                  </h1>
                  <GeneBadge
                    v-if="geneSymbol"
                    :symbol="geneSymbol"
                    size="sm"
                    :link-to="undefined"
                    :show-title="false"
                  />
                  <span class="gene-card-name ms-1">{{ geneName }}</span>
                  <span
                    v-if="chromosomeLocation && chromosomeLocation !== 'null'"
                    class="gene-card-location ms-1"
                  >
                    {{ chromosomeLocation }}
                  </span>
                  <RouterLink
                    v-if="backToResults"
                    class="btn btn-sm btn-outline-secondary ms-auto"
                    :to="backToResults"
                  >
                    Back to results
                  </RouterLink>
                </div>
              </template>
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
              <div class="px-3 py-1">
                <IdentifierCard v-if="gene" :gene-data="gene" compact />
              </div>
            </BCard>
          </BCol>
        </BRow>
      </BContainer>
    </div>

    <!-- 2. Associated Entities — mounted on tick 0 from URL-shape filter -->
    <TablesEntities
      :show-filter-controls="false"
      :show-search-input="false"
      :show-pagination-controls="false"
      header-label="Associated "
      :filter-input="entityFilter"
      :disable-url-sync="true"
    />

    <!-- 3. External cards: 3-up grid at md+, each SectionCard renders skeleton during load
         then unwraps to show the inner card's own frame (no double border) -->
    <div class="container-fluid">
      <BContainer fluid>
        <BRow class="justify-content-md-center pt-2">
          <BCol cols="12" lg="6" xxl="4" class="mb-2" data-testid="gene-external-card-col">
            <SectionCard
              frameless
              :loading="geneRecord.loading.value"
              :empty="false"
              :error="null"
              title="Gene Constraint (gnomAD)"
              min-height="16rem"
            >
              <GeneConstraintCard
                :gene-symbol="geneSymbol"
                :constraints-json="gnomadConstraintsJson"
              />
            </SectionCard>
          </BCol>
          <BCol cols="12" lg="6" xxl="4" class="mb-2" data-testid="gene-external-card-col">
            <SectionCard
              frameless
              :loading="clinvarCounts.loading.value"
              :empty="false"
              :error="clinvarCounts.error.value ? clinvarCounts.error.value.message : null"
              title="ClinVar Variants"
              min-height="16rem"
            >
              <GeneClinVarCard
                :gene-symbol="geneSymbol"
                :loading="false"
                :error="null"
                :counts="clinvarCounts.data.value?.counts ?? null"
                :class-breakdowns="clinvarCounts.data.value?.class_breakdowns ?? null"
                :consequence-counts="clinvarCounts.data.value?.consequence_counts ?? null"
                :total-count="clinvarCounts.data.value?.variant_count ?? 0"
                @retry="clinvarCounts.refresh"
              />
            </SectionCard>
          </BCol>
          <BCol cols="12" lg="6" xxl="4" class="mb-2" data-testid="gene-external-card-col">
            <SectionCard
              frameless
              :loading="mgi.loading.value && rgd.loading.value"
              :empty="false"
              :error="modelOrgError"
              title="Model Organisms"
              min-height="16rem"
            >
              <ModelOrganismsCard
                :gene-symbol="geneSymbol"
                :mgi-loading="mgi.loading.value"
                :mgi-error="mgi.error.value ? mgi.error.value.message : null"
                :mgi-data="mgiCardData"
                :rgd-loading="rgd.loading.value"
                :rgd-error="rgd.error.value ? rgd.error.value.message : null"
                :rgd-data="rgdCardData"
                @retry="retryAllExternalData"
              />
            </SectionCard>
          </BCol>
        </BRow>
      </BContainer>
    </div>

    <!-- 4. Genomic Visualizations: Protein View / Gene Structure / 3D Structure (tabbed, lazy-mount inactive panels) -->
    <div class="container-fluid">
      <BContainer fluid>
        <BRow class="justify-content-md-center pt-2">
          <BCol cols="12">
            <GenomicVisualizationTabs
              v-if="geneSymbol"
              :gene-symbol="geneSymbol"
              :clinvar-variants="clinvar.data.value"
              :clinvar-loading="clinvar.loading.value"
              :clinvar-error="clinvar.error.value ? clinvar.error.value.message : null"
              :uniprot-data="uniprot.data.value"
              :uniprot-loading="uniprot.loading.value"
              :uniprot-error="uniprot.error.value ? uniprot.error.value.message : null"
              :chromosome-location="chromosomeLocation"
              :alphafold-pdb-url="alphafold.data.value?.pdb_url ?? null"
              :alphafold-metadata="alphafold.data.value ?? null"
              :alphafold-loading="alphafold.loading.value"
              :alphafold-error="alphafold.error.value ? alphafold.error.value.message : null"
              @retry="retryAllExternalData"
            />
          </BCol>
        </BRow>
      </BContainer>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, watch, ref, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useHead } from '@unhead/vue';
import { BContainer, BRow, BCol, BCard } from 'bootstrap-vue-next';
import GeneBadge from '@/components/ui/GeneBadge.vue';
import IdentifierCard from '@/components/gene/IdentifierCard.vue';
import ClinicalResourcesCard from '@/components/gene/ClinicalResourcesCard.vue';
import GeneConstraintCard from '@/components/gene/GeneConstraintCard.vue';
import GeneClinVarCard from '@/components/gene/GeneClinVarCard.vue';
import ModelOrganismsCard from '@/components/gene/ModelOrganismsCard.vue';
import GenomicVisualizationTabs from '@/components/gene/GenomicVisualizationTabs.vue';
import TablesEntities from '@/components/tables/TablesEntities.vue';
import SectionCard from '@/components/ui/SectionCard.vue';
import { useGeneRecord } from '@/composables/useGeneRecord';
import { useGeneClinVar } from '@/composables/useGeneClinVar';
import { useGeneClinVarCounts } from '@/composables/useGeneClinVarCounts';
import { useGeneAlphaFold } from '@/composables/useGeneAlphaFold';
import { useGeneUniProt } from '@/composables/useGeneUniProt';
import { useGeneMGI } from '@/composables/useGeneMGI';
import { useGeneRGD } from '@/composables/useGeneRGD';
import type { MGIPhenotypeData, RGDPhenotypeData } from '@/types/external';
import { returnToFromRoute } from '@/utils/returnNavigation';

const route = useRoute();
const router = useRouter();
const backToResults = computed(() => returnToFromRoute(route, ''));

const HGNC_RE = /^HGNC:?\d+$/i;

// URL-shape filter: entity API accepts both equals(symbol,X) and equals(hgnc_id,HGNC:N).
// Mounted on the same tick as the page — no waiting on the gene record.
const routeParam = computed(() => (route.params.symbol as string) || '');
const entityFilter = computed(() =>
  routeParam.value
    ? HGNC_RE.test(routeParam.value)
      ? `equals(hgnc_id,${routeParam.value})`
      : `equals(symbol,${routeParam.value})`
    : ''
);

// Per-source hooks — all fire on tick 0. Gene record drives the header card +
// constraint card; ClinVar/AlphaFold/UniProt/MGI/RGD each own a SectionCard.
const geneRecord = useGeneRecord(routeParam);

// Computed projections from the gene record (must be declared before hooks
// that depend on geneSymbol).
const gene = computed(() => geneRecord.data.value);
const geneSymbol = computed(
  () => gene.value?.symbol?.[0] ?? (HGNC_RE.test(routeParam.value) ? '' : routeParam.value)
);
const geneName = computed(() => gene.value?.name?.[0] ?? '');
const chromosomeLocation = computed(() => gene.value?.bed_hg38?.[0] ?? '');
const hgncId = computed(() => gene.value?.hgnc_id?.[0] ?? '');
const omimId = computed(() => gene.value?.omim_id?.[0] ?? '');
const mgdId = computed(() => gene.value?.mgd_id?.[0] ?? '');
const rgdId = computed(() => gene.value?.rgd_id?.[0] ?? '');
const gnomadConstraintsJson = computed(() => gene.value?.gnomad_constraints ?? null);

// #344: defer external-provider activation until after mount so the child
// <TablesEntities> entity request (our own above-the-fold data) is DISPATCHED
// FIRST. The API is single-threaded per process and serves requests in arrival
// order; useResource's immediate watcher fires the 6 external enrichment calls
// synchronously in this parent setup(), before the child's mounted() hook runs
// the entity fetch. On a symbol URL (where the symbol is known immediately) that
// queued the cheap entity request behind up to 6 slow upstream calls — making
// "Associated" load last. onMounted runs AFTER the child's mounted() hook, so
// gating the external key here guarantees own-data is requested first.
const externalsReady = ref(false);
onMounted(() => {
  // Defer to a macrotask (setTimeout 0): this runs AFTER the microtask queue
  // drains — including the child <TablesEntities> $nextTick-scheduled entity
  // fetch and all Vue reactive watcher flushes — so our own-data requests
  // (gene record + Associated entities) are dispatched BEFORE the external
  // enrichment calls, regardless of warm/cold cache or symbol-vs-HGNC URL form.
  window.setTimeout(() => {
    externalsReady.value = true;
  }, 0);
});
const symbolForExternal = computed<string | null>(() =>
  externalsReady.value && geneSymbol.value ? geneSymbol.value : null
);
// ClinVar counts power the small above-the-fold card (~250 B response).
// The full variant list (~520 KB) is fetched separately for the genomic
// visualization tabs below the entities table — see useGeneClinVar usage.
const clinvarCounts = useGeneClinVarCounts(symbolForExternal);
const clinvar = useGeneClinVar(symbolForExternal);
const alphafold = useGeneAlphaFold(symbolForExternal);
const uniprot = useGeneUniProt(symbolForExternal);
const mgi = useGeneMGI(symbolForExternal);
const rgd = useGeneRGD(symbolForExternal);

// The W1 hook payload types are structurally narrower than the card props
// (the card expects the full MGI/RGD response shape from /api/external).
// The runtime payload matches; cast through `unknown` to satisfy TS without
// duplicating type definitions.
const mgiCardData = computed<MGIPhenotypeData | null>(
  () => mgi.data.value as unknown as MGIPhenotypeData | null
);
const rgdCardData = computed<RGDPhenotypeData | null>(
  () => rgd.data.value as unknown as RGDPhenotypeData | null
);

const modelOrgError = computed(() =>
  mgi.error.value && rgd.error.value
    ? `${mgi.error.value.message} / ${rgd.error.value.message}`
    : null
);

async function retryAllExternalData(): Promise<void> {
  await Promise.all([
    clinvar.refresh(),
    alphafold.refresh(),
    uniprot.refresh(),
    mgi.refresh(),
    rgd.refresh(),
  ]);
}

// 404 redirect: watch [loading, data] so it fires both on the cold loading→resolved
// edge (Ref-identity null→null wouldn't trigger a data-only watcher) and on
// stale→null SWR background transitions.
watch([geneRecord.loading, geneRecord.data], () => {
  if (
    !geneRecord.loading.value &&
    geneRecord.data.value === null &&
    !geneRecord.error.value &&
    routeParam.value
  ) {
    router.push('/PageNotFound');
  }
});

useHead({
  title: computed(() => (geneSymbol.value ? `Gene: ${geneSymbol.value}` : 'Gene')),
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
</script>

<style scoped>
.gene-page-title {
  font-size: 1rem;
  line-height: 1.2;
  font-weight: 700;
}
.gene-card-name {
  font-weight: 600;
  font-size: 0.95rem;
  color: #333;
}
.gene-card-location {
  font-size: 0.8rem;
  font-family: 'Courier New', monospace;
  color: #495057;
}
</style>
