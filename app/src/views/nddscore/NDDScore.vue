<template>
  <AnalysisShell title="NDDScore" :subtitle="subtitle" nav-label="NDDScore views" :tabs="tabs">
    <template #meta>
      <span class="nddscore-meta-badge">
        <i class="bi bi-cpu" aria-hidden="true"></i>
        <span>ML prediction layer</span>
      </span>
    </template>

    <div class="nddscore-shell">
      <NddScorePredictionCard
        :release-id="releaseId"
        :version-doi="versionDoi"
        :test-auc-roc="testAucRoc"
        :brier-skill-score="brierSkillScore"
      />
      <RouterView />
    </div>
  </AnalysisShell>
</template>

<script setup lang="ts">
import { onMounted, ref } from 'vue';
import AnalysisShell from '@/components/analyses/AnalysisShell.vue';
import NddScorePredictionCard from '@/components/nddscore/NddScorePredictionCard.vue';
import { fetchCurrentRelease } from '@/api/nddscore';

defineOptions({
  name: 'NDDScore',
});

const subtitle =
  'Machine-learning predictions for NDD gene association and phenotype annotations. These predictions are separate from curated SysNDD evidence.';

const tabs = [
  { label: 'Gene predictions', to: { name: 'NDDScore' } },
  { label: 'Phenotype predictions', to: { name: 'NDDScorePhenotypePredictions' } },
  { label: 'Model card', to: { name: 'NDDScoreModelCard' } },
];

const releaseId = ref<string>();
const versionDoi = ref<string>();
const testAucRoc = ref<number | null>(null);
const brierSkillScore = ref<number | null>(null);

function scalarString(value: unknown): string | undefined {
  const normalized = Array.isArray(value) ? value[0] : value;
  return typeof normalized === 'string' && normalized.length > 0 ? normalized : undefined;
}

function scalarNumber(value: unknown): number | null {
  const normalized = Array.isArray(value) ? value[0] : value;
  const numberValue = typeof normalized === 'number' ? normalized : Number(normalized);
  return Number.isFinite(numberValue) ? numberValue : null;
}

function parsePerformance(value: unknown): Record<string, unknown> {
  const normalized = Array.isArray(value) ? value[0] : value;
  if (typeof normalized === 'string') {
    try {
      const parsed = JSON.parse(normalized);
      return parsed && typeof parsed === 'object' ? (parsed as Record<string, unknown>) : {};
    } catch {
      return {};
    }
  }
  return normalized && typeof normalized === 'object' ? (normalized as Record<string, unknown>) : {};
}

onMounted(async () => {
  try {
    const release = await fetchCurrentRelease();
    releaseId.value = scalarString(release.release_id);
    versionDoi.value = scalarString(release.version_doi);

    const performance = parsePerformance(release.ndd_performance_json);
    const testMetrics =
      performance.test && typeof performance.test === 'object'
        ? (performance.test as Record<string, unknown>)
        : {};
    testAucRoc.value = scalarNumber(testMetrics.auc_roc);
    brierSkillScore.value = scalarNumber(testMetrics.bss);
  } catch {
    // No active release: keep the prediction card visible with its disclaimer only.
  }
});
</script>

<style scoped>
.nddscore-meta-badge {
  display: inline-flex;
  flex: 0 0 auto;
  align-items: center;
  gap: 0.35rem;
  min-height: 1.55rem;
  padding: 0.2rem 0.55rem;
  border: 1px solid #bdc7d4;
  border-radius: var(--radius-full, 999px);
  background: #eef2f7;
  color: #223044;
  font-size: 0.75rem;
  font-weight: 700;
  white-space: nowrap;
}

.nddscore-meta-badge .bi {
  color: var(--medical-teal-600, #00897b);
}

.nddscore-shell {
  display: grid;
  gap: 1rem;
}
</style>
