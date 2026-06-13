<template>
  <BCard class="ndd-score-card ndd-score-card--ml-disclosure" no-body>
    <template #header>
      <div class="ndd-score-card__header">
        <span class="ndd-score-card__label">
          <i class="bi bi-stars" aria-hidden="true"></i>
          <span>ML prediction</span>
        </span>
        <span class="ndd-score-card__disclosure">Machine learning, not manual curation</span>
        <BBadge v-if="releaseId" class="ndd-score-card__release" variant="light">
          {{ releaseId }}
        </BBadge>
      </div>
    </template>

    <div class="ndd-score-card__body">
      <p class="ndd-score-card__disclaimer">
        NDDScore is a model-derived prediction layer. It is not curated SysNDD evidence, not a
        SysNDD curation decision, and not part of curated classification.
      </p>

      <dl v-if="metrics.length" class="ndd-score-card__metrics">
        <div v-for="metric in metrics" :key="metric.label" class="ndd-score-card__metric">
          <dt>{{ metric.label }}</dt>
          <dd>{{ metric.value }}</dd>
        </div>
      </dl>

      <div v-if="releaseId || versionDoi" class="ndd-score-card__provenance">
        <span v-if="releaseId" class="ndd-score-card__provenance-id">{{ releaseId }}</span>
        <a v-if="versionDoi" :href="doiUrl" target="_blank" rel="noopener noreferrer">
          {{ versionDoi }}
        </a>
      </div>
    </div>
  </BCard>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { BBadge, BCard } from 'bootstrap-vue-next';

const props = defineProps<{
  releaseId?: string;
  versionDoi?: string;
  testAucRoc?: number | null;
  brierSkillScore?: number | null;
}>();

const formatMetric = (value: number) => value.toFixed(3);

const metrics = computed(() => {
  const items: Array<{ label: string; value: string }> = [];

  if (props.testAucRoc != null) {
    items.push({ label: 'Test AUC-ROC', value: formatMetric(props.testAucRoc) });
  }

  if (props.brierSkillScore != null) {
    items.push({ label: 'Brier Skill Score', value: formatMetric(props.brierSkillScore) });
  }

  return items;
});

const doiUrl = computed(() => (props.versionDoi ? `https://doi.org/${props.versionDoi}` : ''));
</script>

<style scoped>
.ndd-score-card {
  border-color: var(--bs-border-color);
  border-radius: var(--radius-lg, 8px);
  color: var(--neutral-900, #212121);
  box-shadow: 0 1px 2px rgb(33 37 41 / 6%);
}

.ndd-score-card--ml-disclosure {
  border-left: 3px solid #e65c00;
  background-color: var(--status-warning-bg, #fff3e0);
}

.ndd-score-card :deep(.card-header) {
  padding: 0.5rem 0.75rem;
  background: transparent;
  border-bottom-color: var(--bs-border-color-translucent, var(--bs-border-color));
}

.ndd-score-card__header {
  display: flex;
  align-items: center;
  justify-content: flex-start;
  gap: 0.5rem;
  min-width: 0;
  flex-wrap: wrap;
}

.ndd-score-card__label {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  padding: 0.125rem 0.5rem;
  border-radius: var(--radius-sm, 4px);
  /* #7a3400 on #fff3e0 ≈ 5.4:1 ✓ AA */
  background: var(--status-warning-bg, #fff3e0);
  color: #7a3400;
  font-size: 0.875rem;
  font-weight: 600;
}

.ndd-score-card__label .bi {
  color: #b84d00;
}

.ndd-score-card__disclosure {
  color: var(--neutral-900, #212121);
  font-size: 0.875rem;
  font-weight: 600;
  line-height: 1.25;
}

.ndd-score-card__release {
  margin-left: auto;
  max-width: 16rem;
  overflow: hidden;
  /* #616161 on white/light ≈ 5.7:1 ✓ AA */
  color: var(--neutral-700, #616161);
  text-overflow: ellipsis;
  white-space: nowrap;
  border: 1px solid var(--bs-border-color);
  border-radius: var(--radius-full, 999px);
  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
  font-weight: 500;
}

.ndd-score-card__body {
  display: grid;
  gap: 0.75rem;
  padding: 0.75rem;
}

.ndd-score-card__disclaimer {
  margin: 0;
  color: var(--neutral-900, #212121);
  font-size: 0.875rem;
  line-height: 1.45;
}

.ndd-score-card__metrics {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  margin: 0;
}

.ndd-score-card__metric {
  display: grid;
  min-width: 9.5rem;
  padding: 0.45rem 0.55rem;
  border: 1px solid var(--bs-border-color);
  border-radius: var(--radius-md, 6px);
  background: var(--bs-white, #fff);
}

.ndd-score-card__metric dt {
  /* #424242 on white ≈ 9.7:1 ✓ AAA — was #757575 which is only 4.6:1 at 12px small text */
  color: var(--neutral-800, #424242);
  font-size: 0.75rem;
  font-weight: 600;
  line-height: 1.2;
}

.ndd-score-card__metric dd {
  margin: 0;
  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
  font-size: 1rem;
  font-weight: 600;
  line-height: 1.3;
}

.ndd-score-card__provenance {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.5rem;
  /* #616161 on #fff3e0 ≈ 4.7:1 ✓ AA */
  color: var(--neutral-700, #616161);
  font-size: 0.8125rem;
}

.ndd-score-card__provenance-id {
  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
}

.ndd-score-card__provenance a {
  color: var(--medical-blue-700, #0d47a1);
  text-decoration-thickness: 1px;
  text-underline-offset: 2px;
}

@media (max-width: 575.98px) {
  .ndd-score-card__release {
    margin-left: 0;
  }
}
</style>
