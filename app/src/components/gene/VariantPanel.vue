<template>
  <div class="variant-panel" role="region" aria-label="ClinVar variant selection panel">
    <!-- Panel Header -->
    <div class="panel-header">
      <span class="fw-semibold small"
        >Variants ({{ filteredVariants.length }}/{{ mappableVariants.length }})</span
      >
      <BButton
        v-if="selectedResidues.size > 0"
        variant="link"
        size="sm"
        class="text-decoration-none p-0"
        aria-label="Clear all highlighted variants"
        @click="clearAll"
      >
        Clear all
      </BButton>
    </div>

    <!-- Search Input -->
    <div class="search-box">
      <input
        v-model="searchQuery"
        type="text"
        class="form-control form-control-sm"
        placeholder="Search variants..."
        aria-label="Search variants by notation"
      />
    </div>

    <!-- ACMG Filter Row -->
    <div class="filter-row d-flex flex-wrap justify-content-center align-items-center gap-1">
      <span v-for="item in legendItems" :key="item.key" class="filter-group">
        <button
          type="button"
          class="filter-chip"
          :class="{ 'filter-chip--hidden': !item.visible }"
          :aria-label="`Toggle ${item.label} variants`"
          :aria-pressed="item.visible"
          @click="toggleFilter(item.key)"
        >
          <span
            class="filter-dot"
            :style="{ backgroundColor: item.visible ? item.color : '#ccc' }"
          />
          <span class="filter-label">{{ item.label }}</span>
          <span v-if="item.count > 0" class="filter-count">{{ item.count }}</span>
        </button>
        <button
          type="button"
          class="only-btn"
          title="Show only this category"
          @click="selectOnly(item.key)"
        >
          only
        </button>
      </span>
      <button type="button" class="all-btn" title="Show all categories" @click="selectAll">
        all
      </button>
    </div>

    <!-- No variants state -->
    <div v-if="mappableVariants.length === 0" class="text-center py-3">
      <span class="text-muted small">
        {{
          variants.length === 0
            ? 'No ClinVar variants available'
            : 'No variants with protein positions'
        }}
      </span>
    </div>

    <!-- No matching variants after filter -->
    <div v-else-if="filteredVariants.length === 0" class="text-center py-3">
      <span class="text-muted small"> No variants match current filters </span>
    </div>

    <!-- Variant List (scrollable) -->
    <div
      v-else
      ref="listContainer"
      class="variant-list"
      role="list"
      aria-label="ClinVar variants with protein positions"
    >
      <label
        v-for="item in filteredVariants"
        :key="item.variant.variant_id"
        class="variant-item"
        role="listitem"
        @mouseenter="showTooltip($event, item)"
        @mouseleave="hideTooltip"
      >
        <input
          type="checkbox"
          :checked="selectedResidues.has(item.residue)"
          :aria-label="`Highlight ${item.variant.hgvsp || item.variant.variant_id} on 3D structure`"
          @change="toggleVariant(item)"
        />
        <span class="acmg-dot" :style="{ backgroundColor: item.color }" :aria-hidden="true"></span>
        <span class="variant-info">
          <span class="variant-row-top">
            <span class="variant-notation small">
              {{ item.variant.hgvsp || item.variant.hgvsc || item.variant.variant_id }}
            </span>
            <a
              :href="`https://www.ncbi.nlm.nih.gov/clinvar/variation/${item.variant.clinvar_variation_id}/`"
              target="_blank"
              rel="noopener noreferrer"
              class="clinvar-link"
              :aria-label="`View ${item.variant.hgvsp || item.variant.variant_id} in ClinVar`"
              @click.stop
            >
              <i class="bi bi-box-arrow-up-right"></i>
            </a>
          </span>
          <span class="variant-row-bottom">
            <span class="variant-class small text-muted">
              {{ item.label }}
            </span>
            <span class="review-stars" :title="`ClinVar review: ${item.variant.gold_stars} stars`">
              {{ '★'.repeat(item.variant.gold_stars) }}{{ '☆'.repeat(4 - item.variant.gold_stars) }}
            </span>
          </span>
        </span>
      </label>
    </div>

    <!-- Single shared tooltip (uses component to avoid v-html XSS warning) -->
    <VariantTooltip
      ref="tooltipEl"
      :visible="tooltipVisible"
      :data="tooltipData"
      :position="tooltipPosition"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, watch } from 'vue';
