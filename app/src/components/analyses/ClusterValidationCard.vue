<template>
  <section
    v-if="visible"
    class="cluster-validation-card"
    aria-labelledby="cluster-validation-card-title"
  >
    <header class="cluster-validation-card__header">
      <div class="cluster-validation-card__title-wrap">
        <i class="bi bi-diagram-3 cluster-validation-card__icon" aria-hidden="true" />
        <div>
          <h3 id="cluster-validation-card-title" class="cluster-validation-card__title">
            Cluster validation
          </h3>
          <p class="cluster-validation-card__subtitle">{{ subtitle }}</p>
        </div>
      </div>
      <div class="cluster-validation-card__release">
        <BBadge v-if="dbVersion" variant="info">DB {{ dbVersion }}</BBadge>
        <span v-if="builtOn" class="cluster-validation-card__built">built {{ builtOn }}</span>
      </div>
    </header>

    <div class="cluster-validation-card__grid" aria-label="Partition metrics">
      <div v-for="metric in metrics" :key="metric.label" class="cluster-validation-card__metric">
        <span class="cluster-validation-card__metric-label">{{ metric.label }}</span>
        <span class="cluster-validation-card__metric-value">
          {{ metric.value }}
          <small v-if="metric.hint" class="cluster-validation-card__metric-hint">{{
            metric.hint
          }}</small>
        </span>
      </div>
    </div>

    <div
      v-if="rows.length"
      class="cluster-validation-card__clusters"
      aria-label="Per-cluster stability"
    >
      <div class="cluster-validation-card__clusters-head">
        <span>Cluster</span>
        <span>Bootstrap-Jaccard stability</span>
      </div>
      <div v-for="row in rows" :key="row.id" class="cluster-validation-card__row">
        <span class="cluster-validation-card__row-id">
          Cluster {{ row.id }}
          <small v-if="row.size != null">· {{ row.size }} {{ unitLabel }}</small>
        </span>
        <div class="cluster-validation-card__bar-wrap">
          <div class="cluster-validation-card__bar-track">
            <div
              class="cluster-validation-card__bar-fill"
              :class="`cluster-validation-card__bar-fill--${row.band.key}`"
              :style="{ width: barWidth(row.jaccard) }"
            />
          </div>
          <span class="cluster-validation-card__row-metrics">
            <span
              class="cluster-validation-card__band"
              :class="`cluster-validation-card__band--${row.band.key}`"
              >{{ row.band.label }}</span
            >
            <span class="cluster-validation-card__jaccard">{{ fmt(row.jaccard) }}</span>
            <span v-if="row.silhouette != null" class="cluster-validation-card__sil">
              sil {{ fmt(row.silhouette) }}
            </span>
          </span>
        </div>
      </div>
    </div>

    <footer class="cluster-validation-card__footer">
      <ul class="cluster-validation-card__legend" aria-label="Stability bands">
        <li>
          <span class="cluster-validation-card__swatch cluster-validation-card__band--stable" />stable
          ≥0.75
        </li>
        <li>
          <span
            class="cluster-validation-card__swatch cluster-validation-card__band--doubtful"
          />doubtful 0.60–0.75
        </li>
        <li>
          <span class="cluster-validation-card__swatch cluster-validation-card__band--weak" />weak
          0.50–0.60
        </li>
        <li>
          <span
            class="cluster-validation-card__swatch cluster-validation-card__band--dissolved"
          />dissolved &lt;0.50
        </li>
      </ul>
      <p class="cluster-validation-card__method">
        <i class="bi bi-info-circle" aria-hidden="true" />
        {{ methodNote }}
        <span v-if="validationHashShort" class="cluster-validation-card__hash"
          >· {{ validationHashShort }}</span
        >
      </p>
    </footer>
  </section>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { BBadge } from 'bootstrap-vue-next';
import type { AnalysisSnapshotMeta } from '@/api/analysis';
import {
  summarizeValidation,
  perClusterStability,
  hasValidation,
  toScalarString,
  type ClusterAnalysisType,
} from './clusterValidation';

defineOptions({ name: 'ClusterValidationCard' });

