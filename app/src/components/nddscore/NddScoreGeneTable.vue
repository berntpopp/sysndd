<template>
  <TableShell
    title="Gene predictions"
    :meta="totalLabel"
    description="Current-release NDDScore gene association predictions."
    :loading="loading"
  >
    <template #toolbar>
      <div class="nddscore-gene-toolbar">
        <div class="nddscore-gene-toolbar__search">
          <TableSearchInput
            v-model="search"
            placeholder="Search gene symbol or HGNC ID"
            :debounce-time="350"
            :loading="loading"
            @update:model-value="handleSearchChange"
            @clear="handleSearchChange"
          />
        </div>

        <div class="nddscore-gene-toolbar__pagination">
          <TablePaginationControls
            :total-rows="total"
            :initial-per-page="pageSize"
            :current-page="page"
            :page-options="[10, 25, 50, 100]"
            @page-change="handlePageChange"
            @per-page-change="handlePageSizeChange"
          />
        </div>
      </div>
    </template>

    <GenericTable
      :items="rows"
      :fields="fields"
      :sort-by="sortBy"
      :fixed-layout="false"
      :stacked-mode="false"
      :is-busy="loading"
      @update-sort="handleSortUpdate"
    >
      <template #column-header="{ data }">
        <div v-b-tooltip.hover.bottom :title="columnHelp[data.column] || data.label">
          {{ data.label }}
        </div>
      </template>

      <template #filter-controls>
        <td v-for="field in fields" :key="field.key">
          <div v-if="field.filterType === 'range'" class="nddscore-gene-table__range-filter">
            <BFormInput
              v-model="columnFilters[`${field.key}_min`]"
              :aria-label="`${field.label} minimum`"
              placeholder="min"
              type="number"
              :step="field.numericStep ?? '1'"
              size="sm"
              @click="removeSearch"
              @update:model-value="handleColumnFilterChange"
            />
            <BFormInput
              v-model="columnFilters[`${field.key}_max`]"
              :aria-label="`${field.label} maximum`"
              placeholder="max"
              type="number"
              :step="field.numericStep ?? '1'"
              size="sm"
              @click="removeSearch"
              @update:model-value="handleColumnFilterChange"
            />
          </div>

          <BFormInput
            v-else-if="field.filterType === 'text'"
            v-model="columnFilters[field.key]"
            :placeholder="'.. ' + field.label + ' ..'"
            type="search"
            autocomplete="off"
            size="sm"
            @click="removeSearch"
            @update:model-value="handleColumnFilterChange"
          />

          <BFormSelect
            v-else-if="field.filterType === 'select'"
            v-model="columnFilters[field.key]"
            :options="selectOptionsFor(field)"
            size="sm"
            @update:model-value="
              removeSearch();
              handleColumnFilterChange();
            "
          />

          <BFormSelect
            v-else-if="field.filterType === 'multi-select'"
            v-model="hpoTermFilter"
            :options="hpoTermOptions"
            size="sm"
            multiple
            :select-size="4"
            aria-label="Predicted HPO terms"
            @update:model-value="
              removeSearch();
              handleColumnFilterChange();
            "
          />
        </td>
      </template>

      <template #cell-gene_symbol="{ row }">
        <GeneBadge
          :symbol="displayValue(row.gene_symbol)"
          :hgnc-id="displayValue(row.hgnc_id)"
          :link-to="detailPath(row)"
          size="sm"
        />
      </template>

      <template #cell-hgnc_id="{ row }">
        <RouterLink class="nddscore-gene-table__id-link" :to="detailPath(row)">
          {{ displayValue(row.hgnc_id) }}
        </RouterLink>
      </template>

      <template #cell-ndd_score="{ row }">
        <span class="nddscore-gene-table__numeric">{{ formatDecimal(row.ndd_score, 3) }}</span>
      </template>

      <template #cell-rank="{ row }">
        <span class="nddscore-gene-table__numeric">{{ displayValue(row.rank) }}</span>
      </template>

      <template #cell-percentile="{ row }">
        <span class="nddscore-gene-table__numeric">{{ formatPercentile(row.percentile) }}</span>
      </template>

      <template #cell-risk_tier="{ row }">
        <BBadge :variant="riskVariant(row.risk_tier)">
          {{ displayValue(row.risk_tier) }}
        </BBadge>
      </template>

      <template #cell-confidence_tier="{ row }">
        <BBadge :variant="confidenceVariant(row.confidence_tier)">
          {{ displayValue(row.confidence_tier) }}
        </BBadge>
      </template>

      <template #cell-known_sysndd_gene="{ row }">
        <RouterLink
          v-if="isKnownGene(row.known_sysndd_gene)"
          v-b-tooltip.hover.left
          :to="`/Genes/${row.hgnc_id}`"
          class="nddscore-gene-table__gene-link"
          title="Open the curated SysNDD gene page for this HGNC identifier."
        >
          <BBadge variant="info">Known</BBadge>
        </RouterLink>
        <BBadge v-else variant="light">New</BBadge>
      </template>

      <template #cell-model_split="{ row }">
        <BBadge class="nddscore-gene-table__chip" variant="secondary">
          {{ displayValue(row.model_split) }}
        </BBadge>
      </template>

      <template #cell-top_inheritance_mode="{ row }">
        <BBadge class="nddscore-gene-table__chip" variant="primary">
          {{ displayValue(row.top_inheritance_mode) }}
        </BBadge>
      </template>

      <template #cell-top_hpo_predictions_json="{ row }">
        <span
          v-b-tooltip.hover.left
          class="nddscore-gene-table__hpo"
          :title="topHpoTooltip(row.top_hpo_predictions_json)"
        >
          {{ topHpoLabel(row.top_hpo_predictions_json, row.n_predicted_hpo) }}
        </span>
      </template>
    </GenericTable>

    <div v-if="!loading && !rows.length" class="nddscore-gene-table__empty">
      No gene predictions found.
    </div>
  </TableShell>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue';