import { BButton } from 'bootstrap-vue-next';
import VariantTooltip from './VariantTooltip.vue';
import type { ClinVarVariant } from '@/types/external';
import {
  ACMG_COLORS,
  ACMG_LABELS,
  parseResidueNumber,
  classifyClinicalSignificance,
  type AcmgClassification,
} from '@/types/alphafold';

/** Filter state key type matching ACMG classifications */
type FilterKey = 'pathogenic' | 'likelyPathogenic' | 'vus' | 'likelyBenign' | 'benign';

/** Mapping from AcmgClassification to FilterKey */
const classificationToFilterKey: Record<AcmgClassification, FilterKey> = {
  pathogenic: 'pathogenic',
  likely_pathogenic: 'likelyPathogenic',
  vus: 'vus',
  likely_benign: 'likelyBenign',
  benign: 'benign',
};

interface Props {
  variants: ClinVarVariant[];
}

const props = defineProps<Props>();
const emit = defineEmits<{
  'toggle-variant': [payload: { variant: ClinVarVariant; selected: boolean }];
  'clear-all': [];
  'filter-change': [payload: { hiddenClassifications: AcmgClassification[] }];
}>();

// Track selected residues for checkbox state
const selectedResidues = ref<Set<number>>(new Set());

// Search query for text filtering
const searchQuery = ref('');

// Filter state for ACMG classifications (all visible by default)
const filterState = reactive({
  pathogenic: true,
  likelyPathogenic: true,
  vus: true,
  likelyBenign: true,
  benign: true,
});

// Refs for tooltip positioning
const listContainer = ref<HTMLElement | null>(null);
const tooltipEl = ref<InstanceType<typeof VariantTooltip> | null>(null);

// Tooltip state (structured data for VariantTooltip component)
interface TooltipData {
  hgvsp: string | null;
  hgvsc: string | null;
  variantId: string;
  label: string;
  color: string;
  goldStars: number;
}
const tooltipData = ref<TooltipData | null>(null);
const tooltipVisible = ref(false);
const tooltipPosition = ref({ top: 0, left: 0 });

// Processable variant item (variant + parsed residue + ACMG info)
interface MappableVariant {
  variant: ClinVarVariant;
  residue: number;
  classification: AcmgClassification | null;
  color: string;
  label: string;
}

// Filter variants to only those with parseable protein positions (missense/inframe only)
// parseResidueNumber returns null for frameshift, stop, and splice variants
// Sorted by residue number for spatial ordering
const mappableVariants = computed<MappableVariant[]>(() => {
  const items: MappableVariant[] = [];

  for (const variant of props.variants) {
    const residue = parseResidueNumber(variant.hgvsp);
    if (residue === null) continue; // Skip non-mappable variants (frameshift, stop, splice)

    const classification = classifyClinicalSignificance(variant.clinical_significance);
    items.push({
      variant,
      residue,
      classification,
      color: classification ? ACMG_COLORS[classification] : '#999999',
      label: classification ? ACMG_LABELS[classification] : variant.clinical_significance,
    });
  }

  // Sort by residue number (ascending) for spatial ordering in list
  items.sort((a, b) => a.residue - b.residue);
  return items;
});

/**
 * Count variants by ACMG classification
 */
function countByClassification(): Record<FilterKey, number> {
  const counts: Record<FilterKey, number> = {
    pathogenic: 0,
    likelyPathogenic: 0,
    vus: 0,
    likelyBenign: 0,
    benign: 0,
  };

  for (const item of mappableVariants.value) {
    if (item.classification) {
      const key = classificationToFilterKey[item.classification];
      counts[key]++;
    }
  }

  return counts;
}

/**
 * Legend items for ACMG filter chips with counts
 */
const legendItems = computed(() => {
  const counts = countByClassification();
  return [
    {
      key: 'pathogenic' as const,
      label: 'Path',
      color: ACMG_COLORS.pathogenic,
      visible: filterState.pathogenic,
      count: counts.pathogenic,
    },
    {
      key: 'likelyPathogenic' as const,
      label: 'LP',
      color: ACMG_COLORS.likely_pathogenic,
      visible: filterState.likelyPathogenic,
      count: counts.likelyPathogenic,
    },
    {
      key: 'vus' as const,
      label: 'VUS',
      color: ACMG_COLORS.vus,
      visible: filterState.vus,
      count: counts.vus,
    },
    {
      key: 'likelyBenign' as const,
      label: 'LB',
      color: ACMG_COLORS.likely_benign,
      visible: filterState.likelyBenign,
      count: counts.likelyBenign,
    },
    {
      key: 'benign' as const,
      label: 'Ben',
      color: ACMG_COLORS.benign,
      visible: filterState.benign,
      count: counts.benign,
    },
  ];
});

