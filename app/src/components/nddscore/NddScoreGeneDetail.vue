<template>
  <div class="container-fluid bg-gradient ndd-gene-detail-page">
    <BContainer fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol cols="12">
          <section class="ndd-gene-detail__hero" aria-labelledby="ndd-gene-detail-title">
            <div class="ndd-gene-detail__hero-head">
              <div class="ndd-gene-detail__identity">
                <p class="ndd-gene-detail__eyebrow">NDDScore gene prediction</p>
                <h1 id="ndd-gene-detail-title" class="ndd-gene-detail__title">
                  {{ geneSymbol }}
                </h1>
              </div>

              <div class="ndd-gene-detail__actions">
                <RouterLink class="ndd-gene-detail__back-link" :to="backToPredictions">
                  Back to predictions
                </RouterLink>
                <BBadge class="ndd-gene-detail__prediction-badge" variant="info">
                  <i class="bi bi-cpu" aria-hidden="true"></i>
                  <span>ML prediction</span>
                </BBadge>
              </div>
            </div>

            <div v-if="gene" class="ndd-gene-detail__unit-grid">
              <div class="ndd-gene-detail__unit-cell">
                <div class="ndd-gene-detail__unit-label">Gene</div>
                <GeneBadge
                  :symbol="geneSymbol"
                  :hgnc-id="hgncId"
                  :link-to="hgncId ? `/Genes/${hgncId}` : undefined"
                  size="lg"
                />
              </div>
              <div class="ndd-gene-detail__unit-cell">
                <div class="ndd-gene-detail__unit-label">Prediction</div>
                <div class="ndd-gene-detail__unit-value">
                  {{ formatScore(readField(gene, 'ndd_score', 'score')) }}
                  <BBadge :variant="riskVariant(readField(gene, 'risk_tier'))">
                    {{ displayValue(readField(gene, 'risk_tier')) }}
                  </BBadge>
                </div>
              </div>
              <div class="ndd-gene-detail__unit-cell">
                <div class="ndd-gene-detail__unit-label">SysNDD status</div>
                <RouterLink
                  v-if="knownSysnddGene && hgncId"
                  v-b-tooltip.hover.top
                  class="ndd-gene-detail__status-link"
                  :to="`/Genes/${hgncId}`"
                  :title="identifierHelp.hgnc"
                >
                  <BBadge class="ndd-gene-detail__status-badge" variant="info">
                    Known SysNDD gene
                  </BBadge>
                </RouterLink>
                <BBadge v-else class="ndd-gene-detail__status-badge" variant="light">
                  New candidate
                </BBadge>
              </div>
            </div>

            <div class="ndd-gene-detail__meta-row">
              <RouterLink
                v-if="hgncId"
                v-b-tooltip.hover.bottom
                class="ndd-gene-detail__meta-chip ndd-gene-detail__meta-chip--link"
                :to="`/Genes/${hgncId}`"
                :title="identifierHelp.hgnc"
              >
                {{ hgncId }}
              </RouterLink>
              <a
                v-if="ensemblId"
                v-b-tooltip.hover.bottom
                class="ndd-gene-detail__meta-chip ndd-gene-detail__meta-chip--link"
                :href="ensemblUrl"
                target="_blank"
                rel="noopener noreferrer"
                :title="identifierHelp.ensembl"
              >
                {{ ensemblId }}
              </a>
              <span
                v-if="modelSplit"
                v-b-tooltip.hover.bottom
                class="ndd-gene-detail__meta-chip"
                :title="modelSplitTooltip"
              >
                {{ modelSplit }} split
              </span>
            </div>
          </section>
        </BCol>
      </BRow>

      <p v-if="!loaded" class="ndd-gene-detail__fallback">Loading gene prediction.</p>

      <template v-else-if="gene">
        <BRow class="ndd-gene-detail__content-grid">
          <BCol cols="12" xl="7" class="mb-2">
            <section class="ndd-gene-detail__panel" aria-labelledby="ndd-gene-detail-summary">
              <h2 id="ndd-gene-detail-summary" class="ndd-gene-detail__section-title">
                Prediction summary
              </h2>
              <dl class="ndd-gene-detail__metrics">
                <div class="ndd-gene-detail__metric">
                  <dt v-b-tooltip.hover.top :title="metricHelp.nddScore">NDD score</dt>
                  <dd>{{ formatScore(readField(gene, 'ndd_score', 'score')) }}</dd>
                </div>
                <div class="ndd-gene-detail__metric">
                  <dt v-b-tooltip.hover.top :title="metricHelp.rank">Rank</dt>
                  <dd>{{ displayValue(readField(gene, 'rank', 'gene_rank')) }}</dd>
                </div>
                <div class="ndd-gene-detail__metric">
                  <dt v-b-tooltip.hover.top :title="metricHelp.percentile">Percentile</dt>
                  <dd>{{ formatPercentile(readField(gene, 'percentile')) }}</dd>
                </div>
                <div class="ndd-gene-detail__metric">
                  <dt v-b-tooltip.hover.top :title="metricHelp.bagAgreement">Bag agreement</dt>
                  <dd>{{ formatProbability(readField(gene, 'bag_agreement')) }}</dd>
                </div>
                <div class="ndd-gene-detail__metric">
                  <dt v-b-tooltip.hover.top :title="metricHelp.riskTier">Risk tier</dt>
                  <dd>
                    <BBadge
                      v-b-tooltip.hover.top
                      :variant="riskVariant(readField(gene, 'risk_tier'))"
                      :title="metricHelp.riskTier"
                    >
                      {{ displayValue(readField(gene, 'risk_tier')) }}
                    </BBadge>
                  </dd>
                </div>
                <div class="ndd-gene-detail__metric">
                  <dt v-b-tooltip.hover.top :title="metricHelp.confidence">Confidence</dt>
                  <dd>
                    <BBadge
                      v-b-tooltip.hover.top
                      :variant="confidenceVariant(readField(gene, 'confidence_tier'))"
                      :title="metricHelp.confidence"
                    >
                      {{ displayValue(readField(gene, 'confidence_tier')) }}
                    </BBadge>
                  </dd>
                </div>
              </dl>
            </section>

            <section class="ndd-gene-detail__panel" aria-labelledby="ndd-gene-detail-inheritance">
              <h2 id="ndd-gene-detail-inheritance" class="ndd-gene-detail__section-title">
                Inheritance probabilities
              </h2>
              <dl class="ndd-gene-detail__compact-grid">
                <div
                  v-for="mode in inheritanceModes"
                  :key="mode.key"
                  class="ndd-gene-detail__compact"
                >
                  <dt v-b-tooltip.hover.top :title="inheritanceHelp">{{ mode.label }}</dt>
                  <dd>{{ formatProbability(mode.value) }}</dd>
                </div>
              </dl>
            </section>

            <section class="ndd-gene-detail__panel" aria-labelledby="ndd-gene-detail-shap">
              <h2 id="ndd-gene-detail-shap" class="ndd-gene-detail__section-title">
                SHAP group contributions
              </h2>
              <dl v-if="shapGroups.length" class="ndd-gene-detail__compact-grid">
                <div
                  v-for="group in shapGroups"
                  :key="group.label"
                  class="ndd-gene-detail__compact"
                >
                  <dt v-b-tooltip.hover.top :title="shapHelp">{{ group.label }}</dt>
                  <dd>{{ formatSigned(group.value) }}</dd>
                </div>
              </dl>
              <p v-else class="ndd-gene-detail__fallback">No SHAP group contributions available.</p>
            </section>
          </BCol>

          <BCol cols="12" xl="5" class="mb-2">
            <section class="ndd-gene-detail__panel" aria-labelledby="ndd-gene-detail-hpo">
              <h2 id="ndd-gene-detail-hpo" class="ndd-gene-detail__section-title">
                Top predicted HPO terms
              </h2>
              <ul v-if="hpoPredictions.length" class="ndd-gene-detail__list">
                <li
                  v-for="term in hpoPredictions"
                  :key="term.key"
                  v-b-tooltip.hover.top
                  class="ndd-gene-detail__list-row"
                  :title="hpoHelp"
                >
                  <span class="ndd-gene-detail__list-main">{{ term.name }}</span>
                  <span class="ndd-gene-detail__list-meta">
                    {{ term.id }} &middot; {{ formatProbability(term.probability) }}
                  </span>
                </li>
              </ul>
              <p v-else class="ndd-gene-detail__fallback">No HPO predictions available.</p>
            </section>

            <section
              v-if="predictionNote"
              class="ndd-gene-detail__note"
              aria-label="Prediction note"
            >
              {{ predictionNote }}
            </section>
          </BCol>
        </BRow>
      </template>

      <p v-else class="ndd-gene-detail__fallback">No NDDScore prediction found for this gene.</p>
    </BContainer>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { RouterLink, useRoute } from 'vue-router';
