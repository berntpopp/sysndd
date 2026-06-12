// Data-loading and derivation layer for the NDDScore gene detail page.
// Extracted from NddScoreGeneDetail.vue so the component stays a thin
// presentation shell. This is a model-derived prediction layer, kept separate
// from curated SysNDD evidence; all copy/labels are owned by the component.

import { computed, type ComputedRef } from 'vue';
import type { ColorVariant } from 'bootstrap-vue-next';
import { fetchGeneDetail, type NddScoreGeneDetail } from '@/api/nddscore';
import { useResource } from '@/composables/useResource';

export type NddScoreGeneDetailRow = NddScoreGeneDetail & {
  hgnc_id?: string | number;
  gene_symbol?: string;
};

export interface NddScoreHpoPrediction {
  key: string;
  id: string;
  name: string;
  probability: unknown;
}

export interface NddScoreInheritanceMode {
  key: string;
  label: string;
  value: unknown;
}

export interface NddScoreShapGroup {
  label: string;
  value: number;
}

export function readField(
  row: Record<string, unknown> | null | undefined,
  ...keys: string[]
): unknown {
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

export function parseObject(value: unknown): Record<string, unknown> {
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

export function parseArray(value: unknown): Array<Record<string, unknown>> {
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

export function displayValue(value: unknown): string {
  if (value == null || value === '') {
    return 'NA';
  }
  return String(value);
}

export function numericValue(value: unknown): number | null {
  const numberValue = typeof value === 'number' ? value : Number(value);
  return Number.isFinite(numberValue) ? numberValue : null;
}

export function formatScore(value: unknown): string {
  const numberValue = numericValue(value);
  return numberValue == null ? 'NA' : numberValue.toFixed(3);
}

export function formatProbability(value: unknown): string {
  const numberValue = numericValue(value);
  return numberValue == null ? 'NA' : `${(numberValue * 100).toFixed(1)}%`;
}

export function formatPercentile(value: unknown): string {
  const numberValue = numericValue(value);
  return numberValue == null ? 'NA' : `${numberValue.toFixed(1)}%`;
}

export function formatSigned(value: unknown): string {
  const numberValue = numericValue(value);
  if (numberValue == null) {
    return 'NA';
  }
  return `${numberValue >= 0 ? '+' : ''}${numberValue.toFixed(3)}`;
}

export function booleanValue(value: unknown): boolean {
  return value === true || value === 1 || value === '1' || value === 'true';
}

export function riskVariant(value: unknown): ColorVariant {
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

export function confidenceVariant(value: unknown): ColorVariant {
  switch (String(value).toLowerCase()) {
    case 'high':
      return 'success';
    case 'medium':
      return 'info';
    default:
      return 'light';
  }
}

export interface UseNddScoreGeneDetail {
  gene: ComputedRef<NddScoreGeneDetailRow | null>;
  loaded: ComputedRef<boolean>;
  geneSymbol: ComputedRef<string>;
  hgncId: ComputedRef<string>;
  ensemblId: ComputedRef<string>;
  modelSplit: ComputedRef<string>;
  ensemblUrl: ComputedRef<string>;
  modelSplitTooltip: ComputedRef<string>;
  knownSysnddGene: ComputedRef<boolean>;
  inheritanceModes: ComputedRef<NddScoreInheritanceMode[]>;
  hpoPredictions: ComputedRef<NddScoreHpoPrediction[]>;
  shapGroups: ComputedRef<NddScoreShapGroup[]>;
}

export function useNddScoreGeneDetail(
  hgncIdOrSymbol: ComputedRef<string>
): UseNddScoreGeneDetail {
  const geneResource = useResource<NddScoreGeneDetailRow>(
    computed(() => `nddscore:gene:${hgncIdOrSymbol.value}`),
    (signal) =>
      fetchGeneDetail(hgncIdOrSymbol.value, { signal }) as Promise<NddScoreGeneDetailRow>,
    { ttlMs: 60_000, staleWhileRevalidate: true }
  );

  const gene = computed<NddScoreGeneDetailRow | null>(() => {
    const row = geneResource.data.value;
    return row && Object.keys(row).length > 0 ? row : null;
  });

  const loaded = computed(() => !geneResource.loading.value);

  const geneSymbol = computed(() =>
    displayValue(readField(gene.value, 'gene_symbol', 'symbol') ?? hgncIdOrSymbol.value)
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
    ensemblId.value
      ? `https://www.ensembl.org/Homo_sapiens/Gene/Summary?g=${ensemblId.value}`
      : ''
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

  const knownSysnddGene = computed(() => booleanValue(readField(gene.value, 'known_sysndd_gene')));

  const inheritance = computed(() =>
    parseObject(
      readField(gene.value, 'inheritance_probabilities_json', 'inheritance_probabilities')
    )
  );

  const inheritanceModes = computed<NddScoreInheritanceMode[]>(() =>
    ['AD', 'AR', 'XLD', 'XLR'].map((key) => ({
      key,
      label: key,
      value: inheritance.value[key],
    }))
  );

  const hpoPredictions = computed<NddScoreHpoPrediction[]>(() =>
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

  const shapGroups = computed<NddScoreShapGroup[]>(() => {
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

  return {
    gene,
    loaded,
    geneSymbol,
    hgncId,
    ensemblId,
    modelSplit,
    ensemblUrl,
    modelSplitTooltip,
    knownSysnddGene,
    inheritanceModes,
    hpoPredictions,
    shapGroups,
  };
}
