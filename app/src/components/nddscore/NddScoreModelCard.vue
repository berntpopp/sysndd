<template>
  <section class="nddscore-model-card" aria-labelledby="nddscore-model-card-title">
    <header class="nddscore-model-card__header">
      <div class="nddscore-model-card__title-wrap">
        <i class="bi bi-cpu nddscore-model-card__icon" aria-hidden="true" />
        <div>
          <h2 id="nddscore-model-card-title" class="nddscore-model-card__title">
            ML prediction - model card
          </h2>
          <p class="nddscore-model-card__subtitle">
            Current public NDDScore release metadata and held-out model performance.
          </p>
        </div>
      </div>
      <BBadge variant="info" class="nddscore-model-card__release">
        {{ releaseBadge }}
      </BBadge>
    </header>

    <div v-if="error" class="nddscore-model-card__fallback">
      No active NDDScore release is available.
    </div>

    <template v-else>
      <div class="nddscore-model-card__grid" aria-label="Test performance">
        <div
          v-for="metric in performanceMetrics"
          :key="metric.label"
          class="nddscore-model-card__metric"
        >
          <span class="nddscore-model-card__metric-label">{{ metric.label }}</span>
          <span class="nddscore-model-card__metric-value">{{ metric.value }}</span>
        </div>
      </div>

      <div class="nddscore-model-card__counts" aria-label="Release counts">
        <div v-for="count in counts" :key="count.label" class="nddscore-model-card__count">
          <span class="nddscore-model-card__count-label">{{ count.label }}</span>
          <span class="nddscore-model-card__count-value">{{ count.value }}</span>
        </div>
      </div>

      <dl class="nddscore-model-card__provenance">
        <div>
          <dt>Version</dt>
          <dd>{{ displayValue(release?.version) }}</dd>
        </div>
        <div>
          <dt>Version DOI</dt>
          <dd>
            <a
              v-if="versionDoi"
              :href="doiUrl(versionDoi)"
              target="_blank"
              rel="noopener noreferrer"
            >
              {{ versionDoi }}
            </a>
            <span v-else>NA</span>
          </dd>
        </div>
        <div>
          <dt>Concept DOI</dt>
          <dd>
            <a
              v-if="conceptDoi"
              :href="doiUrl(conceptDoi)"
              target="_blank"
              rel="noopener noreferrer"
            >
              {{ conceptDoi }}
            </a>
            <span v-else>NA</span>
          </dd>
        </div>
        <div>
          <dt>Zenodo record</dt>
          <dd>
            <a
              v-if="zenodoRecordUrl"
              :href="zenodoRecordUrl"
              target="_blank"
              rel="noopener noreferrer"
            >
              Record
            </a>
            <span v-else>NA</span>
          </dd>
        </div>
      </dl>

      <p class="nddscore-model-card__intended-use">
        NDDScore is a prioritization signal for model-derived review and discovery workflows. A high
        score is not proof of causality, is separate from curated SysNDD evidence, and is not an
        curated classification.
      </p>
    </template>
  </section>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { BBadge } from 'bootstrap-vue-next';
import { fetchCurrentRelease, type NddScoreReleaseRaw } from '@/api/nddscore';

defineOptions({
  name: 'NddScoreModelCard',
});

type ReleaseRecord = NddScoreReleaseRaw & {
  version?: unknown;
  version_doi?: unknown;
  concept_doi?: unknown;
  zenodo_record_url?: unknown;
  n_features?: unknown;
  ndd_performance_json?: unknown;
};

const release = ref<ReleaseRecord | null>(null);
const error = ref(false);

const releaseBadge = computed(() => scalarString(release.value?.release_id) ?? 'No active release');
const versionDoi = computed(() => scalarString(release.value?.version_doi));
const conceptDoi = computed(() => scalarString(release.value?.concept_doi));
const zenodoRecordUrl = computed(() => scalarString(release.value?.zenodo_record_url));

const performanceMetrics = computed(() => {
  const testMetrics = performanceTestMetrics(release.value?.ndd_performance_json);
  return [
    { label: 'AUC-ROC', value: formatDecimal(testMetrics.auc_roc) },
    { label: 'AUC-PR', value: formatDecimal(testMetrics.auc_pr) },
    { label: 'Brier', value: formatDecimal(testMetrics.brier) },
    { label: 'Brier Skill Score', value: formatDecimal(testMetrics.bss) },
  ];
});

const counts = computed(() => [
  { label: 'Genes', value: formatCount(release.value?.n_genes) },
  { label: 'Phenotype predictions', value: formatCount(release.value?.n_hpo_predictions) },
  { label: 'HPO terms', value: formatCount(release.value?.n_hpo_terms) },
  { label: 'Features', value: formatCount(release.value?.n_features) },
]);