const props = defineProps<{
  analysisType: ClusterAnalysisType;
  snapshotMeta: AnalysisSnapshotMeta | null;
  clusters: unknown[];
}>();

const validation = computed(() => props.snapshotMeta?.validation ?? null);
const visible = computed(() => hasValidation(validation.value));

const isPhenotype = computed(() => props.analysisType === 'phenotype_clusters');
const unitLabel = computed(() => (isPhenotype.value ? 'entities' : 'genes'));
const subtitle = computed(() =>
  isPhenotype.value
    ? 'Data-driven k (MCA/HCPC); per-cluster reproducibility from bootstrap subsampling.'
    : 'Weighted Leiden run to convergence; per-cluster reproducibility from bootstrap subsampling.',
);

const metrics = computed(() => summarizeValidation(props.analysisType, validation.value));
const rows = computed(() => perClusterStability(props.clusters as never));

const dbVersion = computed(() => toScalarString(props.snapshotMeta?.db_release?.version));
const builtOn = computed(() => {
  const raw = toScalarString(props.snapshotMeta?.generated_at);
  return raw ? raw.slice(0, 10) : null;
});
const validationHashShort = computed(() => {
  const h = toScalarString(props.snapshotMeta?.validation_hash);
  return h ? `validation ${h.slice(0, 8)}` : null;
});
const methodNote =
  'Stability = bootstrap-Jaccard over subsamples (Hennig bands). Read stable/highly-stable clusters with confidence; treat weak/dissolved clusters cautiously.';

function fmt(value: number | null): string {
  return value == null ? 'n/a' : value.toFixed(3);
}
function barWidth(value: number | null): string {
  const pct = value == null ? 0 : Math.max(0, Math.min(1, value)) * 100;
  return `${pct}%`;
}
</script>

<style scoped>
.cluster-validation-card {
  display: grid;
  gap: 0.875rem;
  padding: 1rem;
  margin-top: 0.75rem;
  border: 1px solid #d7dee8;
  border-radius: var(--radius-lg, 8px);
  background: #fff;
  box-shadow: 0 1px 2px rgb(15 23 42 / 6%);
}

.cluster-validation-card__header {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-start;
  justify-content: space-between;
  gap: 0.75rem;
}

.cluster-validation-card__title-wrap {
  display: flex;
  align-items: flex-start;
  gap: 0.65rem;
}

