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

      <!-- Data display - two column layout with centered divider -->
      <div v-else class="organism-grid">
        <!-- Mouse (MGI) section - LEFT -->
        <div class="organism-section organism-left">
          <div class="d-flex align-items-center gap-1 mb-1">
            <img
              :src="mouseIcon"
              alt="Mouse silhouette"
              class="phylopic-icon text-muted"
            />
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
            <!-- Phenotype count badge - clickable to show popover -->
            <span
              :id="mgiPopoverId"
              class="badge bg-primary phenotype-badge"
              :class="{ 'phenotype-badge-clickable': mgiData.phenotype_count > 0 }"
              :aria-label="`${mgiData.phenotype_count} mouse phenotypes from MGI. ${mgiData.phenotype_count > 0 ? 'Click to see all.' : ''}`"
              role="button"
              tabindex="0"
              @click="mgiData.phenotype_count > 0 && toggleMgiPopover()"
              @keydown.enter="mgiData.phenotype_count > 0 && toggleMgiPopover()"
            >
              {{ mgiData.phenotype_count }} phenotype{{ mgiData.phenotype_count === 1 ? '' : 's' }}
              <i v-if="mgiData.phenotype_count > 0" class="bi bi-chevron-down ms-1 small"></i>
            </span>

            <!-- MGI Phenotype Popover -->
            <BPopover
              v-if="mgiData.phenotype_count > 0"
              :target="mgiPopoverId"
              :model-value="showMgiPopover"
              placement="bottom"
              triggers="manual"
              class="phenotype-popover"
              @update:model-value="showMgiPopover = $event"
            >
              <template #title>
                <div class="d-flex justify-content-between align-items-center">
                  <span>Mouse Phenotypes ({{ mgiData.phenotype_count }})</span>
                  <button
                    type="button"
                    class="btn-close btn-close-sm"
                    aria-label="Close"
                    @click="showMgiPopover = false"
                  ></button>
                </div>
              </template>
              <div class="phenotype-list">
                <div
                  v-for="(phenotype, index) in mgiData.phenotypes"
                  :key="index"
                  class="phenotype-item"
                >
                  <span class="phenotype-term">{{ phenotype.term || 'Unknown' }}</span>
                  <span
                    v-if="phenotype.zygosity"
                    class="badge badge-zygosity ms-1"
                    :class="getZygosityClass(phenotype.zygosity)"
                  >
                    {{ getZygosityLabel(phenotype.zygosity) }}
                  </span>
                </div>
              </div>
            </BPopover>

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


        <!-- Rat (RGD) section - RIGHT -->
        <div class="organism-section organism-right">
          <div class="d-flex align-items-center gap-1 mb-1">
            <img
              :src="ratIcon"
              alt="Rat silhouette"
              class="phylopic-icon text-muted"
            />
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
            <!-- Phenotype count badge - clickable to show popover -->
            <span
              v-if="rgdData.phenotype_count > 0"
              :id="rgdPopoverId"
              class="badge bg-primary phenotype-badge phenotype-badge-clickable"
              :aria-label="`${rgdData.phenotype_count} rat phenotypes from RGD. Click to see all.`"
              role="button"
              tabindex="0"
              @click="toggleRgdPopover()"
              @keydown.enter="toggleRgdPopover()"
            >
              {{ rgdData.phenotype_count }} phenotype{{ rgdData.phenotype_count === 1 ? '' : 's' }}
              <i class="bi bi-chevron-down ms-1 small"></i>
            </span>
            <span v-else class="text-muted small">
              0 phenotypes
            </span>

            <!-- RGD Phenotype Popover -->
            <BPopover
              v-if="rgdData.phenotype_count > 0"
              :target="rgdPopoverId"
              :model-value="showRgdPopover"
              placement="bottom"
              triggers="manual"
              class="phenotype-popover"
              @update:model-value="showRgdPopover = $event"
            >
              <template #title>
                <div class="d-flex justify-content-between align-items-center">
                  <span>Rat Phenotypes ({{ rgdData.phenotype_count }})</span>
                  <button
                    type="button"
                    class="btn-close btn-close-sm"
                    aria-label="Close"
                    @click="showRgdPopover = false"
                  ></button>
                </div>
              </template>
              <div class="phenotype-list">
                <div
                  v-for="(phenotype, index) in rgdData.phenotypes"
                  :key="index"
                  class="phenotype-item"
                >
                  <span class="phenotype-term">{{ phenotype.term || 'Unknown' }}</span>
                </div>
              </div>
            </BPopover>
          </div>
        </div>
      </div>
    </div>
  </BCard>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue'
