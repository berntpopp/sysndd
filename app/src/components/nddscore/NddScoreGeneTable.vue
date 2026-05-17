<template>
  <div class="container-fluid">
    <div class="container-fluid">
      <BContainer fluid>
        <BRow class="justify-content-md-center py-2">
          <BCol col md="12">
            <NddScorePredictionCard class="mb-3" />
            <TableShell
              title="Gene predictions"
              :meta="totalLabel"
              description="Machine-learning NDDScore gene association predictions from the active release; these are not manually curated SysNDD classifications."
              :loading="tableShellLoading"
            >
              <template #actions>
                <h5 class="mb-1 text-end font-weight-bold">
                  <TableDownloadLinkCopyButtons
                    :downloading="isExporting"
                    remove-filters-title="Click to remove all filters."
                    :remove-filters-variant="hasActiveFilters ? 'warning' : 'info'"
                    @request-excel="requestExcel"
                    @copy-link="copyLinkToClipboard"
                    @remove-filters="removeFilters"
                  />
                </h5>
              </template>

              <template #toolbar>
                <BRow>
                  <BCol class="my-1" sm="8">
                    <TableSearchInput
                      v-model="search"
                      placeholder="Search gene symbol or HGNC ID"
                      :debounce-time="350"
                      :loading="loading"
                      @update:model-value="handleSearchChange"
                      @clear="handleSearchChange"
                    />
                  </BCol>

                  <BCol class="my-1" sm="4">
                    <BContainer>
                      <TablePaginationControls
                        :total-rows="total"
                        :initial-per-page="pageSize"
                        :current-page="page"
                        :page-options="[10, 25, 50, 100]"
                        @page-change="handlePageChange"
                        @per-page-change="handlePageSizeChange"
                      />
                    </BContainer>
                  </BCol>
                </BRow>
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
                    <BDropdown
                      v-if="field.filterType === 'range'"
                      :auto-close="false"
                      variant="outline-secondary"
                      size="sm"
                      class="nddscore-gene-table__filter-dropdown"
                      menu-class="nddscore-gene-table__filter-menu"
                      :aria-label="`${field.label} filter`"
                    >
                      <template #button-content>
                        {{ rangeFilterLabel(field) }}
                      </template>

                      <BDropdownForm class="nddscore-gene-table__range-menu" @submit.prevent>
                        <BFormSelect
                          v-model="rangeFilters[rangeKey(field.key)].operator"
                          :options="rangeOperatorOptions"
                          size="sm"
                          :aria-label="`${field.label} filter operator`"
                          @update:model-value="handleRangeOperatorChange(field.key)"
                        />
                        <BFormInput
                          v-if="rangeFilters[rangeKey(field.key)].operator !== 'any'"
                          v-model="rangeFilters[rangeKey(field.key)].value"
                          :aria-label="`${field.label} filter value`"
                          :placeholder="rangeValuePlaceholder(field)"
                          type="number"
                          :step="field.numericStep ?? '1'"
                          size="sm"
                          @click="removeSearch"
                          @update:model-value="handleColumnFilterChange"
                        />
                        <BFormInput
                          v-if="rangeFilters[rangeKey(field.key)].operator === 'range'"
                          v-model="rangeFilters[rangeKey(field.key)].valueMax"
                          :aria-label="`${field.label} upper filter value`"
                          placeholder="to"
                          type="number"
                          :step="field.numericStep ?? '1'"
                          size="sm"
                          @click="removeSearch"
                          @update:model-value="handleColumnFilterChange"
                        />
                      </BDropdownForm>
                      <BDropdownDivider />
                      <div class="nddscore-gene-table__filter-actions">
                        <BButton
                          variant="link"
                          size="sm"
                          class="text-decoration-none p-0"
                          :disabled="rangeFilters[rangeKey(field.key)].operator === 'any'"
                          @click="clearRangeFilter(field.key)"
                        >
                          Clear
                        </BButton>
                      </div>
                    </BDropdown>

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

                    <BDropdown
                      v-else-if="field.filterType === 'multi-select'"
                      :auto-close="false"
                      variant="outline-secondary"
                      size="sm"
                      class="nddscore-gene-table__filter-dropdown"
                      menu-class="nddscore-gene-table__hpo-menu"
                      aria-label="Predicted HPO terms"
                      data-testid="nddscore-hpo-filter"
                    >
                      <template #button-content>
                        {{ hpoFilterLabel }}
                      </template>

                      <BDropdownForm @submit.prevent>
                        <BFormInput
                          v-model="hpoTermSearch"
                          placeholder="Search HPO terms"
                          type="search"
                          size="sm"
                          autocomplete="off"
                          aria-label="Search HPO terms"
                        />
                      </BDropdownForm>
                      <BDropdownDivider />
                      <div class="nddscore-gene-table__hpo-options">
                        <BDropdownItemButton
                          v-for="option in filteredHpoTermOptions"
                          :key="option.value"
                          :active="hpoTermFilter.includes(option.value)"
                          :data-testid="`nddscore-hpo-option-${option.value}`"
                          @click="toggleHpoTerm(option.value)"
                        >
                          <i
                            class="bi me-2"
                            :class="
                              hpoTermFilter.includes(option.value)
                                ? 'bi-check-square text-primary'
                                : 'bi-square text-muted'
                            "
                            aria-hidden="true"
                          />
                          {{ option.text }}
                        </BDropdownItemButton>
                        <BDropdownText v-if="filteredHpoTermOptions.length === 0">
                          No matching HPO terms
                        </BDropdownText>
                      </div>
                      <BDropdownDivider />
                      <div class="nddscore-gene-table__filter-actions">
                        <BButton
                          variant="link"
                          size="sm"
                          class="text-decoration-none p-0"
                          :disabled="!hpoTermFilter.length"
                          @click="clearHpoTerms"
                        >
                          Clear
                        </BButton>
                      </div>
                    </BDropdown>
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
                  <span class="nddscore-gene-table__numeric">{{
                    formatDecimal(row.ndd_score, 3)
                  }}</span>
                </template>

                <template #cell-rank="{ row }">
                  <span class="nddscore-gene-table__numeric">{{ displayValue(row.rank) }}</span>
                </template>

                <template #cell-percentile="{ row }">
                  <span class="nddscore-gene-table__numeric">{{
                    formatPercentile(row.percentile)
                  }}</span>
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
          </BCol>
        </BRow>
      </BContainer>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue';
