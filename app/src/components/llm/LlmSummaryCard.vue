<!-- src/components/llm/LlmSummaryCard.vue -->
<template>
  <BCard v-if="summary" class="llm-summary-card mb-3">
    <!-- Header: AI disclosure with inline verification status -->
    <template #header>
      <div class="d-flex align-items-center justify-content-between">
        <div class="d-flex align-items-center">
          <span class="ai-indicator me-2">
            <i class="bi bi-stars text-warning" />
            <span class="ai-label">AI</span>
          </span>
          <span class="header-title">
            Summary<span v-if="clusterNumber" class="text-muted fw-normal">
              — Cluster {{ clusterNumber }}</span
            >
          </span>
        </div>
        <!-- Verification badge inline with header -->
        <div class="d-flex align-items-center gap-2">
          <BBadge
            v-if="judgeVerdict"
            v-b-tooltip.hover.left="validatedTooltip"
            :variant="judgeVerdictVariant"
            class="verification-badge"
            pill
          >
            <i v-if="judgeVerdict === 'accept'" class="bi bi-check-circle-fill me-1" />
            <i
              v-else-if="judgeVerdict === 'accept_with_corrections'"
              class="bi bi-check2-circle me-1"
            />
            <i
              v-else-if="judgeVerdict === 'low_confidence'"
              class="bi bi-exclamation-triangle me-1"
            />
            <i v-else-if="judgeVerdict === 'reject'" class="bi bi-x-circle me-1" />
            {{ judgeVerdictLabel }}
          </BBadge>
          <span v-else-if="validationStatus === 'pending'" class="pending-badge">
            <i class="bi bi-hourglass-split text-warning" />
          </span>
        </div>
      </div>
    </template>

    <!-- Body: Left-aligned content with clear sections -->
    <div class="card-body-content">
      <!-- Summary text -->
      <p class="summary-text">{{ normalizedSummary?.summary }}</p>

      <!-- Tags section -->
      <div v-if="hasTags" class="tags-section">
        <div class="tags-container">
          <BBadge v-for="tag in summary.tags" :key="tag" variant="light" class="tag-badge">
            {{ tag }}
          </BBadge>
        </div>
      </div>

      <!-- Key themes (if present) -->
      <div v-if="hasKeyThemes" class="themes-section">
        <span class="section-label">Key themes</span>
        <div class="themes-container">
          <BBadge
            v-for="theme in summary.key_themes"
            :key="theme"
            variant="secondary"
            class="theme-badge"
          >
            {{ theme }}
          </BBadge>
        </div>
      </div>

      <!-- Pathways (if present) -->
      <div v-if="hasPathways" class="pathways-section">
        <span class="section-label">Pathways</span>
        <div class="pathways-container">
          <BBadge
            v-for="pathway in summary.pathways"
            :key="pathway"
            variant="info"
            class="pathway-badge"
          >
            {{ pathway }}
          </BBadge>
        </div>
      </div>

      <!-- Inheritance patterns (if present) -->
      <div v-if="hasInheritancePatterns" class="inheritance-section">
        <span class="section-label">Inheritance</span>
        <div class="inheritance-container">
          <BBadge
            v-for="pattern in summary.inheritance_patterns"
            :key="pattern"
            v-b-tooltip.hover.top="getInheritanceTooltip(pattern)"
            variant="primary"
            class="inheritance-badge"
          >
            {{ pattern }}
          </BBadge>
        </div>
      </div>

      <!-- Syndromicity (if present) -->
      <div v-if="hasSyndromicity" class="syndromicity-section">
        <span class="section-label">Pattern</span>
        <BBadge :variant="syndromicityVariant" class="syndromicity-badge">
          {{ syndromicityLabel }}
        </BBadge>
      </div>

      <!-- Clinical relevance (if present) -->
      <div v-if="normalizedSummary?.clinical_relevance" class="clinical-section">
        <span class="section-label">Clinical relevance</span>
        <p class="clinical-text">{{ normalizedSummary.clinical_relevance }}</p>
      </div>
    </div>

    <!-- Footer: Clean provenance line -->
    <template #footer>
      <div class="footer-content">
        <span class="provenance-text">
          <i class="bi bi-robot me-1" />
          {{ modelName }}
          <span class="separator">·</span>
          {{ formattedDate }}
          <span v-if="hasCorrections" class="corrections-indicator">
            <span class="separator">·</span>
            <i
              v-b-tooltip.hover.top="correctionsTooltip"
              class="bi bi-pencil-square text-info cursor-pointer"
            />
          </span>
        </span>
      </div>
    </template>
  </BCard>
</template>

<script lang="ts">
import { defineComponent, computed } from 'vue';
import type { PropType } from 'vue';
import { format } from 'date-fns';

/**
 * Interface for derived confidence from enrichment analysis
 */
interface DerivedConfidence {
  score: 'high' | 'medium' | 'low';
  avg_fdr: number;
  term_count: number;
}

/**
 * Interface for the summary JSON structure from the LLM
 */