function scalarValue(value: unknown): unknown {
  return Array.isArray(value) ? value[0] : value;
}

function scalarString(value: unknown): string | undefined {
  const normalized = scalarValue(value);
  return typeof normalized === 'string' && normalized.length > 0 ? normalized : undefined;
}

function scalarNumber(value: unknown): number | null {
  const normalized = scalarValue(value);
  const numberValue = typeof normalized === 'number' ? normalized : Number(normalized);
  return Number.isFinite(numberValue) ? numberValue : null;
}

function performanceTestMetrics(value: unknown): Record<string, unknown> {
  const normalized = scalarValue(value);
  let parsed: unknown = normalized;

  if (typeof normalized === 'string') {
    try {
      parsed = JSON.parse(normalized);
    } catch {
      parsed = {};
    }
  }

  if (!parsed || typeof parsed !== 'object') {
    return {};
  }

  const test = (parsed as Record<string, unknown>).test;
  return test && typeof test === 'object' ? (test as Record<string, unknown>) : {};
}

function formatDecimal(value: unknown): string {
  const numberValue = scalarNumber(value);
  return numberValue == null ? 'NA' : numberValue.toFixed(3);
}

function formatCount(value: unknown): string {
  const numberValue = scalarNumber(value);
  return numberValue == null ? 'NA' : String(Math.trunc(numberValue));
}

function displayValue(value: unknown): string {
  const normalized = scalarValue(value);
  if (normalized == null || normalized === '') {
    return 'NA';
  }
  return String(normalized);
}

function doiUrl(doi: string): string {
  return `https://doi.org/${doi}`;
}

onMounted(async () => {
  try {
    release.value = (await fetchCurrentRelease()) as ReleaseRecord;
  } catch {
    error.value = true;
  }
});
</script>

<style scoped>
.nddscore-model-card {
  display: grid;
  gap: 0.875rem;
  padding: 1rem;
  border: 1px solid #d7dee8;
  border-radius: var(--radius-lg, 8px);
  background: #fff;
  box-shadow: 0 1px 2px rgb(15 23 42 / 6%);
}

.nddscore-model-card__header {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-start;
  justify-content: space-between;
  gap: 0.75rem;
}

.nddscore-model-card__title-wrap {
  display: flex;
  align-items: flex-start;
  gap: 0.65rem;
}

.nddscore-model-card__icon {
  color: var(--medical-teal-600, #00897b);
  font-size: 1.1rem;
  line-height: 1.4;
}

.nddscore-model-card__title {
  margin: 0;
  color: var(--neutral-900, #212121);
  font-size: 1rem;
  font-weight: 700;
  line-height: 1.25;
}

.nddscore-model-card__subtitle,
.nddscore-model-card__intended-use,
.nddscore-model-card__fallback {
  margin: 0;
  color: var(--neutral-600, #757575);
  font-size: 0.875rem;
  line-height: 1.45;
}

.nddscore-model-card__release {
  max-width: 100%;
  overflow-wrap: anywhere;
}

.nddscore-model-card__grid,
.nddscore-model-card__counts {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(8.25rem, 1fr));
  gap: 0.5rem;
}

.nddscore-model-card__metric,
.nddscore-model-card__count {
  display: grid;
  gap: 0.15rem;
  min-width: 0;
  padding: 0.55rem 0.65rem;
  border: 1px solid #e1e7ef;
  border-radius: var(--radius-md, 6px);
  /* White background keeps --neutral-700 label text at ≥ 5.7:1 ✓ AA */
  background: #fff;
}

/* Label text: --neutral-700 (#616161) on #fff ≈ 5.7:1 ✓ AA
   (--neutral-600 #757575 is 4.54:1 on white but fails on tinted #f8fafc backgrounds) */
.nddscore-model-card__metric-label,
.nddscore-model-card__count-label,
.nddscore-model-card__provenance dt {
  color: var(--neutral-700, #616161);
  font-size: 0.75rem;
  font-weight: 700;
}

.nddscore-model-card__metric-value,
.nddscore-model-card__count-value {
  color: var(--neutral-900, #212121);
  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
  font-size: 1rem;
  font-weight: 700;
}

.nddscore-model-card__provenance {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(13rem, 1fr));
  gap: 0.5rem 0.75rem;
  margin: 0;
}

.nddscore-model-card__provenance div {
  min-width: 0;
}

.nddscore-model-card__provenance dt {
  margin: 0;
}

.nddscore-model-card__provenance dd {
  margin: 0.1rem 0 0;
  color: var(--neutral-900, #212121);
  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
  font-size: 0.8125rem;
  overflow-wrap: anywhere;
}

.nddscore-model-card__provenance a {
  color: var(--medical-blue-700, #0d47a1);
}
</style>
