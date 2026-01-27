<template>
  <BCard
    class="constraint-card shadow-sm"
    role="region"
    aria-label="Gene constraint scores from gnomAD"
  >
    <template #header>
      <div class="d-flex justify-content-between align-items-center">
        <h5 class="mb-0">Gene Constraint (gnomAD)</h5>
        <BButton
          variant="link"
          size="sm"
          :href="`https://gnomad.broadinstitute.org/gene/${geneSymbol}`"
          target="_blank"
          rel="noopener noreferrer"
          class="text-decoration-none"
        >
          <i class="bi bi-box-arrow-up-right"></i>
        </BButton>
      </div>
    </template>

    <!-- Loading State -->
    <div v-if="loading" class="text-center py-5">
      <BSpinner label="Loading constraint data..." role="status" />
    </div>

    <!-- Error State -->
    <div v-else-if="error" class="text-center py-4" role="alert">
      <p class="text-muted mb-3">{{ error }}</p>
      <BButton
        variant="outline-primary"
        size="sm"
        @click="$emit('retry')"
      >
        Retry
      </BButton>
    </div>

    <!-- No Data State -->
    <div v-else-if="!data" class="text-center py-4">
      <i class="bi bi-info-circle text-muted me-2"></i>
      <span class="text-muted">No constraint data available for this gene</span>
    </div>

    <!-- Constraint Table -->
    <BTable
      v-else
      :items="tableItems"
      :fields="tableFields"
      small
      striped
      hover
      class="mb-0"
    >
      <!-- Category Column - Bold Text -->
      <template #cell(category)="{ value }">
        <strong>{{ value }}</strong>
      </template>

      <!-- Metrics Column - Custom Render with SVG CI Bars -->
      <template #cell(metrics)="{ item }">
        <div class="metrics-cell">
          <div class="me-3">
            <span class="text-muted small">Z:</span> {{ formatNumber(item.z_score, 2) }}
          </div>
          <div class="me-3">
            <span class="text-muted small">o/e:</span> {{ formatNumber(item.oe, 2) }}
          </div>
          <div class="ci-bar-container">
            <svg
              width="100"
              height="12"
              role="img"
              :aria-label="getCIAriaLabel(item)"
            >
              <!-- Background rect (0-2 range) -->
              <rect x="0" y="0" width="100" height="12" fill="#e9ecef" rx="2" />

              <!-- CI bar -->
              <rect
                :x="scaleOE(item.oe_lower)"
                y="2"
                :width="Math.max(0, scaleOE(item.oe_upper) - scaleOE(item.oe_lower))"
                height="8"
                :fill="getOEColor(item.oe_upper, item.category)"
                rx="1"
              />

              <!-- Point estimate circle -->
              <circle
                :cx="scaleOE(item.oe)"
                cy="6"
                r="3"
                :fill="getOEColor(item.oe_upper, item.category)"
                stroke="white"
                stroke-width="1"
              />
            </svg>
            <span class="ms-2 small text-muted">
              ({{ formatNumber(item.oe_lower, 2) }} - {{ formatNumber(item.oe_upper, 2) }})
            </span>
          </div>

          <!-- pLI for pLoF row only -->
          <div v-if="item.category === 'pLoF' && item.pLI !== null" class="ms-3">
            <span class="text-muted small">pLI:</span> {{ formatNumber(item.pLI, 2) }}
          </div>
        </div>
      </template>
    </BTable>
  </BCard>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { BCard, BButton, BSpinner, BTable } from 'bootstrap-vue-next'
import type { GnomADConstraints } from '@/types/external'

interface Props {
  geneSymbol: string
  loading: boolean
  error: string | null
  data: GnomADConstraints | null
}

const props = defineProps<Props>()

defineEmits<{
  retry: []
}>()

// Table configuration
const tableFields = [
  { key: 'category', label: 'Category', thStyle: { width: '15%' } },
  { key: 'expected', label: 'Expected SNVs', thStyle: { width: '15%' } },
  { key: 'observed', label: 'Observed SNVs', thStyle: { width: '15%' } },
  { key: 'metrics', label: 'Constraint Metrics', thStyle: { width: '55%' } }
]

// Build table rows from constraint data
const tableItems = computed(() => {
  if (!props.data) return []

  return [
    {
      category: 'Synonymous',
      expected: formatNumber(props.data.exp_syn, 1),
      observed: formatNumber(props.data.obs_syn, 0),
      z_score: props.data.syn_z,
      oe: props.data.oe_syn,
      oe_lower: props.data.oe_syn_lower,
      oe_upper: props.data.oe_syn_upper,
      pLI: null
    },
    {
      category: 'Missense',
      expected: formatNumber(props.data.exp_mis, 1),
      observed: formatNumber(props.data.obs_mis, 0),
      z_score: props.data.mis_z,
      oe: props.data.oe_mis,
      oe_lower: props.data.oe_mis_lower,
      oe_upper: props.data.oe_mis_upper,
      pLI: null
    },
    {
      category: 'pLoF',
      expected: formatNumber(props.data.exp_lof, 1),
      observed: formatNumber(props.data.obs_lof, 0),
      z_score: props.data.lof_z,
      oe: props.data.oe_lof,
      oe_lower: props.data.oe_lof_lower,
      oe_upper: props.data.oe_lof_upper,
      pLI: props.data.pLI
    }
  ]
})

// Helper: Map 0-2 o/e range to 0-100px SVG coordinate
function scaleOE(value: number | null): number {
  if (value === null) return 0
  // Map 0-2 range to 0-100px, clamped
  const scaled = value * 50
  return Math.max(0, Math.min(100, scaled))
}

// Helper: Get CI bar color (amber for pLoF with LOEUF < 0.6, gray otherwise)
function getOEColor(oe_upper: number | null, category: string): string {
  if (category === 'pLoF' && oe_upper !== null && oe_upper < 0.6) {
    return '#ffc107' // Amber for highly constrained pLoF
  }
  return '#6c757d' // Gray default
}

// Helper: Format number with specified decimals
function formatNumber(value: number | null, decimals: number): string {
  if (value === null || value === undefined) return 'N/A'
  return value.toFixed(decimals)
}

// Helper: Generate ARIA label for CI bar (screen reader accessibility)
function getCIAriaLabel(item: any): string {
  if (item.oe === null || item.oe_lower === null || item.oe_upper === null) {
    return `${item.category} constraint: data unavailable`
  }
  return `${item.category} observed/expected ratio: ${formatNumber(item.oe, 2)}, confidence interval ${formatNumber(item.oe_lower, 2)} to ${formatNumber(item.oe_upper, 2)}`
}
</script>

<style scoped>
.constraint-card {
  min-height: 300px;
  border: none;
}

.metrics-cell {
  display: flex;
  align-items: center;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.ci-bar-container {
  display: inline-flex;
  align-items: center;
}
</style>