/**
 * Filtered variants based on search query and ACMG filter state
 */
const filteredVariants = computed<MappableVariant[]>(() => {
  const query = searchQuery.value.toLowerCase().trim();

  return mappableVariants.value.filter((item) => {
    // Check ACMG filter
    if (item.classification) {
      const filterKey = classificationToFilterKey[item.classification];
      if (!filterState[filterKey]) return false;
    } else {
      // If no classification, show only if all filters are enabled (unknown classification)
      // This is a fallback - most variants should have a classification
    }

    // Check search query (case-insensitive across hgvsp, hgvsc, variant_id)
    if (query) {
      const hgvsp = (item.variant.hgvsp || '').toLowerCase();
      const hgvsc = (item.variant.hgvsc || '').toLowerCase();
      const variantId = (item.variant.variant_id || '').toLowerCase();

      if (!hgvsp.includes(query) && !hgvsc.includes(query) && !variantId.includes(query)) {
        return false;
      }
    }

    return true;
  });
});

/**
 * Toggle filter visibility for an ACMG classification
 */
function toggleFilter(key: FilterKey): void {
  filterState[key] = !filterState[key];
}

/**
 * Select only one ACMG classification (deselect all others)
 */
function selectOnly(key: FilterKey): void {
  filterState.pathogenic = key === 'pathogenic';
  filterState.likelyPathogenic = key === 'likelyPathogenic';
  filterState.vus = key === 'vus';
  filterState.likelyBenign = key === 'likelyBenign';
  filterState.benign = key === 'benign';
}

/**
 * Select all ACMG classifications
 */
function selectAll(): void {
  filterState.pathogenic = true;
  filterState.likelyPathogenic = true;
  filterState.vus = true;
  filterState.likelyBenign = true;
  filterState.benign = true;
}

/**
 * Get list of hidden ACMG classifications based on current filter state
 */
function getHiddenClassifications(): AcmgClassification[] {
  const hidden: AcmgClassification[] = [];
  if (!filterState.pathogenic) hidden.push('pathogenic');
  if (!filterState.likelyPathogenic) hidden.push('likely_pathogenic');
  if (!filterState.vus) hidden.push('vus');
  if (!filterState.likelyBenign) hidden.push('likely_benign');
  if (!filterState.benign) hidden.push('benign');
  return hidden;
}

/**
 * Watch filter state changes and emit filter-change event
 * This allows parent component to sync 3D markers with filter state
 */
watch(
  () => ({
    pathogenic: filterState.pathogenic,
    likelyPathogenic: filterState.likelyPathogenic,
    vus: filterState.vus,
    likelyBenign: filterState.likelyBenign,
    benign: filterState.benign,
  }),
  () => {
    emit('filter-change', { hiddenClassifications: getHiddenClassifications() });
  },
  { deep: true }
);

// Toggle variant selection
function toggleVariant(item: MappableVariant): void {
  const isCurrentlySelected = selectedResidues.value.has(item.residue);
  const newSelected = !isCurrentlySelected;

  if (newSelected) {
    selectedResidues.value.add(item.residue);
  } else {
    selectedResidues.value.delete(item.residue);
  }

  // Force reactivity update (Set mutation doesn't trigger)
  selectedResidues.value = new Set(selectedResidues.value);

  emit('toggle-variant', { variant: item.variant, selected: newSelected });
}

// Clear all selections
function clearAll(): void {
  selectedResidues.value = new Set();
  emit('clear-all');
}

// Estimated tooltip dimensions for positioning (avoids DOM measurement)
// Actual tooltip is ~150px wide, ~95px tall based on content
const TOOLTIP_WIDTH = 155;
const TOOLTIP_HEIGHT = 95;
const TOOLTIP_GAP = 8;

/**
 * Show tooltip near the hovered element
 * Uses position:fixed with viewport coordinates to avoid overflow clipping
 */
