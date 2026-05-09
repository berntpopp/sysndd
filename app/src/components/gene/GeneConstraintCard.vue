<template>
  <BCard
    class="constraint-card constraint-card--compact"
    body-class="p-0"
    header-class="p-1"
    border-variant="dark"
    role="region"
    aria-label="Gene constraint scores from gnomAD"
  >
    <template #header>
      <div class="d-flex justify-content-between align-items-center">
        <span class="fw-semibold small">Gene Constraint (gnomAD)</span>
        <a
          :href="`https://gnomad.broadinstitute.org/gene/${geneSymbol}`"
          target="_blank"
          rel="noopener noreferrer"
          class="btn btn-link btn-sm text-decoration-none p-0"
          title="View on gnomAD"
          aria-label="View gene on gnomAD (opens in new tab)"
        >
          <i class="bi bi-box-arrow-up-right" aria-hidden="true"></i>
        </a>
      </div>
    </template>

    <div v-if="!constraintData" class="constraint-empty-state">
      <i class="bi bi-info-circle" aria-hidden="true"></i>
      <span>No gnomAD constraint data available for this gene.</span>
    </div>

    <div v-else class="constraint-matrix" role="table" aria-label="gnomAD constraint metric matrix">
      <div class="constraint-matrix-header" role="row">
        <span class="constraint-label" role="columnheader">Class</span>
        <span class="constraint-label" role="columnheader">Exp / Obs</span>
        <span class="constraint-label" role="columnheader">Z</span>
        <span class="constraint-label" role="columnheader">o/e (90% CI)</span>
        <span class="constraint-label" role="columnheader">pLI</span>
      </div>

      <div v-for="item in tableItems" :key="item.category" class="constraint-matrix-row" role="row">
        <div class="constraint-class-cell" role="cell">
          <span class="constraint-class-name">{{ item.category }}</span>
        </div>

        <div class="constraint-pair-cell" role="cell">
          <span class="constraint-value">{{ item.expected }}</span>
          <span class="constraint-separator" aria-hidden="true">/</span>
          <span class="constraint-value">{{ item.observed }}</span>
        </div>

        <div class="constraint-value-cell" role="cell">
          <span class="constraint-value">{{ formatNumber(item.z_score, 2) }}</span>
        </div>

        <div class="constraint-oe-cell" role="cell">
          <span class="constraint-value">{{ formatNumber(item.oe, 2) }}</span>
          <span class="ci-bar-container">
            <svg
              viewBox="0 0 100 12"
              preserveAspectRatio="none"
              role="img"
              :aria-label="getCIAriaLabel(item)"
            >
              <rect aria-hidden="true" x="0" y="0" width="100" height="12" fill="#dee2e6" rx="2" />
              <rect
                v-if="hasCIData(item)"
                aria-hidden="true"
                :x="scaleOE(item.oe_lower)"
                y="2"
                :width="getCIWidth(item)"
                height="8"
                :fill="getOEColor(item.oe_upper, item.category)"
                rx="1"
              />
              <circle
                v-if="hasCIData(item)"
                aria-hidden="true"
                :cx="scaleOE(item.oe)"
                cy="6"
                r="3"
                :fill="getOEColor(item.oe_upper, item.category)"
                stroke="white"
                stroke-width="1"
              />
            </svg>
          </span>
          <span class="ci-range">
            ({{ formatNumber(item.oe_lower, 2) }} - {{ formatNumber(item.oe_upper, 2) }})
          </span>
        </div>

        <div class="constraint-value-cell" role="cell">
          <span class="constraint-value">
            {{ item.category === 'pLoF' ? formatNumber(item.pLI, 2) : '—' }}
          </span>
        </div>
      </div>
    </div>
  </BCard>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { BCard } from 'bootstrap-vue-next';
import type { GnomADConstraints } from '@/types/external';

interface Props {
  geneSymbol: string;
  /** JSON string from gene endpoint (gnomad_constraints column) or null */
  constraintsJson: string | null;
}

/** Type for constraint table row items */
interface ConstraintTableItem {
  category: string;
  expected: string;
  observed: string;
  z_score: number | null | undefined;
  oe: number | null | undefined;
  oe_lower: number | null | undefined;
  oe_upper: number | null | undefined;
  pLI: number | null | undefined;
}

const props = defineProps<Props>();

/**
 * Parse the JSON string from the database into typed constraint data.
 * Returns null if the string is empty, null, or invalid JSON.
 */
const constraintData = computed<GnomADConstraints | null>(() => {
  if (!props.constraintsJson || props.constraintsJson === 'null') {
    return null;
  }

  try {
    return JSON.parse(props.constraintsJson) as GnomADConstraints;
  } catch {
    return null;
  }
});

// Build table rows from constraint data
const tableItems = computed(() => {
  if (!constraintData.value) return [];

  return [
    {
      category: 'Synonymous',
      expected: formatNumber(constraintData.value.exp_syn, 1),
      observed: formatNumber(constraintData.value.obs_syn, 0),
      z_score: constraintData.value.syn_z,
      oe: constraintData.value.oe_syn,
      oe_lower: constraintData.value.oe_syn_lower,
      oe_upper: constraintData.value.oe_syn_upper,
      pLI: null,
    },
    {
      category: 'Missense',
      expected: formatNumber(constraintData.value.exp_mis, 1),
      observed: formatNumber(constraintData.value.obs_mis, 0),
      z_score: constraintData.value.mis_z,
      oe: constraintData.value.oe_mis,
      oe_lower: constraintData.value.oe_mis_lower,
      oe_upper: constraintData.value.oe_mis_upper,
      pLI: null,
    },
    {
      category: 'pLoF',
      expected: formatNumber(constraintData.value.exp_lof, 1),
      observed: formatNumber(constraintData.value.obs_lof, 0),
      z_score: constraintData.value.lof_z,
      oe: constraintData.value.oe_lof,
      oe_lower: constraintData.value.oe_lof_lower,
      oe_upper: constraintData.value.oe_lof_upper,
      pLI: constraintData.value.pLI,
    },
  ];
});

