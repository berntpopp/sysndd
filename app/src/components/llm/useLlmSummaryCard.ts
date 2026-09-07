// Derivation layer for LlmSummaryCard.vue. Extracted from the component's
// setup() so the card stays a thin presentation shell. These are computed
// views over admin-generated, validated cached LLM summaries — all
// user-facing AI-disclosure copy and badges stay in the component template.

import { computed, type ComputedRef } from 'vue';
import { format } from 'date-fns';

/**
 * Interface for derived confidence from enrichment analysis
 */
export interface DerivedConfidence {
  score: 'high' | 'medium' | 'low';
  avg_fdr: number;
  term_count: number;
}

/**
 * Interface for the summary JSON structure from the LLM
 */
export interface SummaryJson {
  summary: string;
  key_themes?: string[];
  pathways?: string[];
  tags?: string[];
  clinical_relevance?: string;
  confidence?: string;
  derived_confidence?: DerivedConfidence;
  // Phenotype cluster specific fields
  inheritance_patterns?: string[];
  // #630: `syndromicity` was REMOVED from the LLM contract and is stripped from
  // historical cached rows on read. It is computed from curated HPO annotations
  // and rendered by SyndromicityCard.vue instead. Do not reintroduce it here.
  clinical_pattern?: string | string[];
  // Judge metadata (if present)
  llm_judge_verdict?: 'accept' | 'accept_with_corrections' | 'low_confidence' | 'reject' | string[];
  llm_judge_reasoning?: string | string[];
  llm_judge_points?: number | number[];
  corrections_applied?: boolean | boolean[];
  corrections_made?: string[];
}

export type LlmBadgeVariant =
  | 'primary'
  | 'secondary'
  | 'success'
  | 'danger'
  | 'warning'
  | 'info'
  | 'light'
  | 'dark';

export interface LlmSummaryCardProps {
  summary: SummaryJson | null;
  createdAt: string;
}

export interface UseLlmSummaryCard {
  normalizedSummary: ComputedRef<SummaryJson | null>;
  derivedConfidence: ComputedRef<DerivedConfidence | null>;
  formattedDate: ComputedRef<string>;
  hasKeyThemes: ComputedRef<boolean>;
  hasPathways: ComputedRef<boolean>;
  hasTags: ComputedRef<boolean>;
  hasInheritancePatterns: ComputedRef<boolean>;
  getInheritanceTooltip: (pattern: string) => string;
  judgeVerdict: ComputedRef<string | null>;
  judgePoints: ComputedRef<number | null>;
  hasCorrections: ComputedRef<boolean>;
  correctionsList: ComputedRef<string[]>;
  judgeVerdictLabel: ComputedRef<string>;
  judgeVerdictVariant: ComputedRef<LlmBadgeVariant>;
  validatedTooltip: ComputedRef<string>;
  correctionsTooltip: ComputedRef<string>;
}

// Helper to normalize R JSON values (single values come as arrays)
function normalize<T>(val: T | T[] | undefined): T | undefined {
  if (val === undefined) return undefined;
  return Array.isArray(val) ? val[0] : val;
}

/**
 * Cleanly extract a scalar string from values that may arrive as single-element
 * arrays from R Plumber, JSON-stringified arrays like '[ "..." ]', or quoted strings.
 */
export function parseCleanString(val: unknown): string | undefined {
  if (val === undefined || val === null) return undefined;
  let s = val;
  if (Array.isArray(s)) {
    if (s.length === 0) return undefined;
    s = s.map((item) => (typeof item === 'string' ? item.trim() : String(item))).join(', ');
  }
  if (typeof s !== 'string') return String(s);
  let str = s.trim();
  if (str.startsWith('[') && str.endsWith(']')) {
    try {
      const parsed = JSON.parse(str);
      if (Array.isArray(parsed)) {
        return parsed.map((item) => String(item).trim()).filter(Boolean).join(', ');
      }
    } catch {
      str = str.slice(1, -1).trim();
    }
  }
  // Strip surrounding quotes
  while (
    (str.startsWith('"') && str.endsWith('"')) ||
    (str.startsWith("'") && str.endsWith("'"))
  ) {
    str = str.slice(1, -1).trim();
  }
  return str || undefined;
}

