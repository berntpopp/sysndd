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
      <span class="fw-semibold small">Model Organisms</span>
    </template>

    <!-- Two-column layout: Mouse (MGI) left, Rat (RGD) right -->
    <BRow class="g-0">
      <!-- Mouse (MGI) column -->
      <BCol cols="12" md="6" class="border-end-md">
        <div class="p-3">
          <!-- Section header -->
          <h6 class="small mb-2">
            <i class="bi bi-heart-pulse me-1"></i>
            <span>Mouse (MGI)</span>
          </h6>

          <!-- Loading state -->
          <div v-if="mgiLoading" class="text-center py-2">
            <BSpinner label="Loading mouse data..." role="status" small />
          </div>

          <!-- Error state -->
          <div v-else-if="mgiError" class="text-center py-2" role="alert">
            <i class="bi bi-exclamation-triangle text-warning me-1"></i>
            <p class="text-muted mb-2 small">{{ mgiError }}</p>
            <BButton
              variant="outline-primary"
              size="sm"
              @click="$emit('retry')"
            >
              Retry
            </BButton>
          </div>

          <!-- Empty state -->
          <div v-else-if="!mgiData" class="text-center py-2">
            <i class="bi bi-info-circle text-muted me-2"></i>
            <span class="text-muted small">No mouse phenotype data</span>
          </div>

          <!-- Data state -->
          <div v-else>
            <!-- Total count badge -->
            <div class="mb-2">
              <BBadge
                variant="primary"
                class="py-2 px-3"
                :aria-label="`${mgiData.phenotype_count} total phenotypes from MGI`"
              >
                <strong>{{ mgiData.phenotype_count }}</strong> phenotype{{ mgiData.phenotype_count === 1 ? '' : 's' }}
              </BBadge>
            </div>

            <!-- Zygosity breakdown badges (if any phenotypes have zygosity) -->
            <div v-if="hasZygosityData" class="d-flex flex-wrap gap-2 mb-3">
              <BBadge
                v-if="zygosityCounts.homozygous > 0"
                variant="danger"
                class="py-1 px-2"
                :aria-label="`${zygosityCounts.homozygous} homozygous phenotypes`"
              >
                hm ({{ zygosityCounts.homozygous }})
              </BBadge>

              <BBadge
                v-if="zygosityCounts.heterozygous > 0"
                class="badge-warning-custom py-1 px-2"
                :aria-label="`${zygosityCounts.heterozygous} heterozygous phenotypes`"
              >
                ht ({{ zygosityCounts.heterozygous }})
              </BBadge>

              <BBadge
                v-if="zygosityCounts.conditional > 0"
                variant="info"
                class="py-1 px-2"
                :aria-label="`${zygosityCounts.conditional} conditional phenotypes`"
              >
                cn ({{ zygosityCounts.conditional }})
              </BBadge>
            </div>

            <!-- External link to MGI database -->
            <BButton
              variant="outline-secondary"
              size="sm"
              :href="mgiData.mgi_url"
              target="_blank"
              rel="noopener noreferrer"
              aria-label="View gene on MGI database (opens in new tab)"
            >
              <i class="bi bi-box-arrow-up-right me-1"></i>
              View on MGI
            </BButton>
          </div>
        </div>
      </BCol>

      <!-- Rat (RGD) column -->
      <BCol cols="12" md="6">
        <div class="p-3">
          <!-- Section header -->
          <h6 class="small mb-2">
            <i class="bi bi-database me-1"></i>
            <span>Rat (RGD)</span>
          </h6>

          <!-- Loading state -->
          <div v-if="rgdLoading" class="text-center py-2">
            <BSpinner label="Loading rat data..." role="status" small />
          </div>

          <!-- Error state -->
          <div v-else-if="rgdError" class="text-center py-2" role="alert">
            <i class="bi bi-exclamation-triangle text-warning me-1"></i>
            <p class="text-muted mb-2 small">{{ rgdError }}</p>
            <BButton
              variant="outline-primary"
              size="sm"
              @click="$emit('retry')"
            >
              Retry
            </BButton>
          </div>

          <!-- Empty state -->
          <div v-else-if="!rgdData" class="text-center py-2">
            <i class="bi bi-info-circle text-muted me-2"></i>
            <span class="text-muted small">No rat phenotype data</span>
          </div>

          <!-- Data state -->
          <div v-else>
            <!-- Total count badge -->
            <div class="mb-3">
              <BBadge
                variant="primary"
                class="py-2 px-3"
                :aria-label="`${rgdData.phenotype_count} total phenotypes from RGD`"
              >
                <strong>{{ rgdData.phenotype_count }}</strong> phenotype{{ rgdData.phenotype_count === 1 ? '' : 's' }}
              </BBadge>
            </div>

            <!-- External link to RGD database -->
            <BButton
              variant="outline-secondary"
              size="sm"
              :href="rgdData.rgd_url"
              target="_blank"
              rel="noopener noreferrer"
              aria-label="View gene on RGD database (opens in new tab)"
            >
              <i class="bi bi-box-arrow-up-right me-1"></i>
              View on RGD
            </BButton>
          </div>
        </div>
      </BCol>
    </BRow>
  </BCard>
</template>

<script setup lang="ts">
import { computed } from 'vue'
import { BCard, BRow, BCol, BButton, BSpinner, BBadge } from 'bootstrap-vue-next'
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
 * Hide card only when both sources have no data AND no error AND not loading
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
 * Handles missing/undefined zygosity gracefully
 */
const zygosityCounts = computed(() => {
  const counts = {
    homozygous: 0,
    heterozygous: 0,
    conditional: 0,
  }

  if (!props.mgiData || !props.mgiData.phenotypes) {
    return counts
  }

  props.mgiData.phenotypes.forEach(phenotype => {
    const zygosity = phenotype.zygosity?.toLowerCase()
    if (zygosity === 'homozygous') {
      counts.homozygous++
    } else if (zygosity === 'heterozygous') {
      counts.heterozygous++
    } else if (zygosity === 'conditional') {
      counts.conditional++
    }
  })

  return counts
})

/**
 * Check if any phenotypes have zygosity data
 * Don't show zygosity badges if all phenotypes lack zygosity info
 */
const hasZygosityData = computed(() => {
  return (
    zygosityCounts.value.homozygous > 0 ||
    zygosityCounts.value.heterozygous > 0 ||
    zygosityCounts.value.conditional > 0
  )
})
</script>

<style scoped>
.model-organisms-card {
  /* Match gene info card styling — no shadow, dark border */
}

/* Custom badge color for heterozygous (yellow/warning) */
.badge-warning-custom {
  background-color: #ffc107 !important;
  color: #000 !important;
}

/* Border between columns on medium+ screens */
@media (min-width: 768px) {
  .border-end-md {
    border-right: 1px solid #dee2e6;
  }
}

/* Section headers */
h6 {
  font-weight: 600;
  color: #495057;
}
</style>
