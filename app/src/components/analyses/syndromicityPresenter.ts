// src/components/analyses/syndromicityPresenter.ts
//
// Pure presentation helpers for the computed syndromicity block (#630).
//
// The block is COMPUTED from curated HPO annotations under a stated, versioned
// rule -- it is `curated_derived_analysis`, not `llm_generated_summary`. It must
// therefore never be rendered behind the AI-provenance affordances, and it must
// render whether or not an LLM summary exists for the cluster.

/** Bootstrap badge variants, matching BaseColorVariant. */
export type SyndromicityBadgeVariant =
  | 'primary'
  | 'secondary'
  | 'success'
  | 'danger'
  | 'warning'
  | 'info'
  | 'light'
  | 'dark';

/** The computed per-cluster syndromicity block, as served by the API. */
export interface SyndromicityBlock {
  rule_version?: string | null;
  data_class?: string | null;
  measures?: string | null;
  entities?: number | null;
  evaluable?: number | null;
  coverage?: number | null;
  insufficient_annotation?: number | null;
  no_recorded_extraneurological_involvement?: number | null;
  syndromic?: number | null;
  fraction_syndromic?: number | null;
  fraction_syndromic_ci95?: { lower?: number | null; upper?: number | null } | null;
  fraction_syndromic_with_head_size?: number | null;
  median_systems?: number | null;
  mean_systems?: number | null;
  mean_present_terms?: number | null;
  system_frequencies?: Record<string, number> | null;
  neurological_system_frequencies?: Record<string, number> | null;
  cluster_call?: string | null;
  thresholds?: Record<string, number> | null;
}

/**
 * Plumber does not auto-unbox, so scalars nested in a list arrive as length-1
 * arrays. Unwrap field-by-field, never blanket-recursively, or a genuine
 * length-1 array (e.g. a one-element system list) gets flattened.
 */
function scalar<T>(value: T | T[] | null | undefined): T | null {
  if (Array.isArray(value)) return value.length > 0 ? (value[0] as T) : null;
  return value === undefined ? null : (value as T);
}

export function hasSyndromicity(block: SyndromicityBlock | null | undefined): boolean {
  if (!block) return false;
  return scalar(block.cluster_call) !== null;
}

const CALL_LABELS: Record<string, string> = {
  predominantly_syndromic: 'Predominantly syndromic',
  predominantly_isolated: 'Predominantly non-syndromic',
  mixed: 'Mixed',
  insufficient_annotation: 'Insufficient annotation',
};

export function syndromicityLabel(block: SyndromicityBlock | null | undefined): string {
  const call = scalar(block?.cluster_call);
  if (!call) return 'Not computed';
  return CALL_LABELS[call] ?? call;
}

/**
 * Badge variant. Deliberately NOT 'light' for any real value: 'light' is the
 * variant the retired AI-generated badge used for its unknown state, and the
 * computed block must not be mistaken for it.
 */
export function syndromicityVariant(
  block: SyndromicityBlock | null | undefined
): SyndromicityBadgeVariant {
  switch (scalar(block?.cluster_call)) {
    case 'predominantly_syndromic':
      return 'warning';
    case 'predominantly_isolated':
      return 'info';
    case 'mixed':
      return 'secondary';
    default:
      return 'light';
  }
}

function pct(value: number | null): string | null {
  if (value === null || Number.isNaN(value)) return null;
  return `${(value * 100).toFixed(1)}%`;
}

/**
 * The headline line: the fraction with its interval, which is the primary
 * reported quantity. The categorical label is a convenience on top of it, not
 * a substitute for it -- a cluster can sit close enough to a cutoff that the
 * word alone would be misleading.
 */
export function syndromicitySubtitle(block: SyndromicityBlock | null | undefined): string {
  if (!block) return '';
  const fraction = pct(scalar(block.fraction_syndromic));
  const evaluable = scalar(block.evaluable);
  const ci = block.fraction_syndromic_ci95 ?? null;
  const lower = pct(scalar(ci?.lower));
  const upper = pct(scalar(ci?.upper));

  if (fraction === null || evaluable === null) return '';
  const interval = lower !== null && upper !== null ? ` (95% CI ${lower}–${upper})` : '';
  return `${fraction}${interval} of ${evaluable} entities`;
}

/** Systems ordered most-frequent-first, for the chip row. */
export function topSystems(
  block: SyndromicityBlock | null | undefined,
  limit = 6
): Array<{ system: string; count: number }> {
  const freq = block?.system_frequencies;
  if (!freq || typeof freq !== 'object') return [];
  return Object.entries(freq)
    .map(([system, count]) => ({ system, count: Number(scalar(count as never)) }))
    .filter((row) => Number.isFinite(row.count))
    .sort((a, b) => b.count - a.count || a.system.localeCompare(b.system))
    .slice(0, limit);
}

/** Human-readable organ-system name. */
export function systemLabel(system: string): string {
  const labels: Record<string, string> = {
    renal_urogenital: 'Renal / urogenital',
    skeletal: 'Skeletal',
    metabolic: 'Metabolic',
    growth: 'Growth',
    craniofacial: 'Craniofacial',
    ear_hearing: 'Hearing',
    eye: 'Eye',
    endocrine: 'Endocrine',
    integument: 'Skin / integument',
    cardiovascular: 'Cardiovascular',
    hematologic: 'Haematologic',
    neoplasm: 'Neoplasm',
    immune: 'Immune',
    musculature: 'Musculature',
    gastrointestinal: 'Gastrointestinal',
    nervous_system: 'Nervous system',
    head_size: 'Head size',
  };
  return labels[system] ?? system;
}

export { scalar as unwrapSyndromicityScalar };