import { RouterLink } from 'vue-router';
import { BBadge, BFormInput, BFormSelect } from 'bootstrap-vue-next';
import type { ColorVariant } from 'bootstrap-vue-next';
import {
  fetchGenePredictions,
  fetchHpoTerms,
  type NddScoreGenePrediction,
  type NddScoreHpoTerm,
} from '@/api/nddscore';
import GeneBadge from '@/components/ui/GeneBadge.vue';
import TableShell from '@/components/table/TableShell.vue';
import GenericTable from '@/components/small/GenericTable.vue';
import TableSearchInput from '@/components/small/TableSearchInput.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';

defineOptions({
  name: 'NddScoreGeneTable',
});

type GenePredictionRow = NddScoreGenePrediction & {
  release_id?: string;
  hgnc_id?: string | number;
  gene_symbol?: string;
  ndd_score?: number | string;
  rank?: number | string;
  percentile?: number | string;
  risk_tier?: string;
  confidence_tier?: string;
  known_sysndd_gene?: boolean | number | string | null;
  model_split?: string | null;
  top_inheritance_mode?: string | null;
  n_predicted_hpo?: number | string | null;
  top_hpo_predictions_json?: unknown;
};

type SortEvent = {
  sortBy: string;
  sortDesc: boolean;
};

type FieldKey =
  | 'gene_symbol'
  | 'hgnc_id'
  | 'ndd_score'
  | 'rank'
  | 'percentile'
  | 'risk_tier'
  | 'confidence_tier'
  | 'known_sysndd_gene'
  | 'model_split'
  | 'top_inheritance_mode'
  | 'top_hpo_predictions_json';

type FieldDefinition = {
  key: FieldKey;
  label: string;
  sortable?: boolean;
  filterType?: 'text' | 'select' | 'range' | 'multi-select';
  selectOptions?: Array<{ value: string; text: string }>;
  numericStep?: string;
};