import { BBadge, BCol, BContainer, BRow } from 'bootstrap-vue-next';
import type { ColorVariant } from 'bootstrap-vue-next';
import GeneBadge from '@/components/ui/GeneBadge.vue';
import { fetchGeneDetail, type NddScoreGeneDetail } from '@/api/nddscore';
import { returnToFromRoute } from '@/utils/returnNavigation';

defineOptions({
  name: 'NddScoreGeneDetail',
});

const props = defineProps<{
  hgncIdOrSymbol: string;
}>();

const route = useRoute();

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

const backToPredictions = computed(() => returnToFromRoute(route, '/NDDScore'));

const geneSymbol = computed(() =>
  displayValue(readField(gene.value, 'gene_symbol', 'symbol') ?? props.hgncIdOrSymbol)
);

const hgncId = computed(() => {
  const value = readField(gene.value, 'hgnc_id', 'hgnc');
  return value == null || value === '' ? '' : String(value);
});

const ensemblId = computed(() => {
  const value = readField(gene.value, 'ensembl_gene_id');
  return value == null || value === '' ? '' : String(value);
});

const modelSplit = computed(() => {
  const value = readField(gene.value, 'model_split');
  return value == null || value === '' ? '' : String(value);
});

const ensemblUrl = computed(() =>
  ensemblId.value ? `https://www.ensembl.org/Homo_sapiens/Gene/Summary?g=${ensemblId.value}` : ''
);

