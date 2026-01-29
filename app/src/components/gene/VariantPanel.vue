<template>
  <div class="variant-panel" role="region" aria-label="ClinVar variant selection panel">
    <!-- Panel Header -->
    <div class="panel-header">
      <span class="fw-semibold small">Variants ({{ mappableVariants.length }})</span>
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

    <!-- No variants state -->
    <div v-if="mappableVariants.length === 0" class="text-center py-3">
      <span class="text-muted small">
        {{ variants.length === 0 ? 'No ClinVar variants available' : 'No variants with protein positions' }}
      </span>
    </div>

    <!-- Variant List (scrollable) -->
    <div v-else class="variant-list" role="list" aria-label="ClinVar variants with protein positions">
      <label
        v-for="item in mappableVariants"
        :key="item.variant.variant_id"
        class="variant-item"
        role="listitem"
      >
        <input
          type="checkbox"
          :checked="selectedResidues.has(item.residue)"
          :aria-label="`Highlight ${item.variant.hgvsp || item.variant.variant_id} on 3D structure`"
          @change="toggleVariant(item)"
        />
        <span
          class="acmg-dot"
          :style="{ backgroundColor: item.color }"
          :aria-hidden="true"
        ></span>
        <span class="variant-info">
          <span class="variant-notation small">
            {{ item.variant.hgvsp || item.variant.hgvsc || item.variant.variant_id }}
          </span>
          <span class="variant-class small text-muted">
            {{ item.label }}
          </span>
        </span>
      </label>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { BButton } from 'bootstrap-vue-next';
import type { ClinVarVariant } from '@/types/external';
import {
  ACMG_COLORS,
  ACMG_LABELS,
  parseResidueNumber,
  classifyClinicalSignificance,
  type AcmgClassification,
} from '@/types/alphafold';

interface Props {
  variants: ClinVarVariant[];
}

const props = defineProps<Props>();
const emit = defineEmits<{
  'toggle-variant': [payload: { variant: ClinVarVariant; selected: boolean }];
  'clear-all': [];
}>();

// Track selected residues for checkbox state
const selectedResidues = ref<Set<number>>(new Set());

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
</script>

<style scoped>
.variant-panel {
  display: flex;
  flex-direction: column;
  height: 100%;
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

.variant-list {
  overflow-y: auto;
  flex: 1;
  min-height: 0;
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
  background-color: #f8f9fa;
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
}

.variant-notation {
  font-family: 'Courier New', monospace;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.variant-class {
  font-size: 0.7rem;
}
</style>
