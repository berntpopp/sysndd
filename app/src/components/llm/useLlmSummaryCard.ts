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
  syndromicity?: 'predominantly_syndromic' | 'predominantly_id' | 'mixed' | 'unknown';
  // Judge metadata (if present)
  llm_judge_verdict?: 'accept' | 'accept_with_corrections' | 'low_confidence' | 'reject';
  llm_judge_reasoning?: string;
  llm_judge_points?: number;
  corrections_applied?: boolean;
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
  hasSyndromicity: ComputedRef<boolean>;
  syndromicityVariant: ComputedRef<LlmBadgeVariant>;
  syndromicityLabel: ComputedRef<string>;
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

export function useLlmSummaryCard(props: LlmSummaryCardProps): UseLlmSummaryCard {
  /**
   * Normalized summary with scalar fields extracted from R's array format
   */
  const normalizedSummary = computed<SummaryJson | null>(() => {
    if (!props.summary) return null;
    return {
      ...props.summary,
      summary: normalize(props.summary.summary) ?? '',
      clinical_relevance: normalize(props.summary.clinical_relevance),
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
   * Check if syndromicity data is present
   */
  const hasSyndromicity = computed<boolean>(() => {
    const syndromicity = normalize(props.summary?.syndromicity);
    return syndromicity !== undefined && syndromicity !== null && syndromicity !== 'unknown';
  });

  /**
   * Syndromicity badge variant
   */
  const syndromicityVariant = computed<LlmBadgeVariant>(() => {
    const syndromicity = normalize(props.summary?.syndromicity);
    switch (syndromicity) {
      case 'predominantly_syndromic':
        return 'warning';
      case 'predominantly_id':
        return 'info';
      case 'mixed':
        return 'secondary';
      default:
        return 'light';
    }
  });

  /**
   * Syndromicity label for display
   */
  const syndromicityLabel = computed<string>(() => {
    const syndromicity = normalize(props.summary?.syndromicity);
    switch (syndromicity) {
      case 'predominantly_syndromic':
        return 'Syndromic';
      case 'predominantly_id':
        return 'ID-focused';
      case 'mixed':
        return 'Mixed';
      default:
        return 'Unknown';
    }
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
   * Judge verdict label for display
   */
  const judgeVerdictLabel = computed<string>(() => {
    const verdict = judgeVerdict.value;
    if (!verdict) return '';

    switch (verdict) {
      case 'accept':
        return 'Verified';
      case 'accept_with_corrections':
        return 'Verified';
      case 'low_confidence':
        return 'Review';
      case 'reject':
        return 'Rejected';
      default:
        return verdict;
    }
  });

  /**
   * Bootstrap variant for judge verdict badge
   */
  const judgeVerdictVariant = computed<LlmBadgeVariant>(() => {
    const verdict = judgeVerdict.value;
    switch (verdict) {
      case 'accept':
        return 'success';
      case 'accept_with_corrections':
        return 'success';
      case 'low_confidence':
        return 'warning';
      case 'reject':
        return 'danger';
      default:
        return 'secondary';
    }
  });

  /**
   * Tooltip for validation badge
   */
  const validatedTooltip = computed<string>(() => {
    const verdict = judgeVerdict.value;
    const reasoning = normalize(props.summary?.llm_judge_reasoning);

    let tooltip = '';

    switch (verdict) {
      case 'accept':
        tooltip = 'Content verified by AI judge';
        break;
      case 'accept_with_corrections':
        tooltip = 'Verified with minor corrections applied';
        break;
      case 'low_confidence':
        tooltip = 'Low confidence - manual review recommended';
        break;
      case 'reject':
        tooltip = 'Content rejected by AI judge';
        break;
      default:
        tooltip = 'Validation status';
    }

    if (reasoning) {
      tooltip += `\n\n${reasoning}`;
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
    hasSyndromicity,
    syndromicityVariant,
    syndromicityLabel,
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
