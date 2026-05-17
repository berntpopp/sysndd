<template>
  <BCard class="ndd-score-card" no-body>
    <template #header>
      <div class="ndd-score-card__header">
        <span class="ndd-score-card__label">
          <i class="bi bi-cpu" aria-hidden="true"></i>
          <span>ML prediction</span>
        </span>
        <BBadge v-if="releaseId" class="ndd-score-card__release" variant="light">
          {{ releaseId }}
        </BBadge>
      </div>
    </template>

    <div class="ndd-score-card__body">
      <p class="ndd-score-card__disclaimer">
        NDDScore is a model-derived prediction layer. It is not curated SysNDD evidence, not a
        manual review, and not an evidence-tier assignment.
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

.ndd-score-card :deep(.card-header) {
  padding: 0.5rem 0.75rem;
  background: var(--bs-light, #f8f9fa);
  border-bottom-color: var(--bs-border-color);
}

.ndd-score-card__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.5rem;
}

.ndd-score-card__label {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  font-size: 0.875rem;
  font-weight: 600;
}

.ndd-score-card__label .bi {
  color: var(--medical-teal-600, #00897b);
}

.ndd-score-card__release {
  max-width: 16rem;
  overflow: hidden;
  color: var(--neutral-600, #757575);
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
  color: var(--neutral-600, #757575);
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
  color: var(--neutral-600, #757575);
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
</style>