// Helper: Map 0-2 o/e range to 0-100px SVG coordinate
function scaleOE(value: number | null | undefined): number {
  if (value === null || value === undefined || !Number.isFinite(value)) return 0;
  const scaled = value * 50;
  return Math.max(0, Math.min(100, scaled));
}

// Helper: Get CI width in the same 0-100 SVG coordinate system.
function getCIWidth(item: ConstraintTableItem): number {
  return Math.max(0, scaleOE(item.oe_upper) - scaleOE(item.oe_lower));
}

// Helper: CI glyphs should only render for real finite o/e values.
function hasCIData(item: ConstraintTableItem): boolean {
  return [item.oe, item.oe_lower, item.oe_upper].every(
    (value) => typeof value === 'number' && Number.isFinite(value)
  );
}

// Helper: Get CI bar color (amber for pLoF with LOEUF < 0.6, gray otherwise)
function getOEColor(oe_upper: number | null | undefined, category: string): string {
  if (category === 'pLoF' && typeof oe_upper === 'number' && oe_upper < 0.6) {
    return '#ffc107'; // Amber for highly constrained pLoF
  }
  return '#6c757d'; // Gray default
}

// Helper: Format number with specified decimals
function formatNumber(value: number | null | undefined, decimals: number): string {
  if (value === null || value === undefined || !Number.isFinite(value)) return 'N/A';
  return value.toFixed(decimals);
}

// Helper: Generate ARIA label for CI bar (screen reader accessibility)
function getCIAriaLabel(item: ConstraintTableItem): string {
  if (!hasCIData(item)) {
    return `${item.category} constraint: data unavailable`;
  }
  return `${item.category} observed/expected ratio: ${formatNumber(item.oe, 2)}, confidence interval ${formatNumber(item.oe_lower, 2)} to ${formatNumber(item.oe_upper, 2)}`;
}
</script>

<style scoped>
.constraint-card {
  min-height: 0;
}

.constraint-empty-state {
  min-height: 4.5rem;
  display: flex;
  flex-direction: row;
  align-items: center;
  justify-content: center;
  gap: 0.4rem;
  padding: 0.8rem;
  text-align: center;
  color: #343a40;
  background: #f8f9fa;
  border-top: 1px dashed #adb5bd;
}

.constraint-matrix {
  display: grid;
  gap: 0.08rem;
  padding: 0.32rem 0.55rem 0.35rem;
  color: #212529;
}

.constraint-matrix-header,
.constraint-matrix-row {
  display: grid;
  grid-template-columns:
    minmax(4.9rem, 1.05fr) minmax(4.7rem, 0.9fr) minmax(2.25rem, 0.45fr)
    minmax(6.8rem, 1.35fr) minmax(2.15rem, 0.4fr);
  align-items: center;
  gap: 0.35rem;
  min-width: 0;
}

.constraint-matrix-header {
  padding-bottom: 0.12rem;
  border-bottom: 1px solid #ced4da;
  font-size: 0.6rem;
  font-weight: 700;
  letter-spacing: 0;
  line-height: 1.1;
  text-transform: uppercase;
}

.constraint-matrix-row {
  min-height: 1.25rem;
  padding: 0.08rem 0;
  border-bottom: 1px solid #eef1f3;
  line-height: 1;
}

.constraint-matrix-row:last-child {
  border-bottom: 0;
}

.constraint-label {
  color: #343a40;
}

.constraint-class-name,
.constraint-value {
  color: #212529;
  font-weight: 600;
  line-height: 1.15;
}

.constraint-class-name {
  font-size: 0.72rem;
}

.constraint-value {
  font-size: 0.72rem;
}

.constraint-pair-cell,
.constraint-value-cell,
.constraint-class-cell,
.constraint-oe-cell {
  min-width: 0;
  line-height: 1;
}

.constraint-pair-cell {
  display: inline-flex;
  align-items: baseline;
  gap: 0.18rem;
  line-height: 1;
  white-space: nowrap;
}

.constraint-separator,
.ci-range {
  color: #343a40;
  font-size: 0.6rem;
  line-height: 1;
}

.constraint-oe-cell {
  display: grid;
  grid-template-columns: auto minmax(2.4rem, 1fr) auto;
  align-items: center;
  gap: 0.25rem;
  line-height: 1;
}

.ci-bar-container {
  display: block;
  min-width: 0;
}

.ci-bar-container svg {
  width: 100%;
  height: 0.38rem;
  vertical-align: middle;
}

.ci-range {
  white-space: nowrap;
}

@media (max-width: 575.98px) {
  .constraint-matrix {
    padding-inline: 0.45rem;
  }

  .constraint-matrix-header,
  .constraint-matrix-row {
    grid-template-columns:
      minmax(4.2rem, 1fr) minmax(4.2rem, 0.95fr) minmax(2rem, 0.45fr) minmax(4.4rem, 1fr)
      minmax(2rem, 0.42fr);
    gap: 0.22rem;
  }

  .constraint-matrix-header {
    font-size: 0.56rem;
  }

  .constraint-class-name,
  .constraint-value {
    font-size: 0.68rem;
  }

  .constraint-oe-cell {
    grid-template-columns: auto minmax(2rem, 1fr);
  }

  .ci-range {
    display: none;
  }
}
</style>
