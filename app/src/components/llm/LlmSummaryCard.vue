<!-- src/components/llm/LlmSummaryCard.vue -->
<template>
  <BCard v-if="summary" class="llm-summary-card mb-3">
    <!-- Header: AI disclosure with inline verification status -->
    <template #header>
      <div class="d-flex align-items-center justify-content-between flex-wrap gap-2">
        <div class="d-flex align-items-center flex-wrap gap-2">
          <span class="ai-indicator" aria-label="AI-generated summary">
            <i class="bi bi-stars" aria-hidden="true" />
            <span class="ai-label">AI</span>
          </span>
          <span class="header-title">
            {{ title }}<span v-if="clusterNumber" class="text-muted fw-normal">
              — Cluster {{ clusterNumber }}</span
            >
          </span>
          <span class="ai-disclosure d-none d-md-inline-block text-muted">
            · Automated summary, not manual curation
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
            <i v-if="judgeVerdict === 'accept'" class="bi bi-shield-check me-1" />
            <i
              v-else-if="judgeVerdict === 'accept_with_corrections'"
              class="bi bi-shield-check me-1"
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

      <!-- #630: the "Pattern" badge rendered `summary.syndromicity`, a
           model-generated label that was not reproducible on identical input.
           It is now computed from curated annotations and rendered by
           SyndromicityCard.vue, outside this AI-provenance card. -->
      <div v-if="normalizedSummary?.clinical_pattern" class="syndromicity-section">
        <span class="section-label">Suggested category</span>
        <BBadge variant="secondary" class="syndromicity-badge">
          {{ normalizedSummary.clinical_pattern }}
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
import { defineComponent } from 'vue';
import type { PropType } from 'vue';
import { useLlmSummaryCard, type SummaryJson } from './useLlmSummaryCard';

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
    /**
     * Card title label (default 'Summary')
     */
    title: {
      type: String,
      default: 'Summary',
    },
  },

  setup(props) {
    return useLlmSummaryCard(props);
  },
});
</script>

<style scoped>
.llm-summary-card {
  border: 1px solid var(--bs-border-color);
  border-radius: var(--radius-lg, 8px);
  background: var(--bs-body-bg, #ffffff);
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.04);
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

/* Header styles: AI provenance clearly styled matching NDDScore */
.ai-indicator {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  padding: 0.15rem 0.5rem;
  background: var(--status-warning-bg, #fff3e0);
  border: 1px solid rgba(184, 77, 0, 0.25);
  border-radius: var(--radius-sm, 4px);
  font-size: 0.75rem;
  line-height: 1.2;
}

.ai-indicator .bi {
  color: #b84d00;
  font-size: 0.8rem;
}

.ai-label {
  font-weight: 700;
  color: #7a3400;
  letter-spacing: 0.5px;
  text-transform: uppercase;
}

.header-title {
  font-weight: 600;
  font-size: 0.95rem;
  color: var(--bs-body-color);
}

.ai-disclosure {
  font-size: 0.75rem;
  font-weight: 500;
  color: var(--neutral-600, #616161);
}

.verification-badge {
  font-size: 0.75rem;
  font-weight: 600;
  padding: 0.25rem 0.55rem;
  border: 1px solid var(--border-subtle, #d9e0ea);
  background: var(--neutral-100, #f5f5f5);
  color: var(--neutral-800, #333333);
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
