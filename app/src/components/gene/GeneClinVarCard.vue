<template>
  <BCard
    class="clinvar-card border-subtle"
    body-class="p-0"
    header-class="p-1"
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
    <div v-else-if="totalCount === 0" class="clinvar-empty-state text-center py-3">
      <i class="bi bi-info-circle text-muted me-2" aria-hidden="true"></i>
      <span class="text-muted small">No ClinVar variants returned for this gene.</span>
    </div>

    <!-- Dense ACMG chip row -->
    <div v-else class="clinvar-chip-panel px-2 py-2">
      <div class="clinvar-chip-row" aria-label="ClinVar pathogenicity summary">
        <BButton
          v-for="chip in visibleChips"
          :id="chip.id"
          :key="chip.key"
          type="button"
          size="sm"
          class="clinvar-chip"
          :class="chip.className"
          :aria-label="`${chip.shortLabel} ${chip.count} ${chip.label} variants`"
          @click="toggleChip(chip.key)"
          @keydown.enter.space.prevent="toggleChip(chip.key)"
        >
          <span class="clinvar-chip__text">{{ chip.shortLabel }} {{ chip.count }}</span>
        </BButton>

        <BPopover
          v-for="chip in visibleChips"
          :key="`${chip.key}-popover`"
          :target="chip.id"
          :model-value="openChip === chip.key"
          placement="bottom"
          triggers="manual"
          class="clinvar-breakdown-popover"
          @update:model-value="openChip = $event ? chip.key : null"
        >
          <template #title>
            <div class="d-flex align-items-center justify-content-between gap-2">
              <span>{{ chip.label }} ({{ chip.count }})</span>
              <button
                type="button"
                class="btn-close btn-close-sm"
                aria-label="Close"
                @click="openChip = null"
              ></button>
            </div>
          </template>

          <div v-if="chip.consequences.length > 0" class="clinvar-breakdown">
            <div
              v-for="item in chip.consequences"
              :key="`${chip.key}-${item.key}`"
              class="clinvar-breakdown__row"
            >
              <span>{{ item.label }}</span>
              <span class="clinvar-breakdown__value">
                {{ item.count }}
                <span class="text-muted">({{ formatPercent(item.count, chip.count) }})</span>
              </span>
            </div>
          </div>
          <p v-else class="text-muted small mb-0">No consequence breakdown available.</p>
        </BPopover>
      </div>
    </div>
  </BCard>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { BCard, BButton, BSpinner, BPopover } from 'bootstrap-vue-next';
import type { ClinVarVariant } from '@/types/external';
import type {
  ClinVarClassBreakdown,
  ClinVarConsequenceCount,
} from '@/composables/useGeneClinVarCounts';

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
  classBreakdowns?: Partial<Record<keyof ClinVarCounts, ClinVarClassBreakdown>> | null;
  consequenceCounts?: ClinVarConsequenceCount[] | null;
  totalCount?: number;
}

const props = withDefaults(defineProps<Props>(), {
  data: null,
  counts: null,
  classBreakdowns: null,
  consequenceCounts: null,
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

const openChip = ref<keyof ClinVarCounts | null>(null);

const chipMeta: Array<{
  key: keyof ClinVarCounts;
  label: string;
  shortLabel: string;
  className: string;
}> = [
  { key: 'pathogenic', label: 'Pathogenic', shortLabel: 'P', className: 'clinvar-chip--p' },
  {
    key: 'likely_pathogenic',
    label: 'Likely pathogenic',
    shortLabel: 'LP',
    className: 'clinvar-chip--lp',
  },
  { key: 'vus', label: 'VUS', shortLabel: 'VUS', className: 'clinvar-chip--vus' },
  {
    key: 'likely_benign',
    label: 'Likely benign',
    shortLabel: 'LB',
    className: 'clinvar-chip--lb',
  },
  { key: 'benign', label: 'Benign', shortLabel: 'B', className: 'clinvar-chip--b' },
];

const visibleChips = computed(() =>
  chipMeta
    .map((meta) => {
      const breakdown = props.classBreakdowns?.[meta.key];
      return {
        ...meta,
        id: `clinvar-chip-${props.geneSymbol}-${meta.key}`,
        label: breakdown?.label ?? meta.label,
        shortLabel: breakdown?.short_label ?? meta.shortLabel,
        count: breakdown?.count ?? counts.value[meta.key],
        consequences: breakdown?.consequences ?? [],
      };
    })
    .filter((chip) => chip.count > 0)
);

function toggleChip(key: keyof ClinVarCounts): void {
  openChip.value = openChip.value === key ? null : key;
}

function formatPercent(count: number, total: number): string {
  if (total <= 0) return '0%';
  return `${Math.round((count / total) * 100)}%`;
}
</script>

<style scoped>
.clinvar-card {
  /* Match gene info card styling — no shadow, dark border */
}

.clinvar-empty-state {
  background-color: #f8f9fa;
  border-top: 1px dashed #adb5bd;
}

.clinvar-chip-panel {
  min-height: 3.25rem;
}

.clinvar-chip-row {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem;
  align-items: center;
}

.clinvar-chip {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  min-height: 1.65rem;
  padding: 0.2rem 0.45rem;
  border: 1px solid transparent;
  border-radius: 0.25rem;
  font-size: 0.78rem;
  font-weight: 700;
  line-height: 1;
}

.clinvar-chip:focus-visible {
  outline: 2px solid #0d6efd;
  outline-offset: 2px;
}

.clinvar-chip__text {
  letter-spacing: 0;
  font-variant-numeric: tabular-nums;
}

.clinvar-chip--p {
  background: #b42318;
  color: #fff;
}

.clinvar-chip--lp {
  background: #f97316;
  color: #111827;
}

.clinvar-chip--vus {
  background: #ffc107;
  color: #212529;
}

.clinvar-chip--lb {
  background: #20c997;
  color: #102a1d;
}

.clinvar-chip--b {
  background: #198754;
  color: #fff;
}

.clinvar-breakdown {
  min-width: 12rem;
}

.clinvar-breakdown__row {
  display: flex;
  align-items: baseline;
  justify-content: space-between;
  gap: 1rem;
  padding: 0.2rem 0;
  font-size: 0.85rem;
  border-bottom: 1px solid #edf0f2;
}

.clinvar-breakdown__row:last-child {
  border-bottom: 0;
}

.clinvar-breakdown__value {
  font-weight: 700;
  font-variant-numeric: tabular-nums;
  white-space: nowrap;
}

.btn-close-sm {
  width: 0.75rem;
  height: 0.75rem;
  padding: 0.25rem;
  background-size: 0.75rem;
}
</style>
