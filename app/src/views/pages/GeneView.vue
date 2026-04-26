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
    <!-- 1. Header band (gene record) -->
    <BContainer fluid class="pt-2">
      <BRow>
        <BCol cols="12">
          <SectionCard
            :loading="geneRecord.loading.value"
            :empty="!geneRecord.loading.value && geneRecord.data.value === null && !geneRecord.error.value"
            :error="geneRecord.error.value ? geneRecord.error.value.message : null"
            :title="geneSymbol ? `Gene ${geneSymbol}` : 'Gene'"
            min-height="6rem"
          >
            <template #header>
              <div class="d-flex align-items-center gap-1 flex-wrap">
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
                  class="gene-card-location text-muted ms-1"
                >
                  {{ chromosomeLocation }}
                </span>
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
              <IdentifierCard
                v-if="gene"
                :gene-data="gene"
                compact
              />
            </div>
          </SectionCard>
        </BCol>
      </BRow>
    </BContainer>

    <!-- 2. Associated Entities — mounted on tick 0 from URL-shape filter -->
    <TablesEntities
      :show-filter-controls="false"
      :show-pagination-controls="false"
      header-label="Associated "
      :filter-input="entityFilter"
      :disable-url-sync="true"
    />

    <!-- 3. External cards: 3-up grid at lg+, hide-when-empty -->
    <BContainer fluid class="pt-2">
      <BRow>
        <BCol
          cols="12"
          lg="4"
          class="mb-2"
        >
          <SectionCard
            :loading="constraint.loading.value"
            :empty="!constraint.loading.value && (gnomadConstraintsJson === null || gnomadConstraintsJson === '') && !constraint.error.value"
            :error="null"
            title="Gene Constraint (gnomAD)"
          >
            <GeneConstraintCard
              :gene-symbol="geneSymbol"
              :constraints-json="gnomadConstraintsJson"
            />
          </SectionCard>
        </BCol>
        <BCol
          cols="12"
          lg="4"
          class="mb-2"
        >
          <SectionCard
            :loading="clinvar.loading.value"
            :empty="!clinvar.loading.value && (clinvar.data.value === null || clinvar.data.value.length === 0) && !clinvar.error.value"
            :error="clinvar.error.value ? clinvar.error.value.message : null"
            title="ClinVar Variants"
          >
            <GeneClinVarCard
              :gene-symbol="geneSymbol"
              :loading="false"
              :error="null"
              :data="clinvar.data.value"
              @retry="clinvar.refresh"
            />
          </SectionCard>
        </BCol>
        <BCol
          cols="12"
          lg="4"
          class="mb-2"
        >
          <SectionCard
            :loading="mgi.loading.value || rgd.loading.value"
            :empty="modelOrgEmpty"
            :error="modelOrgError"
            title="Model Organisms"
          >
            <ModelOrganismsCard
              :gene-symbol="geneSymbol"
              :mgi-loading="false"
              :mgi-error="null"
              :mgi-data="mgiCardData"
              :rgd-loading="false"
              :rgd-error="null"
              :rgd-data="rgdCardData"
              @retry="retryAllExternalData"
            />
          </SectionCard>
        </BCol>
      </BRow>

      <!-- 4. Genomic visualizations -->
      <BRow class="pt-2">
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
</template>

<script setup lang="ts">
import { computed, watch } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { useHead } from '@unhead/vue';
import { BContainer, BRow, BCol } from 'bootstrap-vue-next';
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
import { useGeneAlphaFold } from '@/composables/useGeneAlphaFold';
import { useGeneUniProt } from '@/composables/useGeneUniProt';
import { useGeneMGI } from '@/composables/useGeneMGI';
import { useGeneRGD } from '@/composables/useGeneRGD';
import type { MGIPhenotypeData, RGDPhenotypeData } from '@/types/external';

const route = useRoute();
const router = useRouter();

const HGNC_RE = /^HGNC:?\d+$/i;

// URL-shape filter: entity API accepts both equals(symbol,X) and equals(hgnc_id,HGNC:N).
// Mounted on the same tick as the page — no waiting on the gene record.
const routeParam = computed(() => (route.params.symbol as string) || '');
const entityFilter = computed(() =>
  routeParam.value
    ? HGNC_RE.test(routeParam.value)
      ? `equals(hgnc_id,${routeParam.value})`
      : `equals(symbol,${routeParam.value})`
    : '',
);

// Per-source hooks — all fire on tick 0. Gene record drives the header card +
// constraint card; ClinVar/AlphaFold/UniProt/MGI/RGD each own a SectionCard.
const geneRecord = useGeneRecord(routeParam);

// Computed projections from the gene record (must be declared before hooks
// that depend on geneSymbol).
const gene = computed(() => geneRecord.data.value);
const geneSymbol = computed(() =>
  gene.value?.symbol?.[0]
    ?? (HGNC_RE.test(routeParam.value) ? '' : routeParam.value),
);
const geneName = computed(() => gene.value?.name?.[0] ?? '');
const chromosomeLocation = computed(() => gene.value?.bed_hg38?.[0] ?? '');
const hgncId = computed(() => gene.value?.hgnc_id?.[0] ?? '');
const omimId = computed(() => gene.value?.omim_id?.[0] ?? '');
const mgdId = computed(() => gene.value?.mgd_id?.[0] ?? '');
const rgdId = computed(() => gene.value?.rgd_id?.[0] ?? '');
const gnomadConstraintsJson = computed(() => gene.value?.gnomad_constraints ?? null);

const symbolForExternal = computed<string | null>(() =>
  geneSymbol.value ? geneSymbol.value : null,
);
const clinvar = useGeneClinVar(symbolForExternal);
const alphafold = useGeneAlphaFold(symbolForExternal);
const uniprot = useGeneUniProt(symbolForExternal);
const mgi = useGeneMGI(symbolForExternal);
const rgd = useGeneRGD(symbolForExternal);

// Constraint card has no separate hook (data lives on the gene record).
// Expose a ResourceState-shaped slice so SectionCard can drive the skeleton.
const constraint = {
  loading: geneRecord.loading,
  error: geneRecord.error,
} as const;

// The W1 hook payload types are structurally narrower than the card props
// (the card expects the full MGI/RGD response shape from /api/external).
// The runtime payload matches; cast through `unknown` to satisfy TS without
// duplicating type definitions.
const mgiCardData = computed<MGIPhenotypeData | null>(
  () => mgi.data.value as unknown as MGIPhenotypeData | null,
);
const rgdCardData = computed<RGDPhenotypeData | null>(
  () => rgd.data.value as unknown as RGDPhenotypeData | null,
);

// Combined Model Organism empty/error logic.
const modelOrgEmpty = computed(() => {
  if (mgi.loading.value || rgd.loading.value) return false;
  const mgiPhenos = mgi.data.value?.phenotypes;
  const rgdPhenos = rgd.data.value?.phenotypes;
  const noMgi = !mgi.data.value || !mgiPhenos || mgiPhenos.length === 0;
  const noRgd = !rgd.data.value || !rgdPhenos || rgdPhenos.length === 0;
  return noMgi && noRgd;
});
const modelOrgError = computed(() =>
  (mgi.error.value && rgd.error.value)
    ? `${mgi.error.value.message} / ${rgd.error.value.message}`
    : null,
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

// 404 redirect: only when the gene record returns null (canonical not-found).
watch(geneRecord.data, (val) => {
  if (!geneRecord.loading.value && val === null && routeParam.value) {
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
          : 'This Gene view shows specific information for a gene.',
      ),
    },
  ],
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