import { RouterLink } from 'vue-router';
import {
  BBadge,
  BButton,
  BCol,
  BContainer,
  BDropdown,
  BDropdownDivider,
  BDropdownForm,
  BDropdownItemButton,
  BDropdownText,
  BFormInput,
  BFormSelect,
  BRow,
} from 'bootstrap-vue-next';
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
import TableDownloadLinkCopyButtons from '@/components/small/TableDownloadLinkCopyButtons.vue';
import NddScorePredictionCard from '@/components/nddscore/NddScorePredictionCard.vue';
import { useExcelExport } from '@/composables/useExcelExport';
import { withReturnTo } from '@/utils/returnNavigation';

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

type RangeOperator = 'any' | 'gte' | 'lte' | 'eq' | 'range';
type RangeFieldKey = 'ndd_score' | 'rank' | 'percentile';
type RangeFilterState = {
  operator: RangeOperator;
  value: string;
  valueMax: string;
};
type UrlFilterClause = {
  operator: string;
  key: string;
  values: string[];
};

const rows = ref<GenePredictionRow[]>([]);
const total = ref(0);
const page = ref(1);
const pageSize = ref(10);
const loading = ref(false);
const hasLoadedOnce = ref(false);
const search = ref('');
const sort = ref('rank');
const hpoTermFilter = ref<string[]>([]);
const hpoTermOptions = ref<Array<{ value: string; text: string }>>([]);
const hpoTermSearch = ref('');
let requestSerial = 0;
const { isExporting, exportToExcel } = useExcelExport();

const rangeOperatorOptions = [
  { value: 'any', text: 'Any' },
  { value: 'gte', text: '>=' },
  { value: 'lte', text: '<=' },
  { value: 'eq', text: '=' },
  { value: 'range', text: 'Range' },
];

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

const rangeFilters = reactive<Record<RangeFieldKey, RangeFilterState>>({
  ndd_score: { operator: 'any', value: '', valueMax: '' },
  rank: { operator: 'any', value: '', valueMax: '' },
  percentile: { operator: 'any', value: '', valueMax: '' },
});