interface SummaryJson {
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

export default defineComponent({
  name: 'LlmSummaryCard',

  props: {
    /**
     * The structured summary data from the LLM
     */
    summary: {
      type: Object as PropType<SummaryJson | null>,
      default: null,
    },
    /**
     * Name of the model that generated the summary
     */
    modelName: {
      type: String,
      required: true,
    },
    /**
     * ISO date string when the summary was created
     */
    createdAt: {
      type: String,
      required: true,
    },
    /**
     * Validation status: 'pending', 'validated', or 'rejected'
     */
    validationStatus: {
      type: String as PropType<'pending' | 'validated' | 'rejected'>,
      default: 'pending',
    },
    /**
     * Cluster number for display in header
     */
    clusterNumber: {
      type: Number,
      default: null,
    },
  },

  setup(props) {
    // Helper to normalize R JSON values (single values come as arrays)
    const normalize = <T,>(val: T | T[] | undefined): T | undefined => {
      if (val === undefined) return undefined;
      return Array.isArray(val) ? val[0] : val;
    };

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
    type BadgeVariant =
      | 'primary'
      | 'secondary'
      | 'success'
      | 'danger'
      | 'warning'
      | 'info'
      | 'light'
      | 'dark';
    const syndromicityVariant = computed<BadgeVariant>(() => {
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
    const judgeVerdictVariant = computed<BadgeVariant>(() => {
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
  },
});
</script>

<style scoped>
.llm-summary-card {
  border: 1px solid var(--bs-border-color);
  border-left: 4px solid var(--bs-warning);
  border-radius: 8px;
  background: linear-gradient(to bottom, #fffbf0 0%, #ffffff 100%);
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.08);
}

.llm-summary-card :deep(.card-header) {
  background: transparent;
  border-bottom: 1px solid var(--bs-border-color-translucent);
  padding: 0.75rem 1rem;
}

.llm-summary-card :deep(.card-body) {
  padding: 1rem;
}

.llm-summary-card :deep(.card-footer) {
  background: transparent;
  border-top: 1px solid var(--bs-border-color-translucent);
  padding: 0.5rem 1rem;
}

/* Header styles */
.ai-indicator {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  padding: 0.125rem 0.5rem;
  background: rgba(255, 193, 7, 0.15);
  border-radius: 4px;
  font-size: 0.75rem;
}

.ai-label {
  font-weight: 600;
  color: var(--bs-warning);
  text-transform: uppercase;
  letter-spacing: 0.5px;
}

.header-title {
  font-weight: 600;
  font-size: 0.95rem;
  color: var(--bs-body-color);
}

.verification-badge {
  font-size: 0.75rem;
  font-weight: 500;
}

.pending-badge {
  font-size: 0.875rem;
}

/* Body content styles */
.card-body-content {
  text-align: left;
}

.summary-text {
  font-size: 0.925rem;
  line-height: 1.65;
  color: var(--bs-body-color);
  margin-bottom: 1rem;
}

/* Tags section */
.tags-section {
  margin-bottom: 0.75rem;
}

.tags-container {
  display: flex;
  flex-wrap: wrap;
  gap: 0.375rem;
}

.tag-badge {
  font-size: 0.8rem;
  font-weight: 500;
  padding: 0.25rem 0.625rem;
  border: 1px solid var(--bs-border-color);
  background: var(--bs-white);
  color: var(--bs-body-color);
}

/* Section labels */
.section-label {
  display: block;
  font-size: 0.75rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.5px;
  color: var(--bs-secondary);
  margin-bottom: 0.375rem;
}

/* Themes section */
.themes-section {
  margin-bottom: 0.75rem;
}

.themes-container {
  display: flex;
  flex-wrap: wrap;
  gap: 0.375rem;
}

.theme-badge {
  font-size: 0.8rem;
  font-weight: 500;
}

/* Pathways section */
.pathways-section {
  margin-bottom: 0.75rem;
}

.pathways-container {
  display: flex;
  flex-wrap: wrap;
  gap: 0.375rem;
}

.pathway-badge {
  font-size: 0.8rem;
  font-weight: 500;
}

/* Inheritance section */
.inheritance-section {
  margin-bottom: 0.75rem;
}

.inheritance-container {
  display: flex;
  flex-wrap: wrap;
  gap: 0.375rem;
}

.inheritance-badge {
  font-size: 0.8rem;
  font-weight: 600;
  cursor: help;
}

/* Syndromicity section */
.syndromicity-section {
  margin-bottom: 0.75rem;
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.syndromicity-badge {
  font-size: 0.8rem;
  font-weight: 500;
}

/* Clinical section */
.clinical-section {
  margin-top: 0.75rem;
  padding-top: 0.75rem;
  border-top: 1px solid var(--bs-border-color-translucent);
}

.clinical-text {
  font-size: 0.875rem;
  color: var(--bs-secondary);
  margin-bottom: 0;
}

/* Footer styles */
.footer-content {
  text-align: left;
}

.provenance-text {
  font-size: 0.8rem;
  color: var(--bs-secondary);
}

.separator {
  margin: 0 0.375rem;
  color: var(--bs-border-color);
}

.corrections-indicator {
  display: inline;
}

.cursor-pointer {
  cursor: pointer;
}
</style>