const modelSplitTooltip = computed(() => {
  switch (modelSplit.value.toLowerCase()) {
    case 'train':
      return 'This gene was present in the model-training split.';
    case 'test':
      return 'This gene was held out for model testing.';
    case 'unseen':
      return 'This gene was not in the model-training split; interpret the prediction as an unseen-gene estimate.';
    default:
      return 'Dataset split used by the NDDScore model release.';
  }
});

const predictionNote = computed(() => {
  const value = readField(gene.value, 'prediction_note');
  return value == null || value === '' ? '' : String(value);
});

const knownSysnddGene = computed(() => booleanValue(readField(gene.value, 'known_sysndd_gene')));

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
  parseArray(readField(gene.value, 'hpo_predictions', 'top_hpo_predictions_json'))
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

const metricHelp = {
  nddScore:
    'Model probability-like score for neurodevelopmental disorder gene candidacy; higher scores indicate stronger model support.',
  rank: 'Position of this gene in the active NDDScore release after sorting by NDD score.',
  percentile:
    'Relative position among all genes in the active release; higher percentile means stronger model rank.',
  bagAgreement:
    'Share of model bags that support this prediction tier. Higher agreement means the ensemble was more consistent.',
  riskTier: 'Bucketed interpretation of the NDD score in the active model release.',
  confidence:
    'Model confidence tier derived from ensemble consistency and score stability; this is not curated SysNDD evidence.',
};
const identifierHelp = {
  hgnc: 'Open the curated SysNDD gene page for this HGNC identifier.',
  ensembl: 'Open the Ensembl gene record in a new tab.',
};
const inheritanceHelp =
  'Model-estimated probability for each inheritance mode. These are prediction outputs, not curated inheritance assignments.';
const shapHelp =
  'Signed contribution of each feature group to the model score. Positive values pushed the score higher; negative values pushed it lower.';
const hpoHelp =
  'Predicted phenotype association for this gene in the active NDDScore release, shown with model probability.';

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

function formatPercentile(value: unknown): string {
  const numberValue = numericValue(value);
  return numberValue == null ? 'NA' : `${numberValue.toFixed(1)}%`;
}

function formatSigned(value: unknown): string {
  const numberValue = numericValue(value);
  if (numberValue == null) {
    return 'NA';
  }
  return `${numberValue >= 0 ? '+' : ''}${numberValue.toFixed(3)}`;
}

