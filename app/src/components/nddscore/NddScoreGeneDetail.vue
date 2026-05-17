<template>
  <section class="ndd-gene-detail" aria-labelledby="ndd-gene-detail-title">
    <header class="ndd-gene-detail__header">
      <div>
        <p class="ndd-gene-detail__eyebrow">NDDScore gene prediction</p>
        <h2 id="ndd-gene-detail-title" class="ndd-gene-detail__title">
          {{ geneSymbol }}
        </h2>
        <p v-if="hgncId" class="ndd-gene-detail__meta">{{ hgncId }}</p>
      </div>

      <BBadge class="ndd-gene-detail__prediction-badge" variant="info">
        <i class="bi bi-cpu" aria-hidden="true"></i>
        <span>ML prediction</span>
      </BBadge>
    </header>

    <p v-if="!loaded" class="ndd-gene-detail__fallback">Loading gene prediction.</p>

    <template v-else-if="gene">
      <section class="ndd-gene-detail__panel" aria-labelledby="ndd-gene-detail-summary">
        <h3 id="ndd-gene-detail-summary" class="ndd-gene-detail__section-title">
          Prediction summary
        </h3>
        <dl class="ndd-gene-detail__metrics">
          <div class="ndd-gene-detail__metric">
            <dt>NDD score</dt>
            <dd>{{ formatScore(readField(gene, 'ndd_score', 'score')) }}</dd>
          </div>
          <div class="ndd-gene-detail__metric">
            <dt>Rank</dt>
            <dd>{{ displayValue(readField(gene, 'rank', 'gene_rank')) }}</dd>
          </div>
          <div class="ndd-gene-detail__metric">
            <dt>Risk tier</dt>
            <dd>
              <BBadge :variant="riskVariant(readField(gene, 'risk_tier'))">
                {{ displayValue(readField(gene, 'risk_tier')) }}
              </BBadge>
            </dd>
          </div>
          <div class="ndd-gene-detail__metric">
            <dt>Confidence</dt>
            <dd>
              <BBadge :variant="confidenceVariant(readField(gene, 'confidence_tier'))">
                {{ displayValue(readField(gene, 'confidence_tier')) }}
              </BBadge>
            </dd>
          </div>
        </dl>
      </section>

      <section class="ndd-gene-detail__panel" aria-labelledby="ndd-gene-detail-inheritance">
        <h3 id="ndd-gene-detail-inheritance" class="ndd-gene-detail__section-title">
          Inheritance probabilities
        </h3>
        <dl class="ndd-gene-detail__compact-grid">
          <div v-for="mode in inheritanceModes" :key="mode.key" class="ndd-gene-detail__compact">
            <dt>{{ mode.label }}</dt>
            <dd>{{ formatProbability(mode.value) }}</dd>
          </div>
        </dl>
      </section>

      <section class="ndd-gene-detail__panel" aria-labelledby="ndd-gene-detail-hpo">
        <h3 id="ndd-gene-detail-hpo" class="ndd-gene-detail__section-title">
          Top predicted HPO terms
        </h3>
        <ul v-if="hpoPredictions.length" class="ndd-gene-detail__list">
          <li v-for="term in hpoPredictions" :key="term.key" class="ndd-gene-detail__list-row">
            <span class="ndd-gene-detail__list-main">{{ term.name }}</span>
            <span class="ndd-gene-detail__list-meta">
              {{ term.id }} &middot; {{ formatProbability(term.probability) }}
            </span>
          </li>
        </ul>
        <p v-else class="ndd-gene-detail__fallback">No HPO predictions available.</p>
      </section>

      <section class="ndd-gene-detail__panel" aria-labelledby="ndd-gene-detail-shap">
        <h3 id="ndd-gene-detail-shap" class="ndd-gene-detail__section-title">
          SHAP group contributions
        </h3>
        <dl v-if="shapGroups.length" class="ndd-gene-detail__compact-grid">
          <div v-for="group in shapGroups" :key="group.label" class="ndd-gene-detail__compact">
            <dt>{{ group.label }}</dt>
            <dd>{{ formatSigned(group.value) }}</dd>
          </div>
        </dl>
        <p v-else class="ndd-gene-detail__fallback">No SHAP group contributions available.</p>
      </section>

      <section class="ndd-gene-detail__curated" aria-labelledby="ndd-gene-detail-curated">
        <div>
          <h3 id="ndd-gene-detail-curated" class="ndd-gene-detail__section-title">
            Curated SysNDD evidence
          </h3>
          <p>
            The curated SysNDD record is separate from the NDDScore prediction and should be read as
            a distinct evidence source.
          </p>
        </div>
        <RouterLink v-if="hgncId" class="ndd-gene-detail__curated-link" :to="`/Genes/${hgncId}`">
          Open SysNDD gene page
        </RouterLink>
      </section>
    </template>

    <p v-else class="ndd-gene-detail__fallback">No NDDScore prediction found for this gene.</p>
  </section>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { RouterLink } from 'vue-router';