const columnHelp: Record<string, string> = {
  gene_symbol: 'Gene symbol linked to the NDDScore prediction detail page.',
  ndd_score:
    'Model probability-like score for NDD gene candidacy; higher is stronger model support.',
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
const tableShellLoading = computed(() => loading.value && !hasLoadedOnce.value);
const hasActiveFilters = computed(
  () =>
    search.value.trim() !== '' ||
    Object.values(columnFilters).some((value) => value.trim() !== '') ||
    Object.values(rangeFilters).some((state) => state.operator !== 'any') ||
    hpoTermFilter.value.length > 0
);
const sortBy = computed(() => [
  {
    key: sort.value.replace(/^[+-]/, ''),
    order: sort.value.startsWith('-') ? 'desc' : 'asc',
  },
]);
const filteredHpoTermOptions = computed(() => {
  const query = hpoTermSearch.value.trim().toLowerCase();
  if (!query) {
    return hpoTermOptions.value;
  }
  return hpoTermOptions.value.filter(
    (option) =>
      option.value.toLowerCase().includes(query) || option.text.toLowerCase().includes(query)
  );
});
const hpoFilterLabel = computed(() => {
  if (hpoTermFilter.value.length === 0) {
    return 'Any HPO';
  }
  if (hpoTermFilter.value.length === 1) {
    return hpoTermFilter.value[0];
  }
  return `${hpoTermFilter.value.length} HPO terms`;
});

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

function rangeKey(key: FieldKey): RangeFieldKey {
  return key as RangeFieldKey;
}

function rangeValuePlaceholder(field: FieldDefinition): string {
  const operator = rangeFilters[rangeKey(field.key)].operator;
  if (operator === 'range') {
    return 'from';
  }
  return 'value';
}

function rangeFilterLabel(field: FieldDefinition): string {
  const state = rangeFilters[rangeKey(field.key)];
  if (state.operator === 'any') {
    return `Any ${field.label}`;
  }
  if (state.operator === 'range') {
    return state.value && state.valueMax
      ? `${state.value}-${state.valueMax}`
      : `${field.label} range`;
  }
  const operatorLabel = rangeOperatorOptions.find(
    (option) => option.value === state.operator
  )?.text;
  return state.value ? `${operatorLabel} ${state.value}` : `${field.label} ${operatorLabel}`;
}

function handleRangeOperatorChange(key: FieldKey) {
  const state = rangeFilters[rangeKey(key)];
  if (state.operator === 'any') {
    state.value = '';
    state.valueMax = '';
    handleColumnFilterChange();
  } else if (state.operator !== 'range') {
    state.valueMax = '';
  }
  removeSearch();
}

function clearRangeFilter(key: FieldKey) {
  const state = rangeFilters[rangeKey(key)];
  state.operator = 'any';
  state.value = '';
  state.valueMax = '';
  handleColumnFilterChange();
}

function rangeMin(key: RangeFieldKey): number | undefined {
  const state = rangeFilters[key];
  if (state.operator === 'gte' || state.operator === 'range') {
    return numberFilter(state.value);
  }
  if (state.operator === 'eq') {
    return numberFilter(state.value);
  }
  return undefined;
}

function rangeMax(key: RangeFieldKey): number | undefined {
  const state = rangeFilters[key];
  if (state.operator === 'lte') {
    return numberFilter(state.value);
  }
  if (state.operator === 'range') {
    return numberFilter(state.valueMax);
  }
  if (state.operator === 'eq') {
    return numberFilter(state.value);
  }
  return undefined;
}

function toggleHpoTerm(value: string) {
  if (hpoTermFilter.value.includes(value)) {
    hpoTermFilter.value = hpoTermFilter.value.filter((term) => term !== value);
  } else {
    hpoTermFilter.value = [...hpoTermFilter.value, value];
  }
  removeSearch();
  handleColumnFilterChange();
}

function clearHpoTerms() {
  hpoTermFilter.value = [];
  hpoTermSearch.value = '';
  handleColumnFilterChange();
}

async function requestExcel() {
  await exportToExcel(rows.value, {
    filename: 'nddscore_gene_predictions',
    sheetName: 'NDDScore genes',
  });
}

async function copyLinkToClipboard() {
  await navigator.clipboard?.writeText(window.location.href);
}

function removeFilters() {
  search.value = '';
  Object.keys(columnFilters).forEach((key) => {
    columnFilters[key] = '';
  });
  (Object.keys(rangeFilters) as RangeFieldKey[]).forEach((key) => {
    rangeFilters[key].operator = 'any';
    rangeFilters[key].value = '';
    rangeFilters[key].valueMax = '';
  });
  hpoTermFilter.value = [];
  hpoTermSearch.value = '';
  page.value = 1;
  void loadRows();
}

function encodeFilterValue(value: string): string {
  return value.replace(/[(),]/g, ' ');
}

function activeFilterString(): string {
  const clauses: string[] = [];
  const addClause = (operator: string, key: string, values: string[]) => {
    const cleaned = values.map((value) => encodeFilterValue(value.trim())).filter(Boolean);
    if (cleaned.length) {
      clauses.push(`${operator}(${key},${cleaned.join(',')})`);
    }
  };

  addClause('contains', 'any', [search.value]);
  addClause('equals', 'gene_symbol', [columnFilters.gene_symbol]);
  addClause('equals', 'risk_tier', [columnFilters.risk_tier]);
  addClause('equals', 'confidence_tier', [columnFilters.confidence_tier]);
  addClause('equals', 'known_sysndd_gene', [columnFilters.known_sysndd_gene]);
  addClause('equals', 'model_split', [columnFilters.model_split]);
  addClause('equals', 'top_inheritance_mode', [columnFilters.top_inheritance_mode]);
  (Object.keys(rangeFilters) as RangeFieldKey[]).forEach((key) => {
    const state = rangeFilters[key];
    if (state.operator === 'any') {
      return;
    }
    if (state.operator === 'range') {
      addClause('range', key, [state.value, state.valueMax]);
    } else {
      addClause(state.operator, key, [state.value]);
    }
  });
  addClause('any', 'top_hpo_predictions_json', hpoTermFilter.value);
  return clauses.join(',');
}

function normalizedSortForUrl(): string {
  const sortKey = sort.value.replace(/^[+-]/, '');
  return sort.value.startsWith('-') ? `-${sortKey}` : `+${sortKey}`;
}

function normalizedSortForApi(): string {
  const sortKey = sort.value.replace(/^[+-]/, '');
  return sort.value.startsWith('-') ? `-${sortKey}` : sortKey;
}

function updateBrowserUrl() {
  if (typeof window === 'undefined') {
    return;
  }

  const params = new URLSearchParams();
  params.set('sort', normalizedSortForUrl());
  const filter = activeFilterString();
  if (filter) {
    params.set('filter', filter);
  }
  if (page.value > 1) {
    params.set('page', String(page.value));
  }
  params.set('page_size', String(pageSize.value));

  const query = params.toString();
  const nextUrl = query ? `${window.location.pathname}?${query}` : window.location.pathname;
  window.history.replaceState({ ...window.history.state }, '', nextUrl);
}

function parseFilterClauses(filterString: string | null): UrlFilterClause[] {
  if (!filterString || filterString === 'null') {
    return [];
  }

  return filterString
    .split('),')
    .map((part) => part.replace(/\)$/, ''))
    .map((part) => {
      const match = part.match(/^([^()]+)\(([^,]+),(.*)$/);
      if (!match) {
        return null;
      }
      return {
        operator: match[1].trim(),
        key: match[2].trim(),
        values: match[3]
          .split(',')
          .map((value) => value.trim())
          .filter(Boolean),
      };
    })
    .filter((clause): clause is UrlFilterClause => clause != null);
}

function applyInitialQuery() {
  if (typeof window === 'undefined') {
    return;
  }

  const params = new URLSearchParams(window.location.search);
  sort.value = params.get('sort') || sort.value;
  search.value = '';
  page.value = Math.max(1, Number(params.get('page')) || 1);
  pageSize.value = Math.max(1, Number(params.get('page_size')) || 10);
  Object.keys(columnFilters).forEach((key) => {
    columnFilters[key] = '';
  });
  (Object.keys(rangeFilters) as RangeFieldKey[]).forEach((key) => {
    rangeFilters[key].operator = 'any';
    rangeFilters[key].value = '';
    rangeFilters[key].valueMax = '';
  });
  hpoTermFilter.value = [];

  parseFilterClauses(params.get('filter')).forEach((clause) => {
    const [first = '', second = ''] = clause.values;
    if (clause.key === 'any') {
      search.value = first;
      return;
    }
    if (clause.key in columnFilters) {
      columnFilters[clause.key] = first;
      return;
    }
    if (clause.key === 'top_hpo_predictions_json') {
      hpoTermFilter.value = clause.values;
      return;
    }
    if (clause.key in rangeFilters) {
      const key = clause.key as RangeFieldKey;
      if (clause.operator === 'range') {
        rangeFilters[key].operator = 'range';
        rangeFilters[key].value = first;
        rangeFilters[key].valueMax = second;
      } else if (['gte', 'lte', 'eq'].includes(clause.operator)) {
        rangeFilters[key].operator = clause.operator as RangeOperator;
        rangeFilters[key].value = first;
      }
    }
  });
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
      sort: normalizedSortForApi(),
      search: search.value || undefined,
      nddScoreMin: rangeMin('ndd_score'),
      nddScoreMax: rangeMax('ndd_score'),
      rankMin: rangeMin('rank'),
      rankMax: rangeMax('rank'),
      percentileMin: rangeMin('percentile'),
      percentileMax: rangeMax('percentile'),
      riskTier: columnFilters.risk_tier || undefined,
      confidenceTier: columnFilters.confidence_tier || undefined,
      knownSysnddGene: columnFilters.known_sysndd_gene || undefined,
      page: page.value,
      pageSize: pageSize.value,
      hgncId: undefined,
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
    hasLoadedOnce.value = true;
    updateBrowserUrl();
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
  return withReturnTo(`/NDDScore/Gene/${encodeURIComponent(displayValue(row.hgnc_id))}`);
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
      return probability == null
        ? String(label)
        : `${String(label)} (${formatDecimal(probability, 3)})`;
    })
    .join('; ');
}