export function useLlmSummaryCard(props: LlmSummaryCardProps): UseLlmSummaryCard {
  /**
   * Normalized summary with scalar fields extracted from R's array format
   */
  const normalizedSummary = computed<SummaryJson | null>(() => {
    if (!props.summary) return null;
    return {
      ...props.summary,
      summary: parseCleanString(props.summary.summary) ?? '',
      clinical_relevance: parseCleanString(props.summary.clinical_relevance),
      clinical_pattern: parseCleanString(props.summary.clinical_pattern),
    };
  });

  /**
   * Get derived confidence (objective, based on enrichment terms)
   */
  const derivedConfidence = computed<DerivedConfidence | null>(() => {
    const dc = props.summary?.derived_confidence;
    if (!dc) return null;

    const score = normalize(dc.score);
    const avgFdr = normalize(dc.avg_fdr);
    const termCount = normalize(dc.term_count);

    if (!score || typeof avgFdr !== 'number' || typeof termCount !== 'number') {
      return null;
    }

    return {
      score: score as 'high' | 'medium' | 'low',
      avg_fdr: avgFdr,
      term_count: termCount,
    };
  });

  /**
   * Format the creation date for display
   */
  const formattedDate = computed<string>(() => {
    if (!props.createdAt) return '';
    try {
      return format(new Date(props.createdAt), 'MMM d, yyyy');
    } catch {
      return props.createdAt;
    }
  });

  /**
   * Check if key themes are present and non-empty
   */
  const hasKeyThemes = computed<boolean>(() => {
    return Array.isArray(props.summary?.key_themes) && props.summary.key_themes.length > 0;
  });

  /**
   * Check if pathways are present and non-empty
   */
  const hasPathways = computed<boolean>(() => {
    return Array.isArray(props.summary?.pathways) && props.summary.pathways.length > 0;
  });

  /**
   * Check if tags are present and non-empty
   */
  const hasTags = computed<boolean>(() => {
    return Array.isArray(props.summary?.tags) && props.summary.tags.length > 0;
  });

  /**
   * Check if inheritance patterns are present and non-empty
   */
  const hasInheritancePatterns = computed<boolean>(() => {
    return (
      Array.isArray(props.summary?.inheritance_patterns) &&
      props.summary.inheritance_patterns.length > 0
    );
  });




  /**
   * Get tooltip for inheritance pattern abbreviation
   */
  const getInheritanceTooltip = (pattern: string): string => {
    const tooltips: Record<string, string> = {
      AD: 'Autosomal dominant inheritance',
      AR: 'Autosomal recessive inheritance',
      XL: 'X-linked inheritance',
      XLR: 'X-linked recessive inheritance',
      XLD: 'X-linked dominant inheritance',
      MT: 'Mitochondrial inheritance',
      SP: 'Sporadic occurrence',
    };
    return tooltips[pattern.toUpperCase()] || pattern;
  };

  /**
   * Judge verdict from LLM judge validation
   */
  const judgeVerdict = computed<string | null>(() => {
    return normalize(props.summary?.llm_judge_verdict) ?? null;
  });

  /**
   * Judge points (0-8 scale for functional, similar for phenotype)
   */
  const judgePoints = computed<number | null>(() => {
    const points = normalize(props.summary?.llm_judge_points);
    return typeof points === 'number' ? points : null;
  });

  /**
   * Whether corrections were applied by the judge
   */
  const hasCorrections = computed<boolean>(() => {
    return normalize(props.summary?.corrections_applied) === true;
  });

  /**
   * List of corrections made by the judge
   */
  const correctionsList = computed<string[]>(() => {
    const corrections = props.summary?.corrections_made;
    return Array.isArray(corrections) ? corrections : [];
  });

  /**
   * Judge verdict label for display (explicitly notes automated AI evaluation)
   */
  const judgeVerdictLabel = computed<string>(() => {
    const verdict = judgeVerdict.value;
    if (!verdict) return '';

    switch (verdict) {
      case 'accept':
        return 'AI evaluated';
      case 'accept_with_corrections':
        return 'AI evaluated (corrected)';
      case 'low_confidence':
        return 'Needs review';
      case 'reject':
        return 'Rejected';
      default:
        return verdict;
    }
  });

  /**
   * Bootstrap variant for judge verdict badge (calm secondary/neutral instead of clinical success)
   */
  const judgeVerdictVariant = computed<LlmBadgeVariant>(() => {
    const verdict = judgeVerdict.value;
    switch (verdict) {
      case 'accept':
        return 'secondary';
      case 'accept_with_corrections':
        return 'secondary';
      case 'low_confidence':
        return 'warning';
      case 'reject':
        return 'danger';
      default:
        return 'secondary';
    }
  });

  /**
   * Tooltip for validation badge with explicit automated provenance disclosure
   */
  const validatedTooltip = computed<string>(() => {
    const verdict = judgeVerdict.value;
    const reasoning = normalize(props.summary?.llm_judge_reasoning);

    let tooltip = '';

    switch (verdict) {
      case 'accept':
        tooltip =
          'Consistency verified by automated AI evaluation. Note: this text is model-generated and automated-evaluated, not manual clinical curation.';
        break;
      case 'accept_with_corrections':
        tooltip =
          'Consistency verified by automated AI evaluation with minor corrections applied. Note: not manual clinical curation.';
        break;
      case 'low_confidence':
        tooltip = 'Low confidence from automated evaluation - manual review recommended';
        break;
      case 'reject':
        tooltip = 'Content rejected by automated evaluation model';
        break;
      default:
        tooltip = 'Validation status';
    }

    if (reasoning) {
      tooltip += `\n\nEvaluator notes: ${reasoning}`;
    }

    return tooltip;
  });

  /**
   * Tooltip for corrections indicator
   */
  const correctionsTooltip = computed<string>(() => {
    if (correctionsList.value.length === 0) {
      return 'Minor corrections applied';
    }
    return `Corrections:\n${correctionsList.value.join('\n')}`;
  });

  return {
    normalizedSummary,
    derivedConfidence,
    formattedDate,
    hasKeyThemes,
    hasPathways,
    hasTags,
    hasInheritancePatterns,
    getInheritanceTooltip,
    judgeVerdict,
    judgePoints,
    hasCorrections,
    correctionsList,
    judgeVerdictLabel,
    judgeVerdictVariant,
    validatedTooltip,
    correctionsTooltip,
  };
}