function showTooltip(event: MouseEvent, item: MappableVariant): void {
  // Capture element rect synchronously before it might become stale
  const targetElement = event.currentTarget as HTMLElement;
  if (!targetElement) return;
  const itemRect = targetElement.getBoundingClientRect();

  // Set structured tooltip data (avoids v-html XSS vulnerability)
  tooltipData.value = {
    hgvsp: typeof item.variant.hgvsp === 'string' ? item.variant.hgvsp : null,
    hgvsc: typeof item.variant.hgvsc === 'string' ? item.variant.hgvsc : null,
    variantId: item.variant.variant_id,
    label: item.label,
    color: item.color,
    goldStars: item.variant.gold_stars,
  };

  // Position to the left of the item in viewport coordinates (for position:fixed)
  let left = itemRect.left - TOOLTIP_WIDTH - TOOLTIP_GAP;
  let top = itemRect.top + itemRect.height / 2 - TOOLTIP_HEIGHT / 2;

  // Ensure tooltip stays within viewport bounds
  const minTop = 10;
  const maxTop = window.innerHeight - TOOLTIP_HEIGHT - 10;
  top = Math.max(minTop, Math.min(maxTop, top));

  // If tooltip would go off left edge, position to the right of item instead
  if (left < 10) {
    left = itemRect.right + TOOLTIP_GAP;
  }

  tooltipPosition.value = { top, left };
  tooltipVisible.value = true;
}

/**
 * Hide tooltip
 */
function hideTooltip(): void {
  tooltipVisible.value = false;
  tooltipData.value = null;
}
</script>

<style scoped>
.variant-panel {
  display: flex;
  flex-direction: column;
  height: 100%;
  position: relative;
}

.panel-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 6px 10px;
  background: #f8f9fa;
  border-bottom: 1px solid #dee2e6;
  flex-shrink: 0;
}

/* Search box */
.search-box {
  padding: 6px 10px;
  background: #f8f9fa;
  border-bottom: 1px solid #dee2e6;
  flex-shrink: 0;
}

.search-box input {
  font-size: 0.8rem;
}

/* Filter row */
.filter-row {
  padding: 6px 8px;
  background: #f8f9fa;
  border-bottom: 1px solid #dee2e6;
  flex-shrink: 0;
}

/* Filter chips - compact toggle buttons (matching lollipop plot) */
.filter-chip {
  display: inline-flex;
  align-items: center;
  gap: 3px;
  padding: 2px 6px;
  border: 1px solid #dee2e6;
  border-radius: 10px;
  background: white;
  cursor: pointer;
  transition: all 0.15s ease;
  font-size: 0.7rem;
  line-height: 1.4;
}

.filter-chip:hover {
  border-color: #adb5bd;
  background: #f8f9fa;
}

.filter-chip--hidden {
  opacity: 0.4;
  background: #f5f5f5;
}

.filter-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 50%;
  flex-shrink: 0;
}

.filter-label {
  white-space: nowrap;
}

.filter-count {
  color: #6c757d;
  font-size: 0.65rem;
}

/* Filter group with "only" button */
.filter-group {
  display: inline-flex;
  align-items: center;
  gap: 1px;
}

/* "only" and "all" buttons (gnomAD-style) */
.only-btn,
.all-btn {
  padding: 1px 3px;
  font-size: 0.6rem;
  line-height: 1.2;
  border: 1px solid #dee2e6;
  border-radius: 3px;
  background: #f8f9fa;
  color: #6c757d;
  cursor: pointer;
  transition: all 0.15s ease;
}

.only-btn:hover,
.all-btn:hover {
  background: #e9ecef;
  border-color: #adb5bd;
  color: #495057;
}

.all-btn {
  margin-left: 2px;
}

.variant-list {
  overflow-y: auto;
  flex: 1;
  min-height: 0;
  position: relative;
}

.variant-item {
  display: flex;
  align-items: center;
  gap: 6px;
  padding: 4px 10px;
  cursor: pointer;
  border-bottom: 1px solid #f0f0f0;
  transition: background-color 0.15s;
}

.variant-item:hover {
  background-color: #e9ecef;
}

.variant-item:focus-within {
  background-color: #e9ecef;
  outline: 2px solid #0d6efd;
  outline-offset: -2px;
}

.acmg-dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
  flex-shrink: 0;
}

.variant-info {
  display: flex;
  flex-direction: column;
  min-width: 0;
  flex: 1;
}

.variant-row-top,
.variant-row-bottom {
  display: flex;
  align-items: center;
  gap: 4px;
}

.variant-row-top {
  justify-content: space-between;
}

.variant-notation {
  font-family: 'Courier New', monospace;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.clinvar-link {
  color: #6c757d;
  font-size: 0.65rem;
  flex-shrink: 0;
  opacity: 0.6;
  transition:
    opacity 0.15s,
    color 0.15s;
}

.clinvar-link:hover {
  color: #0d6efd;
  opacity: 1;
}

.variant-class {
  font-size: 0.7rem;
}

.review-stars {
  color: #ffc107;
  font-size: 0.65rem;
  flex-shrink: 0;
  letter-spacing: -1px;
}
</style>