import { BBadge } from 'bootstrap-vue-next';
import type { ColorVariant } from 'bootstrap-vue-next';
import { fetchGeneDetail, type NddScoreGeneDetail } from '@/api/nddscore';

defineOptions({
  name: 'NddScoreGeneDetail',
});

const props = defineProps<{
  hgncIdOrSymbol: string;
}>();

type GeneDetailRow = NddScoreGeneDetail & {
  hgnc_id?: string | number;
  gene_symbol?: string;
};

type HpoPrediction = {
  key: string;
  id: string;
  name: string;
  probability: unknown;
};

const gene = ref<GeneDetailRow | null>(null);
const loaded = ref(false);
let requestSerial = 0;

const geneSymbol = computed(() =>
  displayValue(readField(gene.value, 'gene_symbol', 'symbol') ?? props.hgncIdOrSymbol)
);

const hgncId = computed(() => {
  const value = readField(gene.value, 'hgnc_id', 'hgnc');
  return value == null || value === '' ? '' : String(value);
});

const inheritance = computed(() =>
  parseObject(readField(gene.value, 'inheritance_probabilities_json', 'inheritance_probabilities'))
);

const inheritanceModes = computed(() =>
  ['AD', 'AR', 'XLD', 'XLR'].map((key) => ({
    key,
    label: key,
    value: inheritance.value[key],
  }))
);

const hpoPredictions = computed<HpoPrediction[]>(() =>
  parseArray(readField(gene.value, 'top_hpo_predictions_json', 'hpo_predictions'))
    .slice(0, 8)
    .map((entry, index) => {
      const id = displayValue(readField(entry, 'phenotype_id', 'hpo_id', 'term_id'));
      const name = displayValue(readField(entry, 'phenotype_name', 'term_name', 'name') ?? id);
      return {
        key: `${id}-${index}`,
        id,
        name,
        probability: readField(entry, 'probability', 'score'),
      };
    })
);

const shapGroups = computed(() => {
  const raw = readField(gene.value, 'shap_group_contributions_json', 'shap_groups');
  const parsed = Array.isArray(raw) ? raw : parseObject(raw);
  const entries = Array.isArray(parsed)
    ? parsed.map((entry) => ({
        label: displayValue(readField(entry, 'group', 'label', 'name')),
        value: numericValue(readField(entry, 'value', 'contribution', 'shap_value')) ?? 0,
      }))
    : Object.entries(parsed).map(([label, value]) => ({
        label,
        value: numericValue(value) ?? 0,
      }));

  return entries
    .filter((entry) => entry.label !== 'NA')
    .sort((left, right) => Math.abs(right.value) - Math.abs(left.value));
});

async function loadGene() {
  const serial = ++requestSerial;
  loaded.value = false;

  try {
    const result = await fetchGeneDetail(props.hgncIdOrSymbol);
    if (serial === requestSerial) {
      gene.value = result as GeneDetailRow;
    }
  } catch {
    if (serial === requestSerial) {
      gene.value = null;
    }
  } finally {
    if (serial === requestSerial) {
      loaded.value = true;
    }
  }
}

function readField(row: Record<string, unknown> | null | undefined, ...keys: string[]): unknown {
  if (!row) {
    return undefined;
  }

  for (const key of keys) {
    if (row[key] != null && row[key] !== '') {
      return row[key];
    }
  }

  return undefined;
}

function parseObject(value: unknown): Record<string, unknown> {
  if (value && typeof value === 'object' && !Array.isArray(value)) {
    return value as Record<string, unknown>;
  }

  if (typeof value !== 'string' || value.length === 0) {
    return {};
  }

  try {
    const parsed = JSON.parse(value);
    return parsed && typeof parsed === 'object' && !Array.isArray(parsed)
      ? (parsed as Record<string, unknown>)
      : {};
  } catch {
    return {};
  }
}

function parseArray(value: unknown): Array<Record<string, unknown>> {
  if (Array.isArray(value)) {
    return value.filter((entry): entry is Record<string, unknown> => Boolean(entry));
  }

  if (typeof value !== 'string' || value.length === 0) {
    return [];
  }

  try {
    const parsed = JSON.parse(value);
    return Array.isArray(parsed)
      ? parsed.filter((entry): entry is Record<string, unknown> => Boolean(entry))
      : [];
  } catch {
    return [];
  }
}

function displayValue(value: unknown): string {
  if (value == null || value === '') {
    return 'NA';
  }
  return String(value);
}

function numericValue(value: unknown): number | null {
  const numberValue = typeof value === 'number' ? value : Number(value);
  return Number.isFinite(numberValue) ? numberValue : null;
}

