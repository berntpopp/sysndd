/**
 * proteinLollipopControls.ts
 *
 * Pure presentation/control helpers for ProteinDomainLollipopPlot.vue:
 *  - domain type label formatting
 *  - effect-type label/order constants
 *  - variant counting by classification / effect type
 *  - pathogenicity & effect-type filter mutation helpers
 *
 * Extracted from ProteinDomainLollipopPlot.vue so the component stays focused
 * on template + D3-composable wiring. Framework-agnostic and unit-testable.
 */

import type { ProcessedVariant, EffectType, LollipopFilterState } from '@/types/protein';
import { normalizeEffectType } from '@/types/protein';

/** Pathogenicity filter keys on the lollipop filter state. */
export type PathogenicityFilterKey =
  | 'pathogenic'
  | 'likelyPathogenic'
  | 'vus'
  | 'likelyBenign'
  | 'benign';

/** Effect types in canonical display order. */
export const EFFECT_TYPE_ORDER: EffectType[] = [
  'missense',
  'frameshift',
  'stop_gained',
  'splice',
  'inframe_indel',
  'synonymous',
  'other',
];

/** Human-readable labels for effect types. */
export const EFFECT_TYPE_LABELS: Record<EffectType, string> = {
  missense: 'Missense',
  frameshift: 'Frameshift',
  stop_gained: 'Stop gained',
  splice: 'Splice',
  inframe_indel: 'In-frame indel',
  synonymous: 'Synonymous',
  other: 'Other',
};

/**
 * Format a UniProt domain type code into a human-readable label.
 * e.g. 'DOMAIN' -> 'Domain', 'ZN_FING' -> 'Zinc finger', 'DNA_BIND' -> 'DNA binding'
 */
export function formatDomainType(type: string): string {
  const typeMap: Record<string, string> = {
    DOMAIN: 'Domain',
    REGION: 'Region',
    MOTIF: 'Motif',
    ZN_FING: 'Zinc finger',
    DNA_BIND: 'DNA binding',
    REPEAT: 'Repeat',
    COILED: 'Coiled coil',
    TRANSMEM: 'Transmembrane',
    SIGNAL: 'Signal peptide',
    PROPEP: 'Propeptide',
    TRANSIT: 'Transit peptide',
    CHAIN: 'Chain',
    ACT_SITE: 'Active site',
    BINDING: 'Binding site',
    SITE: 'Site',
    DISULFID: 'Disulfide bond',
    CARBOHYD: 'Glycosylation',
    LIPID: 'Lipidation',
    CROSSLNK: 'Cross-link',
    VAR_SEQ: 'Variant sequence',
  };

  if (typeMap[type]) {
    return typeMap[type];
  }

  // Fall back to title case with underscore replacement
  return type
    .toLowerCase()
    .replace(/_/g, ' ')
    .replace(/\b\w/g, (c) => c.toUpperCase());
}

/**
 * Count variants by pathogenicity classification.
 */
export function countByClassification(variants: ProcessedVariant[]): Record<string, number> {
  const counts: Record<string, number> = {};
  for (const variant of variants) {
    const key = variant.classification;
    counts[key] = (counts[key] || 0) + 1;
  }
  return counts;
}

/**
 * Count variants by effect type.
 */
export function countByEffectType(variants: ProcessedVariant[]): Record<EffectType, number> {
  const counts: Record<EffectType, number> = {
    missense: 0,
    frameshift: 0,
    stop_gained: 0,
    splice: 0,
    inframe_indel: 0,
    synonymous: 0,
    other: 0,
  };
  for (const variant of variants) {
    const effectType = normalizeEffectType(variant.majorConsequence);
    counts[effectType]++;
  }
  return counts;
}

/**
 * Select only one pathogenicity class (deselect all others) in place.
 */
export function selectOnlyPathogenicity(
  filterState: LollipopFilterState,
  key: PathogenicityFilterKey
): void {
  filterState.pathogenic = key === 'pathogenic';
  filterState.likelyPathogenic = key === 'likelyPathogenic';
  filterState.vus = key === 'vus';
  filterState.likelyBenign = key === 'likelyBenign';
  filterState.benign = key === 'benign';
}

/**
 * Select all pathogenicity classes in place.
 */
export function selectAllPathogenicity(filterState: LollipopFilterState): void {
  filterState.pathogenic = true;
  filterState.likelyPathogenic = true;
  filterState.vus = true;
  filterState.likelyBenign = true;
  filterState.benign = true;
}

/**
 * Select only one effect type (deselect all others) in place.
 */
export function selectOnlyEffectType(
  filterState: LollipopFilterState,
  effectType: EffectType
): void {
  for (const et of EFFECT_TYPE_ORDER) {
    filterState.effectFilters[et] = et === effectType;
  }
}

/**
 * Select all effect types in place.
 */
export function selectAllEffectTypes(filterState: LollipopFilterState): void {
  for (const et of EFFECT_TYPE_ORDER) {
    filterState.effectFilters[et] = true;
  }
}