.cluster-validation-card__icon {
  color: var(--medical-teal-600, #00897b);
  font-size: 1.1rem;
  line-height: 1.4;
}

.cluster-validation-card__title {
  margin: 0;
  color: var(--neutral-900, #212121);
  font-size: 1rem;
  font-weight: 700;
  line-height: 1.25;
}

.cluster-validation-card__subtitle {
  margin: 0;
  color: var(--neutral-600, #757575);
  font-size: 0.875rem;
  line-height: 1.45;
}

.cluster-validation-card__release {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 0.2rem;
}

.cluster-validation-card__built {
  color: var(--neutral-600, #757575);
  font-size: 0.75rem;
}

.cluster-validation-card__grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(9rem, 1fr));
  gap: 0.5rem;
}

.cluster-validation-card__metric {
  display: grid;
  gap: 0.15rem;
  min-width: 0;
  padding: 0.55rem 0.65rem;
  border: 1px solid #e1e7ef;
  border-radius: var(--radius-md, 6px);
  background: #fff;
}

.cluster-validation-card__metric-label {
  color: var(--neutral-700, #616161);
  font-size: 0.75rem;
  font-weight: 700;
}

.cluster-validation-card__metric-value {
  color: var(--neutral-900, #212121);
  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
  font-size: 1rem;
  font-weight: 700;
}

.cluster-validation-card__metric-hint {
  display: block;
  color: var(--neutral-600, #757575);
  font-family: inherit;
  font-size: 0.7rem;
  font-weight: 400;
}

.cluster-validation-card__clusters {
  display: grid;
  gap: 0.35rem;
  max-height: 22rem;
  overflow-y: auto;
}

.cluster-validation-card__clusters-head {
  display: grid;
  grid-template-columns: minmax(9rem, 1fr) 2fr;
  gap: 0.75rem;
  color: var(--neutral-700, #616161);
  font-size: 0.7rem;
  font-weight: 700;
  text-transform: uppercase;
  letter-spacing: 0.02em;
}

.cluster-validation-card__row {
  display: grid;
  grid-template-columns: minmax(9rem, 1fr) 2fr;
  align-items: center;
  gap: 0.75rem;
}

.cluster-validation-card__row-id {
  color: var(--neutral-900, #212121);
  font-size: 0.8125rem;
  font-weight: 600;
}

.cluster-validation-card__row-id small {
  color: var(--neutral-600, #757575);
  font-weight: 400;
}

.cluster-validation-card__bar-wrap {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  min-width: 0;
}

.cluster-validation-card__bar-track {
  position: relative;
  flex: 1 1 auto;
  min-width: 3rem;
  height: 0.55rem;
  border-radius: 999px;
  background: #eef2f7;
  overflow: hidden;
}

.cluster-validation-card__bar-fill {
  height: 100%;
  border-radius: 999px;
}

.cluster-validation-card__row-metrics {
  display: inline-flex;
  align-items: center;
  gap: 0.4rem;
  flex: 0 0 auto;
  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
  font-size: 0.75rem;
}

.cluster-validation-card__band {
  padding: 0.05rem 0.4rem;
  border-radius: 999px;
  color: #fff;
  font-family: var(--font-family-base, system-ui, sans-serif);
  font-size: 0.7rem;
  font-weight: 700;
  white-space: nowrap;
}

.cluster-validation-card__jaccard {
  color: var(--neutral-900, #212121);
  font-weight: 700;
}

.cluster-validation-card__sil {
  color: var(--neutral-600, #757575);
}

/* Band colors — vivid fill + AA-contrast chip text (white on each). */
.cluster-validation-card__band--highly_stable,
.cluster-validation-card__band--stable {
  background: #2e7d32;
}
.cluster-validation-card__band--doubtful {
  background: #b26a00;
}
.cluster-validation-card__band--weak {
  background: #d84315;
}
.cluster-validation-card__band--dissolved {
  background: #c62828;
}
.cluster-validation-card__band--na {
  background: #757575;
}

.cluster-validation-card__bar-fill--highly_stable,
.cluster-validation-card__bar-fill--stable {
  background: #2e7d32;
}
.cluster-validation-card__bar-fill--doubtful {
  background: #b26a00;
}
.cluster-validation-card__bar-fill--weak {
  background: #d84315;
}
.cluster-validation-card__bar-fill--dissolved {
  background: #c62828;
}
.cluster-validation-card__bar-fill--na {
  background: #9aa4b2;
}

.cluster-validation-card__footer {
  display: grid;
  gap: 0.4rem;
  border-top: 1px solid #eef2f7;
  padding-top: 0.65rem;
}

.cluster-validation-card__legend {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem 0.9rem;
  margin: 0;
  padding: 0;
  list-style: none;
  color: var(--neutral-700, #616161);
  font-size: 0.72rem;
}

.cluster-validation-card__legend li {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
}

.cluster-validation-card__swatch {
  display: inline-block;
  width: 0.7rem;
  height: 0.7rem;
  border-radius: 3px;
}

.cluster-validation-card__method {
  margin: 0;
  color: var(--neutral-600, #757575);
  font-size: 0.72rem;
  line-height: 1.45;
}

.cluster-validation-card__hash {
  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
}

/* Narrow viewports: stack each cluster row (label above a full-width bar + metrics)
   so the band chip and Jaccard value never clip or force horizontal scroll. */
@media (max-width: 560px) {
  .cluster-validation-card__clusters-head {
    display: none;
  }

  .cluster-validation-card__row {
    grid-template-columns: 1fr;
    gap: 0.25rem;
    padding: 0.4rem 0;
    border-bottom: 1px solid #f1f5f9;
  }

  .cluster-validation-card__row:last-child {
    border-bottom: 0;
  }

  .cluster-validation-card__row-metrics {
    flex-wrap: wrap;
  }
}
</style>