const rows = ref<GenePredictionRow[]>([]);
const total = ref(0);
const page = ref(1);
const pageSize = ref(10);
const loading = ref(false);
const search = ref('');
const sort = ref('rank');
const hpoTermFilter = ref<string[]>([]);
const hpoTermOptions = ref<Array<{ value: string; text: string }>>([]);
let requestSerial = 0;

const riskTierOptions = [
  { value: 'Very High', text: 'Very High' },
  { value: 'High', text: 'High' },
  { value: 'Moderate', text: 'Moderate' },
  { value: 'Low', text: 'Low' },
  { value: 'Very Low', text: 'Very Low' },
];

const confidenceTierOptions = [
  { value: 'High', text: 'High' },
  { value: 'Medium', text: 'Medium' },
  { value: 'Low', text: 'Low' },
];

const knownSysnddOptions = [
  { value: 'true', text: 'Known SysNDD gene' },
  { value: 'false', text: 'Not known in SysNDD' },
];

const modelSplitOptions = [
  { value: 'train', text: 'Train' },
  { value: 'validation', text: 'Validation' },
  { value: 'test', text: 'Test' },
  { value: 'unseen', text: 'Unseen' },
];

const inheritanceModeOptions = [
  { value: 'AD', text: 'AD' },
  { value: 'AR', text: 'AR' },
  { value: 'XLD', text: 'XLD' },
  { value: 'XLR', text: 'XLR' },
];

const fields: FieldDefinition[] = [
  { key: 'gene_symbol', label: 'Gene', sortable: true, filterType: 'text' },
  { key: 'hgnc_id', label: 'HGNC ID', sortable: true, filterType: 'text' },
  {
    key: 'ndd_score',
    label: 'NDD score',
    sortable: true,
    filterType: 'range',
    numericStep: '0.001',
  },
  { key: 'rank', label: 'Rank', sortable: true, filterType: 'range', numericStep: '1' },
  {
    key: 'percentile',
    label: 'Percentile',
    sortable: true,
    filterType: 'range',
    numericStep: '0.1',
  },
  {
    key: 'risk_tier',
    label: 'Risk tier',
    sortable: true,
    filterType: 'select',
    selectOptions: riskTierOptions,
  },
  {
    key: 'confidence_tier',
    label: 'Confidence',
    sortable: true,
    filterType: 'select',
    selectOptions: confidenceTierOptions,
  },
  {
    key: 'known_sysndd_gene',
    label: 'SysNDD',
    sortable: true,
    filterType: 'select',
    selectOptions: knownSysnddOptions,
  },
  {
    key: 'model_split',
    label: 'Split',
    sortable: false,
    filterType: 'select',
    selectOptions: modelSplitOptions,
  },
  {
    key: 'top_inheritance_mode',
    label: 'Top inheritance',
    sortable: false,
    filterType: 'select',
    selectOptions: inheritanceModeOptions,
  },
  {
    key: 'top_hpo_predictions_json',
    label: 'Predicted HPO',
    sortable: false,
    filterType: 'multi-select',
  },
];

const columnFilters = reactive<Record<string, string>>({
  gene_symbol: '',
  hgnc_id: '',
  ndd_score_min: '',
  ndd_score_max: '',
  rank_min: '',
  rank_max: '',
  percentile_min: '',
  percentile_max: '',
  risk_tier: '',
  confidence_tier: '',
  known_sysndd_gene: '',
  model_split: '',
  top_inheritance_mode: '',
});

const columnHelp: Record<string, string> = {
  gene_symbol: 'Gene symbol linked to the NDDScore prediction detail page.',
  hgnc_id: 'HGNC identifier linked to the NDDScore prediction detail page.',
  ndd_score: 'Model probability-like score for NDD gene candidacy; higher is stronger model support.',
  rank: 'Position of this gene in the active NDDScore release after sorting by NDD score.',
  percentile: 'Relative position among all genes in the active release.',
  risk_tier: 'Bucketed interpretation of the model score.',
  confidence_tier: 'Model confidence tier based on ensemble consistency and score stability.',
  known_sysndd_gene: 'Whether this HGNC identifier already has a curated SysNDD gene page.',
  model_split: 'Dataset split assigned in the active NDDScore release.',
  top_inheritance_mode: 'Highest-probability inheritance mode predicted by the model.',
  top_hpo_predictions_json: 'Top predicted phenotype association for this gene.',
};