function formatScore(value: unknown): string {
  const numberValue = numericValue(value);
  return numberValue == null ? 'NA' : numberValue.toFixed(3);
}

function formatProbability(value: unknown): string {
  const numberValue = numericValue(value);
  return numberValue == null ? 'NA' : `${(numberValue * 100).toFixed(1)}%`;
}

function formatSigned(value: unknown): string {
  const numberValue = numericValue(value);
  if (numberValue == null) {
    return 'NA';
  }
  return `${numberValue >= 0 ? '+' : ''}${numberValue.toFixed(3)}`;
}

function riskVariant(value: unknown): ColorVariant {
  switch (String(value).toLowerCase()) {
    case 'very high':
      return 'danger';
    case 'high':
      return 'warning';
    case 'moderate':
      return 'info';
    default:
      return 'light';
  }
}

function confidenceVariant(value: unknown): ColorVariant {
  switch (String(value).toLowerCase()) {
    case 'high':
      return 'success';
    case 'moderate':
      return 'info';
    default:
      return 'light';
  }
}

onMounted(() => {
  void loadGene();
});

watch(
  () => props.hgncIdOrSymbol,
  () => {
    void loadGene();
  }
);
</script>

<style scoped>
.ndd-gene-detail {
  display: grid;
  gap: 0.75rem;
  color: var(--neutral-900, #212121);
}

.ndd-gene-detail__header,
.ndd-gene-detail__panel,
.ndd-gene-detail__curated {
  padding: 0.875rem;
  border: 1px solid #d7dee8;
  border-radius: var(--radius-lg, 8px);
  background: #fff;
  box-shadow: 0 1px 2px rgb(15 23 42 / 6%);
}

.ndd-gene-detail__header {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-start;
  justify-content: space-between;
  gap: 0.75rem;
}

.ndd-gene-detail__eyebrow,
.ndd-gene-detail__meta,
.ndd-gene-detail__fallback,
.ndd-gene-detail__curated p {
  margin: 0;
  color: var(--neutral-600, #757575);
  font-size: 0.875rem;
  line-height: 1.45;
}

.ndd-gene-detail__eyebrow {
  font-size: 0.75rem;
  font-weight: 700;
}

.ndd-gene-detail__title {
  margin: 0.1rem 0 0;
  color: var(--neutral-900, #212121);
  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
  font-size: 1.25rem;
  font-weight: 700;
  line-height: 1.25;
}

.ndd-gene-detail__prediction-badge {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  border-radius: var(--radius-full, 999px);
}

.ndd-gene-detail__prediction-badge .bi {
  color: currentcolor;
}

.ndd-gene-detail__panel {
  display: grid;
  gap: 0.6rem;
}

.ndd-gene-detail__section-title {
  margin: 0;
  color: var(--neutral-900, #212121);
  font-size: 1rem;
  font-weight: 700;
  line-height: 1.25;
}

.ndd-gene-detail__metrics,
.ndd-gene-detail__compact-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(8.5rem, 1fr));
  gap: 0.5rem;
  margin: 0;
}

.ndd-gene-detail__metric,
.ndd-gene-detail__compact {
  display: grid;
  gap: 0.15rem;
  min-width: 0;
  padding: 0.5rem 0.6rem;
  border: 1px solid #e1e7ef;
  border-radius: var(--radius-md, 6px);
  background: #f8fafc;
}

.ndd-gene-detail__metric dt,
.ndd-gene-detail__compact dt {
  color: var(--neutral-600, #757575);
  font-size: 0.75rem;
  font-weight: 700;
}

.ndd-gene-detail__metric dd,
.ndd-gene-detail__compact dd {
  margin: 0;
  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
  font-size: 0.95rem;
  font-weight: 700;
}

.ndd-gene-detail__list {
  display: grid;
  gap: 0.35rem;
  padding: 0;
  margin: 0;
  list-style: none;
}

.ndd-gene-detail__list-row {
  display: flex;
  flex-wrap: wrap;
  align-items: baseline;
  justify-content: space-between;
  gap: 0.35rem 0.75rem;
  padding: 0.45rem 0.55rem;
  border: 1px solid #e1e7ef;
  border-radius: var(--radius-md, 6px);
  background: #fff;
}

.ndd-gene-detail__list-main {
  font-weight: 600;
}

.ndd-gene-detail__list-meta {
  color: var(--neutral-600, #757575);
  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
  font-size: 0.8125rem;
}

.ndd-gene-detail__curated {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-start;
  justify-content: space-between;
  gap: 0.75rem;
  border-color: #b8d7d2;
  background: #f6fbfa;
}

.ndd-gene-detail__curated-link {
  color: var(--medical-blue-700, #0d47a1);
  font-size: 0.875rem;
  font-weight: 700;
  text-decoration-thickness: 1px;
  text-underline-offset: 2px;
}
</style>
