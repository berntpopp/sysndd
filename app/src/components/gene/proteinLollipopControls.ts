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
  | 'benign'
  | 'conflicting'
  | 'other';

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
  filterState.conflicting = key === 'conflicting';
  filterState.other = key === 'other';
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
  filterState.conflicting = true;
  filterState.other = true;
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

/** Canonical label for variants with missing, uninformative, or placeholder conditions */
export const NOT_PROVIDED_CONDITION = 'Not provided';

/** Alias for backwards compatibility with earlier filter states and tests */
export const NOT_SPECIFIED_CONDITION = NOT_PROVIDED_CONDITION;

/** Regular expression identifying non-informative ClinVar condition strings */
const PLACEHOLDER_CONDITION_REGEX =
  /^(not\s*(provided|specified|reported)|see\s*cases|unknown|unspecified|none|[.-])$/i;

/**
 * Check whether a raw condition string is an uninformative placeholder.
 */
export function isUnspecifiedCondition(cond?: string | null): boolean {
  if (!cond || !cond.trim() || cond.trim().toUpperCase() === 'NA') {
    return true;
  }
  return PLACEHOLDER_CONDITION_REGEX.test(cond.trim());
}

/**
 * Normalize a condition string into a canonical label.
 * Maps all variations of "not provided", "not specified", "see cases", etc. to "Not provided".
 */
export function normalizeCondition(cond?: string | null): string {
  if (isUnspecifiedCondition(cond)) {
    return NOT_PROVIDED_CONDITION;
  }
  return cond!.trim();
}

/**
 * Normalize and deduplicate a variant's condition list.
 * Specific disease conditions are sorted alphabetically, followed by "Not provided" if present.
 */
export function normalizeConditionList(conditions?: string[] | null): string[] {
  if (!conditions || conditions.length === 0) {
    return [NOT_PROVIDED_CONDITION];
  }

  const set = new Set<string>();
  for (const c of conditions) {
    set.add(normalizeCondition(c));
  }

  return Array.from(set).sort((a, b) => {
    if (a === NOT_PROVIDED_CONDITION) return 1;
    if (b === NOT_PROVIDED_CONDITION) return -1;
    return a.localeCompare(b);
  });
}

/**
 * Count variants per distinct reported condition.
 * Specific clinical conditions are sorted by count descending (then alphabetical).
 * "Not provided" is grouped into a single consolidated count and placed at the very end
 * so that informative clinical syndromes take visual precedence in filter chips.
 */
export function countByCondition(
  variants: Array<{ conditions?: string[] }>
): Array<{ condition: string; count: number }> {
  const counts = new Map<string, number>();

  for (const variant of variants) {
    const conds = normalizeConditionList(variant.conditions);
    for (const cond of conds) {
      counts.set(cond, (counts.get(cond) || 0) + 1);
    }
  }

  const specificConditions: Array<{ condition: string; count: number }> = [];
  let notProvidedEntry: { condition: string; count: number } | null = null;

  for (const [condition, count] of counts.entries()) {
    if (condition === NOT_PROVIDED_CONDITION) {
      notProvidedEntry = { condition, count };
    } else {
      specificConditions.push({ condition, count });
    }
  }

  specificConditions.sort((a, b) => b.count - a.count || a.condition.localeCompare(b.condition));

  if (notProvidedEntry) {
    specificConditions.push(notProvidedEntry);
  }

  return specificConditions;
}

/**
 * Check whether a variant's reported conditions are visible under the active filter state.
 */
export function isConditionVisible(
  conditions: string[] | undefined,
  filterState: LollipopFilterState
): boolean {
  if (!filterState.selectedConditions || filterState.selectedConditions.length === 0) {
    return true;
  }

  const normalized = normalizeConditionList(conditions);
  return normalized.some((c) => filterState.selectedConditions!.includes(c));
}

/**
 * Toggle a condition in the filter state.
 */
export function toggleCondition(
  filterState: LollipopFilterState,
  condition: string,
  allConditions: string[]
): void {
  if (!filterState.selectedConditions) {
    // Currently all conditions are shown; deselecting one means all except this one are selected
    filterState.selectedConditions = allConditions.filter((c) => c !== condition);
    return;
  }

  if (filterState.selectedConditions.includes(condition)) {
    filterState.selectedConditions = filterState.selectedConditions.filter((c) => c !== condition);
    if (filterState.selectedConditions.length === 0) {
      // If none selected, reset to all
      filterState.selectedConditions = null;
    }
  } else {
    filterState.selectedConditions.push(condition);
    if (filterState.selectedConditions.length >= allConditions.length) {
      filterState.selectedConditions = null;
    }
  }
}

/**
 * Select only one condition in the filter state.
 */
export function selectOnlyCondition(
  filterState: LollipopFilterState,
  condition: string
): void {
  filterState.selectedConditions = [condition];
}

/**
 * Reset condition filter state to show all conditions.
 */
export function selectAllConditions(filterState: LollipopFilterState): void {
  filterState.selectedConditions = null;
}