function booleanValue(value: unknown): boolean {
  return value === true || value === 1 || value === '1' || value === 'true';
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
    case 'medium':
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
.ndd-gene-detail-page {
  min-height: calc(100vh - 4rem);
  padding-bottom: 1rem;
  color: var(--neutral-900, #212121);
}

.ndd-gene-detail__hero,
.ndd-gene-detail__panel,
.ndd-gene-detail__note {
  padding: 0.875rem;
  border: 1px solid #d7dee8;
  border-radius: var(--radius-lg, 8px);
  background: #fff;
  box-shadow: 0 1px 2px rgb(15 23 42 / 6%);
}

.ndd-gene-detail__hero {
  display: grid;
  gap: 0.65rem;
}

.ndd-gene-detail__hero-head {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-start;
  justify-content: space-between;
  gap: 0.75rem;
}

.ndd-gene-detail__identity {
  display: grid;
  gap: 0.3rem;
  min-width: 0;
}

.ndd-gene-detail__actions {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  justify-content: flex-end;
  gap: 0.5rem;
}

.ndd-gene-detail__unit-grid {
  display: grid;
  grid-template-columns: minmax(12rem, 1.2fr) minmax(11rem, 1fr) minmax(11rem, 1fr);
  gap: 0.5rem;
}

.ndd-gene-detail__unit-cell {
  display: grid;
  align-content: start;
  gap: 0.3rem;
  min-width: 0;
  padding: 0.55rem 0.65rem;
  border: 1px solid #e1e7ef;
  border-radius: var(--radius-md, 6px);
  background: #f8fafc;
}

.ndd-gene-detail__unit-label {
  color: var(--neutral-600, #757575);
  font-size: 0.72rem;
  font-weight: 800;
  line-height: 1.2;
  text-transform: uppercase;
}

.ndd-gene-detail__unit-value {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.4rem;
  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
  font-size: 1rem;
  font-weight: 800;
}

.ndd-gene-detail__eyebrow,
.ndd-gene-detail__fallback,
.ndd-gene-detail__note {
  margin: 0;
  color: var(--neutral-600, #757575);
  font-size: 0.875rem;
  line-height: 1.45;
}

.ndd-gene-detail__meta-row {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem;
}

.ndd-gene-detail__meta-chip {
  display: inline-flex;
  max-width: 100%;
  padding: 0.15rem 0.45rem;
  overflow: hidden;
  color: var(--neutral-900, #212121);
  text-overflow: ellipsis;
  white-space: nowrap;
  border: 1px solid #d7dee8;
  border-radius: var(--radius-full, 999px);
  background: #f8fafc;
  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
  font-size: 0.75rem;
  font-weight: 700;
}

.ndd-gene-detail__meta-chip--link {
  color: var(--medical-blue-700, #0d47a1);
  text-decoration: none;
}

.ndd-gene-detail__meta-chip--link:hover {
  color: var(--medical-blue-600, #1e88e5);
  text-decoration: underline;
  text-underline-offset: 2px;
}

.ndd-gene-detail__eyebrow {
  font-size: 0.75rem;
  font-weight: 700;
}

.ndd-gene-detail__title {
  margin: 0.1rem 0 0;
  color: var(--neutral-900, #212121);
  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
  font-size: 1.35rem;
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
  margin-bottom: 0.75rem;
}

.ndd-gene-detail__section-title {
  margin: 0;
  color: var(--neutral-900, #212121);
  font-size: 0.95rem;
  font-weight: 700;
  line-height: 1.25;
  text-align: left;
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
  cursor: help;
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
  cursor: help;
}

.ndd-gene-detail__list-main {
  font-weight: 600;
}

.ndd-gene-detail__list-meta {
  color: var(--neutral-600, #757575);
  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
  font-size: 0.8125rem;
}

.ndd-gene-detail__note {
  border-color: #d7dee8;
  background: #f8fafc;
}

.ndd-gene-detail__back-link,
.ndd-gene-detail__status-link {
  color: var(--medical-blue-700, #0d47a1);
  font-size: 0.875rem;
  font-weight: 700;
  text-decoration-thickness: 1px;
  text-underline-offset: 2px;
}

.ndd-gene-detail__status-link {
  text-decoration: none;
}

.ndd-gene-detail__status-badge {
  border-radius: var(--radius-full, 999px);
}

@media (max-width: 991.98px) {
  .ndd-gene-detail__unit-grid {
    grid-template-columns: 1fr;
  }

  .ndd-gene-detail__actions {
    justify-content: flex-start;
  }
}
</style>
