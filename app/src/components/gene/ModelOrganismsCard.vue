<template>
  <BCard
    v-if="showCard"
    class="model-organisms-card"
    body-class="p-0"
    header-class="p-1"
    border-variant="dark"
    role="region"
    aria-label="Model organism phenotypes"
  >
    <template #header>
      <div class="d-flex justify-content-between align-items-center">
        <span class="fw-semibold small">Model Organisms</span>
        <div class="d-flex gap-1">
          <!-- MGI external link -->
          <BButton
            v-if="mgiData?.mgi_url"
            variant="link"
            size="sm"
            :href="mgiData.mgi_url"
            target="_blank"
            rel="noopener noreferrer"
            class="text-decoration-none p-0"
            title="View on MGI"
            aria-label="View gene on MGI database (opens in new tab)"
          >
            <span class="badge bg-secondary me-1">MGI</span>
            <i class="bi bi-box-arrow-up-right"></i>
          </BButton>
          <!-- RGD external link -->
          <BButton
            v-if="rgdData?.rgd_url"
            variant="link"
            size="sm"
            :href="rgdData.rgd_url"
            target="_blank"
            rel="noopener noreferrer"
            class="text-decoration-none p-0"
            title="View on RGD"
            aria-label="View gene on RGD database (opens in new tab)"
          >
            <span class="badge bg-secondary me-1">RGD</span>
            <i class="bi bi-box-arrow-up-right"></i>
          </BButton>
        </div>
      </div>
    </template>

    <!-- Compact content layout -->
    <div class="px-2 py-2">
      <!-- Loading state -->
      <div v-if="mgiLoading && rgdLoading" class="text-center py-2">
        <BSpinner label="Loading phenotype data..." role="status" small />
      </div>

      <!-- Error state (both failed) -->
      <div v-else-if="mgiError && rgdError && !mgiData && !rgdData" class="text-center py-2" role="alert">
        <i class="bi bi-exclamation-triangle text-warning me-1"></i>
        <span class="text-muted small">Failed to load phenotype data</span>
        <BButton
          variant="link"
          size="sm"
          class="p-0 ms-2"
          @click="$emit('retry')"
        >
          Retry
        </BButton>
      </div>

      <!-- Data display -->
      <div v-else class="d-flex flex-wrap gap-3 align-items-start">
        <!-- Mouse (MGI) section -->
        <div class="organism-section">
          <div class="d-flex align-items-center gap-1 mb-1">
            <i class="bi bi-heart-pulse text-muted small"></i>
            <span class="text-muted small fw-semibold">Mouse</span>
            <BSpinner v-if="mgiLoading" small class="ms-1" />
          </div>

          <!-- MGI Error -->
          <span v-if="mgiError && !mgiData" class="text-muted small">
            <i class="bi bi-exclamation-circle"></i> Error
          </span>

          <!-- MGI No data -->
          <span v-else-if="!mgiData && !mgiLoading" class="text-muted small">
            No data
          </span>

          <!-- MGI Data -->
          <div v-else-if="mgiData" class="d-flex flex-wrap gap-1 align-items-center">
            <!-- Phenotype count with tooltip showing sample terms -->
            <span
              v-b-tooltip.hover="mgiTooltipContent"
              class="badge bg-primary cursor-help"
              :aria-label="`${mgiData.phenotype_count} mouse phenotypes from MGI`"
            >
              {{ mgiData.phenotype_count }} phenotype{{ mgiData.phenotype_count === 1 ? '' : 's' }}
            </span>

            <!-- Zygosity breakdown (compact) -->
            <span
              v-if="zygosityCounts.homozygous > 0"
              v-b-tooltip.hover="'Homozygous phenotypes'"
              class="badge bg-danger badge-sm cursor-help"
            >
              hm {{ zygosityCounts.homozygous }}
            </span>
            <span
              v-if="zygosityCounts.heterozygous > 0"
              v-b-tooltip.hover="'Heterozygous phenotypes'"
              class="badge badge-warning-custom badge-sm cursor-help"
            >
              ht {{ zygosityCounts.heterozygous }}
            </span>
            <span
              v-if="zygosityCounts.conditional > 0"
              v-b-tooltip.hover="'Conditional phenotypes'"
              class="badge bg-info badge-sm cursor-help"
            >
              cn {{ zygosityCounts.conditional }}
            </span>
          </div>
        </div>

        <!-- Divider -->
        <div class="vr d-none d-sm-block"></div>

        <!-- Rat (RGD) section -->
        <div class="organism-section">
          <div class="d-flex align-items-center gap-1 mb-1">
            <i class="bi bi-database text-muted small"></i>
            <span class="text-muted small fw-semibold">Rat</span>
            <BSpinner v-if="rgdLoading" small class="ms-1" />
          </div>

          <!-- RGD Error -->
          <span v-if="rgdError && !rgdData" class="text-muted small">
            <i class="bi bi-exclamation-circle"></i> Error
          </span>

          <!-- RGD No data -->
          <span v-else-if="!rgdData && !rgdLoading" class="text-muted small">
            No data
          </span>

          <!-- RGD Data -->
          <div v-else-if="rgdData" class="d-flex flex-wrap gap-1 align-items-center">
            <!-- Phenotype count with tooltip showing sample terms -->
            <span
              v-if="rgdData.phenotype_count > 0"
              v-b-tooltip.hover="rgdTooltipContent"
              class="badge bg-primary cursor-help"
              :aria-label="`${rgdData.phenotype_count} rat phenotypes from RGD`"
            >
              {{ rgdData.phenotype_count }} phenotype{{ rgdData.phenotype_count === 1 ? '' : 's' }}
            </span>
            <span v-else class="text-muted small">
              0 phenotypes
            </span>
          </div>
        </div>
      </div>
    </div>
  </BCard>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { BCard, BButton, BSpinner } from 'bootstrap-vue-next'