import { BCard, BButton, BSpinner, BPopover } from 'bootstrap-vue-next'
import type { MGIPhenotypeData, RGDPhenotypeData } from '@/types/external'

// PhyloPic silhouette icons (CC0 licensed)
import mouseIcon from '@/assets/icons/phylopic/mus-musculus.svg'
import ratIcon from '@/assets/icons/phylopic/rattus.svg'

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

// Popover state
const showMgiPopover = ref(false)
const showRgdPopover = ref(false)

// Unique IDs for popover targets
const mgiPopoverId = computed(() => `mgi-phenotypes-${props.geneSymbol}`)
const rgdPopoverId = computed(() => `rgd-phenotypes-${props.geneSymbol}`)

/**
 * Toggle MGI popover visibility
 */
function toggleMgiPopover() {
  showMgiPopover.value = !showMgiPopover.value
  // Close other popover
  if (showMgiPopover.value) {
    showRgdPopover.value = false
  }
}

/**
 * Toggle RGD popover visibility
 */
function toggleRgdPopover() {
  showRgdPopover.value = !showRgdPopover.value
  // Close other popover
  if (showRgdPopover.value) {
    showMgiPopover.value = false
  }
}

/**
 * Get CSS class for zygosity badge
 */
function getZygosityClass(zygosity: string | undefined): string {
  const z = zygosity?.toLowerCase()
  if (z === 'homozygous') return 'bg-danger'
  if (z === 'heterozygous') return 'badge-warning-custom'
  if (z === 'conditional') return 'bg-info'
  return 'bg-secondary'
}

/**
 * Get abbreviated label for zygosity
 */
function getZygosityLabel(zygosity: string | undefined): string {
  const z = zygosity?.toLowerCase()
  if (z === 'homozygous') return 'hm'
  if (z === 'heterozygous') return 'ht'
  if (z === 'conditional') return 'cn'
  return z || ''
}

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
</script>

<style scoped>
.model-organisms-card {
  /* Match gene info card styling */
}

/* PhyloPic silhouette icons */
.phylopic-icon {
  width: 24px;
  height: 24px;
  opacity: 0.7;
  /* Make black silhouettes appear muted/gray */
  filter: invert(40%) sepia(0%) saturate(0%) hue-rotate(0deg) brightness(90%) contrast(100%);
}

/* Grid layout for two-column with centered divider */
.organism-grid {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 1rem;
  align-items: start;
}

/* On mobile, stack vertically */
@media (max-width: 575.98px) {
  .organism-grid {
    grid-template-columns: 1fr;
    gap: 0.75rem;
  }

  .organism-left {
    border-right: none !important;
    padding-right: 0 !important;
    border-bottom: 1px solid #dee2e6;
    padding-bottom: 0.5rem;
  }
}

.organism-section {
  min-width: 100px;
}

/* Left section aligns content to the right (towards center) */
.organism-left {
  text-align: right;
  border-right: 1px solid #dee2e6;
  padding-right: 1rem;
}

.organism-left .d-flex {
  justify-content: flex-end;
}

/* Right section aligns content to the left (towards center) */
.organism-right {
  text-align: left;
}

.organism-right .d-flex {
  justify-content: flex-start;
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

/* Clickable phenotype badge */
.phenotype-badge {
  transition: all 0.2s ease;
}

.phenotype-badge-clickable {
  cursor: pointer;
}

.phenotype-badge-clickable:hover {
  filter: brightness(1.1);
  transform: translateY(-1px);
}

.phenotype-badge-clickable:active {
  transform: translateY(0);
}


/* Phenotype list in popover */
.phenotype-list {
  max-height: 300px;
  overflow-y: auto;
  font-size: 0.85rem;
}

.phenotype-item {
  padding: 0.35rem 0;
  border-bottom: 1px solid #eee;
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.5rem;
}

.phenotype-item:last-child {
  border-bottom: none;
}

.phenotype-term {
  flex: 1;
  word-break: break-word;
}

/* Zygosity badge in list */
.badge-zygosity {
  font-size: 0.65rem;
  padding: 0.15rem 0.3rem;
  flex-shrink: 0;
}

/* Close button size adjustment */
.btn-close-sm {
  width: 0.75rem;
  height: 0.75rem;
  padding: 0.25rem;
  background-size: 0.75rem;
}
</style>

<style>
/* Global styles for popover (not scoped) */
.phenotype-popover .popover-body {
  padding: 0.5rem;
  min-width: 250px;
  max-width: 350px;
}

.phenotype-popover .popover-header {
  padding: 0.5rem 0.75rem;
  font-size: 0.9rem;
  background-color: #f8f9fa;
}
</style>