onMounted(() => {
  applyInitialQuery();
  void loadHpoTermOptions();
  void loadRows();
});
</script>

<style scoped>
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

.nddscore-gene-table__empty {
  padding: 1.5rem;
  color: var(--neutral-600, #757575);
  text-align: center;
}

.nddscore-gene-table__filter-dropdown {
  width: 100%;
  min-width: 7.5rem;
}

.nddscore-gene-table__filter-dropdown :deep(.btn) {
  width: 100%;
  min-height: calc(1.5em + 0.5rem + 2px);
  padding: 0.25rem 0.5rem;
  overflow: hidden;
  border-color: #dee2e6;
  color: #212529;
  font-size: 0.875rem;
  font-weight: 400;
  text-align: left;
  text-overflow: ellipsis;
  white-space: nowrap;
  background-color: #fff;
}

.nddscore-gene-table__filter-dropdown :deep(.btn:hover),
.nddscore-gene-table__filter-dropdown :deep(.btn:focus) {
  border-color: #86b7fe;
  color: #212529;
  background-color: #fff;
  box-shadow: 0 0 0 0.15rem rgba(13, 110, 253, 0.12);
}

.nddscore-gene-table__range-menu {
  display: grid;
  width: 15rem;
  gap: 0.5rem;
}

.nddscore-gene-table__filter-actions {
  display: flex;
  justify-content: flex-end;
  padding: 0.35rem 0.75rem 0.45rem;
}

:deep(.nddscore-gene-table__filter-menu) {
  min-width: 16rem;
}

:deep(.nddscore-gene-table__hpo-menu) {
  min-width: 22rem;
  max-width: 30rem;
}

.nddscore-gene-table__hpo-options {
  max-height: 16rem;
  overflow-y: auto;
}

.nddscore-gene-table__hpo-options :deep(.dropdown-item) {
  padding: 0.45rem 0.75rem;
  overflow-wrap: anywhere;
  white-space: normal;
}

.nddscore-gene-table__hpo-options :deep(.dropdown-item.active) {
  background-color: #e9f5ff;
  color: #0f172a;
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
</style>
