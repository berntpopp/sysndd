<template>
  <BCard
    class="clinvar-card"
    body-class="p-0"
    header-class="p-1"
    border-variant="dark"
    role="region"
    aria-label="ClinVar variant summary"
  >
    <template #header>
      <div class="d-flex justify-content-between align-items-center">
        <span class="fw-semibold small">ClinVar Variants ({{ totalCount }})</span>
        <BButton
          variant="link"
          size="sm"
          :href="`https://www.ncbi.nlm.nih.gov/clinvar/?term=${geneSymbol}[gene]`"
          target="_blank"
          rel="noopener noreferrer"
          class="text-decoration-none p-0"
          title="View on ClinVar"
          aria-label="View gene on ClinVar (opens in new tab)"
        >
          <i class="bi bi-box-arrow-up-right" aria-hidden="true"></i>
        </BButton>
      </div>
    </template>

    <!-- Loading State -->
    <div v-if="loading" class="text-center py-3">
      <BSpinner label="Loading ClinVar data..." role="status" small />
    </div>

    <!-- Error State -->
    <div v-else-if="error" class="text-center py-3" role="alert">
      <p class="text-muted mb-2 small">{{ error }}</p>
      <BButton variant="outline-primary" size="sm" @click="$emit('retry')"> Retry </BButton>
    </div>

    <!-- No Data State -->
    <div v-else-if="totalCount === 0" class="text-center py-3">
      <i class="bi bi-info-circle text-muted me-2"></i>
      <span class="text-muted small">No ClinVar variants available for this gene</span>
    </div>

    <!-- ACMG Badge Row -->
    <div v-else class="d-flex flex-wrap gap-2 px-3 py-2">
      <BBadge
        v-if="counts.pathogenic > 0"
        variant="danger"
        class="py-2 px-3"
        :aria-label="`Pathogenic: ${counts.pathogenic} variants`"
      >
        <strong>Pathogenic</strong> ({{ counts.pathogenic }})
      </BBadge>

      <BBadge
        v-if="counts.likely_pathogenic > 0"
        class="badge-lp py-2 px-3"
        :aria-label="`Likely Pathogenic: ${counts.likely_pathogenic} variants`"
      >
        <strong>Likely Pathogenic</strong> ({{ counts.likely_pathogenic }})
      </BBadge>

      <BBadge
        v-if="counts.vus > 0"
        variant="warning"
        class="py-2 px-3"
        :aria-label="`VUS: ${counts.vus} variants`"
      >
        <strong>VUS</strong> ({{ counts.vus }})
      </BBadge>

      <BBadge
        v-if="counts.likely_benign > 0"
        class="badge-lb py-2 px-3"
        :aria-label="`Likely Benign: ${counts.likely_benign} variants`"
      >
        <strong>Likely Benign</strong> ({{ counts.likely_benign }})
      </BBadge>

      <BBadge
        v-if="counts.benign > 0"
        variant="success"
        class="py-2 px-3"
        :aria-label="`Benign: ${counts.benign} variants`"
      >
        <strong>Benign</strong> ({{ counts.benign }})
      </BBadge>
    </div>
  </BCard>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { BCard, BButton, BSpinner, BBadge } from 'bootstrap-vue-next';
import type { ClinVarVariant } from '@/types/external';

export interface ClinVarCounts {
  pathogenic: number;
  likely_pathogenic: number;
  vus: number;
  likely_benign: number;
  benign: number;
}

interface Props {
  geneSymbol: string;
  loading: boolean;
  error: string | null;
  // Either pass the full variant array (`data`) and we derive counts, or pass
  // a precomputed `counts`+`totalCount` pair (preferred — see useGeneClinVarCounts).
  data?: ClinVarVariant[] | null;
  counts?: ClinVarCounts | null;
  totalCount?: number;
}

const props = withDefaults(defineProps<Props>(), {
  data: null,
  counts: null,
  totalCount: 0,
});

defineEmits<{
  retry: [];
}>();

// Count variants by ACMG pathogenicity classification — derived only when no
// precomputed counts are passed (keeps backward compat for callers that still
// hold the full ClinVarVariant[] array).
const counts = computed<ClinVarCounts>(() => {
  if (props.counts) return props.counts;
  if (!props.data || props.data.length === 0) {
    return {
      pathogenic: 0,
      likely_pathogenic: 0,
      vus: 0,
      likely_benign: 0,
      benign: 0,
    };
  }

  const result: ClinVarCounts = {
    pathogenic: 0,
    likely_pathogenic: 0,
    vus: 0,
    likely_benign: 0,
    benign: 0,
  };

  props.data.forEach((variant) => {
    const significance = variant.clinical_significance?.toLowerCase().replace(/_/g, ' ') || '';

    // Match classification (handle both underscore and space formats)
    if (significance.includes('pathogenic') && !significance.includes('likely')) {
      result.pathogenic++;
    } else if (significance.includes('likely') && significance.includes('pathogenic')) {
      result.likely_pathogenic++;
    } else if (significance.includes('uncertain') || significance.includes('vus')) {
      result.vus++;
    } else if (significance.includes('likely') && significance.includes('benign')) {
      result.likely_benign++;
    } else if (significance.includes('benign') && !significance.includes('likely')) {
      result.benign++;
    }
  });

  return result;
});

// Total variant count — prefers the precomputed `totalCount` prop; falls back
// to the derived count from the variant array.
const totalCount = computed(() => {
  if (props.counts) return props.totalCount ?? 0;
  return props.data?.length ?? 0;
});
</script>

<style scoped>
.clinvar-card {
  /* Match gene info card styling — no shadow, dark border */
}

/* Custom badge color for Likely Pathogenic (orange) */
.badge-lp {
  background-color: #fd7e14 !important;
  color: #fff !important;
}

/* Custom badge color for Likely Benign (light green/teal) */
.badge-lb {
  background-color: #20c997 !important;
  color: #fff !important;
}
</style>