import type { MGIPhenotypeData, RGDPhenotypeData } from '@/types/external'

interface Props {
  geneSymbol: string
  mgiLoading: boolean
  mgiError: string | null
  mgiData: MGIPhenotypeData | null
  rgdLoading: boolean
  rgdError: string | null
  rgdData: RGDPhenotypeData | null
}

const props = defineProps<Props>()

defineEmits<{
  retry: []
}>()

/**
 * Show card if either source has data, error, or is loading
 */
const showCard = computed(() => {
  return (
    props.mgiData !== null ||
    props.mgiError !== null ||
    props.mgiLoading ||
    props.rgdData !== null ||
    props.rgdError !== null ||
    props.rgdLoading
  )
})

/**
 * Count phenotypes by zygosity from MGI data
 */
const zygosityCounts = computed(() => {
  const counts = { homozygous: 0, heterozygous: 0, conditional: 0 }
  if (!props.mgiData?.phenotypes) return counts

  props.mgiData.phenotypes.forEach(phenotype => {
    const zygosity = phenotype.zygosity?.toLowerCase()
    if (zygosity === 'homozygous') counts.homozygous++
    else if (zygosity === 'heterozygous') counts.heterozygous++
    else if (zygosity === 'conditional') counts.conditional++
  })
  return counts
})

/**
 * Generate tooltip content showing first few MGI phenotype terms
 */
const mgiTooltipContent = computed(() => {
  if (!props.mgiData?.phenotypes?.length) {
    return 'No phenotype details available'
  }

  const phenotypes = props.mgiData.phenotypes
  const maxShow = 5
  const terms = phenotypes
    .slice(0, maxShow)
    .map(p => `• ${p.term || 'Unknown'}`)
    .join('\n')

  const remaining = phenotypes.length - maxShow
  const suffix = remaining > 0 ? `\n...and ${remaining} more` : ''

  return `Sample phenotypes:\n${terms}${suffix}`
})

/**
 * Generate tooltip content showing RGD phenotype terms
 */
const rgdTooltipContent = computed(() => {
  if (!props.rgdData?.phenotypes?.length) {
    return 'No phenotype details available'
  }

  const phenotypes = props.rgdData.phenotypes
  const maxShow = 5
  const terms = phenotypes
    .slice(0, maxShow)
    .map(p => `• ${p.term || 'Unknown'}`)
    .join('\n')

  const remaining = phenotypes.length - maxShow
  const suffix = remaining > 0 ? `\n...and ${remaining} more` : ''

  return `Sample phenotypes:\n${terms}${suffix}`
})
</script>

<style scoped>
.model-organisms-card {
  /* Match gene info card styling */
}

.organism-section {
  min-width: 100px;
}

/* Smaller badges for zygosity */
.badge-sm {
  font-size: 0.7rem;
  padding: 0.2rem 0.4rem;
}

/* Custom badge color for heterozygous (yellow/warning) */
.badge-warning-custom {
  background-color: #ffc107 !important;
  color: #000 !important;
}

/* Cursor for tooltip elements */
.cursor-help {
  cursor: help;
}

/* Vertical rule styling */
.vr {
  opacity: 0.3;
  height: auto;
  align-self: stretch;
}
</style>