const totalLabel = computed(() => `${total.value.toLocaleString()} genes`);
const sortBy = computed(() => [
  {
    key: sort.value.replace(/^[+-]/, ''),
    order: sort.value.startsWith('-') ? 'desc' : 'asc',
  },
]);

function normalizeRows(data: NddScoreGenePrediction[] | undefined): GenePredictionRow[] {
  return (data ?? []).map((row) => row as GenePredictionRow);
}

function hpoTermOption(term: NddScoreHpoTerm): { value: string; text: string } | null {
  const phenotypeId = displayValue(term.phenotype_id);
  if (phenotypeId === 'NA') {
    return null;
  }
  const phenotypeName = displayValue(term.phenotype_name);
  return {
    value: phenotypeId,
    text: phenotypeName === 'NA' ? phenotypeId : `${phenotypeId} ${phenotypeName}`,
  };
}

async function loadHpoTermOptions() {
  try {
    hpoTermOptions.value = (await fetchHpoTerms())
      .map(hpoTermOption)
      .filter((option): option is { value: string; text: string } => option != null);
  } catch {
    hpoTermOptions.value = [];
  }
}

function selectOptionsFor(field: FieldDefinition): Array<{ value: string; text: string }> {
  return [{ value: '', text: `.. ${field.label} ..` }, ...(field.selectOptions ?? [])];
}

function numberFilter(value: string): number | undefined {
  if (value.trim() === '') {
    return undefined;
  }
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : undefined;
}

async function loadRows() {
  const serial = ++requestSerial;
  loading.value = true;

  try {
    const result = await fetchGenePredictions({
      sort: sort.value,
      search: search.value || undefined,
      nddScoreMin: numberFilter(columnFilters.ndd_score_min),
      nddScoreMax: numberFilter(columnFilters.ndd_score_max),
      rankMin: numberFilter(columnFilters.rank_min),
      rankMax: numberFilter(columnFilters.rank_max),
      percentileMin: numberFilter(columnFilters.percentile_min),
      percentileMax: numberFilter(columnFilters.percentile_max),
      riskTier: columnFilters.risk_tier || undefined,
      confidenceTier: columnFilters.confidence_tier || undefined,
      knownSysnddGene: columnFilters.known_sysndd_gene || undefined,
      page: page.value,
      pageSize: pageSize.value,
      hgncId: columnFilters.hgnc_id || undefined,
      geneSymbol: columnFilters.gene_symbol || undefined,
      modelSplit: columnFilters.model_split || undefined,
      topInheritanceMode: columnFilters.top_inheritance_mode || undefined,
      hpoTerms: hpoTermFilter.value.length ? hpoTermFilter.value : undefined,
    });

    if (serial !== requestSerial) {
      return;
    }

    rows.value = normalizeRows(result.data);
    total.value = Number(result.total) || 0;
    page.value = Number(result.page) || page.value;
    pageSize.value = Number(result.page_size) || pageSize.value;
  } finally {
    if (serial === requestSerial) {
      loading.value = false;
    }
  }
}

function handleSearchChange() {
  page.value = 1;
  void loadRows();
}

function handleColumnFilterChange() {
  page.value = 1;
  void loadRows();
}

function handleSortUpdate({ sortBy: nextSortBy, sortDesc }: SortEvent) {
  sort.value = `${sortDesc ? '-' : ''}${nextSortBy}`;
  page.value = 1;
  void loadRows();
}

function handlePageChange(nextPage: number) {
  page.value = nextPage;
  void loadRows();
}

