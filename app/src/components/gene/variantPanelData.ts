/**
 * variantPanelData.ts
 *
 * Pure data/control helpers for VariantPanel.vue:
 *  - ACMG classification <-> filter-key mapping
 *  - mappable-variant building (parse residue + classify + color/label)
 *  - counting and search/ACMG filtering
 *  - hidden-classification derivation
 *  - filter-state mutation helpers
 *
 * Extracted from VariantPanel.vue so the component keeps DOM/tooltip and
 * selection state only. Framework-agnostic and unit-testable.
 */

import type { ClinVarVariant } from '@/types/external';
import {
  ACMG_COLORS,
  ACMG_LABELS,
  parseResidueNumber,
  classifyClinicalSignificance,
  type AcmgClassification,
} from '@/types/alphafold';

/** Filter state key type matching ACMG classifications */
export type VariantFilterKey =
  | 'pathogenic'
  | 'likelyPathogenic'
  | 'vus'
  | 'likelyBenign'
  | 'benign';

/** ACMG filter state (one boolean per filter key). */
export type VariantFilterState = Record<VariantFilterKey, boolean>;

/** Mapping from AcmgClassification to VariantFilterKey */
export const classificationToFilterKey: Record<AcmgClassification, VariantFilterKey> = {
  pathogenic: 'pathogenic',
  likely_pathogenic: 'likelyPathogenic',
  vus: 'vus',
  likely_benign: 'likelyBenign',
  benign: 'benign',
};

/** Processable variant item (variant + parsed residue + ACMG info) */
export interface MappableVariant {
  variant: ClinVarVariant;
  residue: number;
  classification: AcmgClassification | null;
  color: string;
  label: string;
}

/**
 * Filter variants to only those with parseable protein positions
 * (missense/inframe only — parseResidueNumber returns null for frameshift,
 * stop, and splice variants). Sorted by residue number for spatial ordering.
 */
export function buildMappableVariants(variants: ClinVarVariant[]): MappableVariant[] {
  const items: MappableVariant[] = [];

  for (const variant of variants) {
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
}

/**
 * Count mappable variants by ACMG filter key.
 */
export function countByClassification(
  mappableVariants: MappableVariant[]
): Record<VariantFilterKey, number> {
  const counts: Record<VariantFilterKey, number> = {
    pathogenic: 0,
    likelyPathogenic: 0,
    vus: 0,
    likelyBenign: 0,
    benign: 0,
  };

  for (const item of mappableVariants) {
    if (item.classification) {
      const key = classificationToFilterKey[item.classification];
      counts[key]++;
    }
  }

  return counts;
}

/**
 * Filter mappable variants by ACMG filter state and a case-insensitive search
 * query across hgvsp / hgvsc / variant_id.
 */
export function filterMappableVariants(
  mappableVariants: MappableVariant[],
  filterState: VariantFilterState,
  searchQuery: string
): MappableVariant[] {
  const query = searchQuery.toLowerCase().trim();

  return mappableVariants.filter((item) => {
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
}

/**
 * Get the list of hidden ACMG classifications for the current filter state.
 */
export function getHiddenClassifications(filterState: VariantFilterState): AcmgClassification[] {
  const hidden: AcmgClassification[] = [];
  if (!filterState.pathogenic) hidden.push('pathogenic');
  if (!filterState.likelyPathogenic) hidden.push('likely_pathogenic');
  if (!filterState.vus) hidden.push('vus');
  if (!filterState.likelyBenign) hidden.push('likely_benign');
  if (!filterState.benign) hidden.push('benign');
  return hidden;
}

/**
 * Toggle a single ACMG filter key in place.
 */
export function toggleFilter(filterState: VariantFilterState, key: VariantFilterKey): void {
  filterState[key] = !filterState[key];
}

/**
 * Select only one ACMG classification (deselect all others) in place.
 */
export function selectOnly(filterState: VariantFilterState, key: VariantFilterKey): void {
  filterState.pathogenic = key === 'pathogenic';
  filterState.likelyPathogenic = key === 'likelyPathogenic';
  filterState.vus = key === 'vus';
  filterState.likelyBenign = key === 'likelyBenign';
  filterState.benign = key === 'benign';
}

/**
 * Select all ACMG classifications in place.
 */
export function selectAll(filterState: VariantFilterState): void {
  filterState.pathogenic = true;
  filterState.likelyPathogenic = true;
  filterState.vus = true;
  filterState.likelyBenign = true;
  filterState.benign = true;
}