function handlePageSizeChange(nextPageSize: number) {
  pageSize.value = nextPageSize;
  page.value = 1;
  void loadRows();
}

function removeSearch() {
  search.value = '';
}

function detailPath(row: GenePredictionRow): string {
  return `/NDDScore/Gene/${encodeURIComponent(displayValue(row.hgnc_id))}`;
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

function formatDecimal(value: unknown, digits: number): string {
  const numberValue = numericValue(value);
  return numberValue == null ? 'NA' : numberValue.toFixed(digits);
}

function formatPercentile(value: unknown): string {
  const numberValue = numericValue(value);
  return numberValue == null ? 'NA' : `${numberValue.toFixed(1)}%`;
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
    case 'moderate':
      return 'info';
    default:
      return 'light';
  }
}

function isKnownGene(value: unknown): boolean {
  return value === true || value === 1 || value === '1' || value === 'true';
}

function parseHpoPredictions(value: unknown): Array<Record<string, unknown>> {
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

function topHpoLabel(value: unknown, count: unknown): string {
  const predictions = parseHpoPredictions(value);
  const first = predictions[0];
  const label = first?.phenotype_name ?? first?.term_name ?? first?.phenotype_id ?? first?.hpo_id;
  const totalPredicted = numericValue(count);

  if (label) {
    return totalPredicted && totalPredicted > 1
      ? `${String(label)} +${totalPredicted - 1}`
      : String(label);
  }

  return totalPredicted ? String(totalPredicted) : 'NA';
}

function topHpoTooltip(value: unknown): string {
  const predictions = parseHpoPredictions(value);
  if (!predictions.length) {
    return 'No predicted HPO terms available.';
  }

  return predictions
    .map((entry) => {
      const label = entry.phenotype_name ?? entry.term_name ?? entry.phenotype_id ?? entry.hpo_id;
      const probability = numericValue(entry.probability ?? entry.score);
      return probability == null ? String(label) : `${String(label)} (${formatDecimal(probability, 3)})`;
    })
    .join('; ');
}

onMounted(() => {
  void loadHpoTermOptions();
  void loadRows();
});
</script>

<style scoped>
.nddscore-gene-toolbar {
  display: flex;
  flex-wrap: wrap;
  align-items: flex-start;
  gap: 0.5rem;
}

.nddscore-gene-toolbar__search {
  flex: 1 1 18rem;
  min-width: min(100%, 16rem);
}

.nddscore-gene-toolbar__pagination {
  flex: 0 1 18rem;
  min-width: min(100%, 15rem);
  margin-left: auto;
}

.nddscore-gene-table__id-link,
.nddscore-gene-table__gene-link {
  text-decoration: none;
}

.nddscore-gene-table__numeric {
  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
}

.nddscore-gene-table__chip {
  min-width: 2.5rem;
  font-weight: 700;
}

.nddscore-gene-table__hpo {
  display: inline-block;
  max-width: 18rem;
  overflow: hidden;
  text-overflow: ellipsis;
  vertical-align: bottom;
  cursor: help;
}

.nddscore-gene-table__range-filter {
  display: grid;
  grid-template-columns: minmax(4rem, 1fr) minmax(4rem, 1fr);
  gap: 0.25rem;
}

.nddscore-gene-table__empty {
  padding: 1.5rem;
  color: var(--neutral-600, #757575);
  text-align: center;
}

:deep(.entities-table) {
  min-width: 92rem;
}

:deep(.entities-table th) {
  color: var(--neutral-600, #757575);
  font-size: 0.75rem;
  font-weight: 700;
  white-space: nowrap;
}

:deep(.entities-table td) {
  white-space: nowrap;
}

:deep(.entities-table thead input),
:deep(.entities-table thead select) {
  min-width: 7.5rem;
}

:deep(.entities-table thead select[multiple]) {
  min-width: 12rem;
}

@media (max-width: 767.98px) {
  .nddscore-gene-toolbar__pagination {
    margin-left: 0;
  }
}
</style>
