<template>
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

    <!-- Desktop: fixed-layout prediction table -->
    <div class="d-none d-md-block">
      <GenericTable
        :items="rows"
        :fields="fields"
        :sort-by="sortBy"
        :fixed-layout="true"
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
              :class="rangeFilterDropdownClass(field)"
              :toggle-class="rangeFilterToggleClass(field)"
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
              class="nddscore-gene-table__filter-control"
              @click="removeSearch"
              @update:model-value="handleColumnFilterChange"
            />

            <BFormSelect
              v-else-if="field.filterType === 'select'"
              v-model="columnFilters[field.key]"
              :options="selectOptionsFor(field)"
              size="sm"
              :class="filterControlClass(field.key)"
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
              :class="hpoFilterDropdownClass"
              :toggle-class="hpoFilterToggleClass"
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
    </div>

    <!-- Mobile: purpose-built prediction record rows -->
    <div class="d-md-none">
      <NddScoreGeneMobileRows :items="rows" />
    </div>

    <div v-if="!loading && !rows.length" class="nddscore-gene-table__empty">
      No gene predictions found.
    </div>
    <BAlert v-if="loadError" variant="warning" show class="mt-3 mb-0">
      <i class="bi bi-exclamation-triangle-fill me-1" aria-hidden="true" />
      {{ loadError }}
    </BAlert>
  </TableShell>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue';
import { RouterLink } from 'vue-router';
import {
  BBadge,
  BAlert,
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
import { fetchGenePredictions, fetchHpoTerms, type NddScoreGenePrediction } from '@/api/nddscore';
import GeneBadge from '@/components/ui/GeneBadge.vue';
import TableShell from '@/components/table/TableShell.vue';
import GenericTable from '@/components/small/GenericTable.vue';
import NddScoreGeneMobileRows from './NddScoreGeneMobileRows.vue';
import TableSearchInput from '@/components/small/TableSearchInput.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';
import TableDownloadLinkCopyButtons from '@/components/small/TableDownloadLinkCopyButtons.vue';
import { useExcelExport } from '@/composables/useExcelExport';
import { withReturnTo } from '@/utils/returnNavigation';
import {
  buildNddScoreGeneApiFilters,
  buildNddScoreGeneFilterString,
  parseNddScoreGeneFilterClauses,
  type NddScoreGeneRangeOperator,
} from './nddScoreGeneTableFilters';
import {
  nddScoreGeneFields,
  nddScoreGeneColumnHelp,
  nddScoreRangeOperatorOptions,
  type NddScoreGeneFieldDefinition,
  type NddScoreGeneFieldKey,
} from './nddScoreGeneTableColumns';
import {
  displayValue,
  formatDecimal,
  formatPercentile,
  riskVariant,
  confidenceVariant,
  isKnownGene,
  topHpoLabel,
  topHpoTooltip,
} from './nddScoreGeneTableFormatters';
import {
  nddScoreSelectOptionsFor,
  nddScoreRangeValuePlaceholder,
  nddScoreRangeFilterLabel,
  nddScoreFilterDropdownToggleClass,
  nddScoreFilterDropdownClass,
  nddScoreFilterControlClass,
  nddScoreHpoTermOption,
  type NddScoreSelectOption,
} from './nddScoreGeneTableFilterUi';

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

type FieldKey = NddScoreGeneFieldKey;
type FieldDefinition = NddScoreGeneFieldDefinition;

type RangeOperator = NddScoreGeneRangeOperator;
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
const loadError = ref('');
const search = ref('');
const sort = ref('rank');
const hpoTermFilter = ref<string[]>([]);
const hpoTermOptions = ref<NddScoreSelectOption[]>([]);
const hpoTermSearch = ref('');
let requestSerial = 0;
const { isExporting, exportToExcel } = useExcelExport();

const rangeOperatorOptions = nddScoreRangeOperatorOptions;
const fields: FieldDefinition[] = nddScoreGeneFields;

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

const columnHelp = nddScoreGeneColumnHelp;

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

const hpoFilterToggleClass = computed(() =>
  nddScoreFilterDropdownToggleClass(hpoTermFilter.value.length === 0)
);

const hpoFilterDropdownClass = computed(() =>
  nddScoreFilterDropdownClass(hpoTermFilter.value.length === 0)
);

function normalizeRows(data: NddScoreGenePrediction[] | undefined): GenePredictionRow[] {
  return (data ?? []).map((row) => row as GenePredictionRow);
}

async function loadHpoTermOptions() {
  try {
    hpoTermOptions.value = (await fetchHpoTerms())
      .map(nddScoreHpoTermOption)
      .filter((option): option is NddScoreSelectOption => option != null);
  } catch {
    hpoTermOptions.value = [];
  }
}

function selectOptionsFor(field: FieldDefinition): NddScoreSelectOption[] {
  return nddScoreSelectOptionsFor(field);
}

function rangeKey(key: FieldKey): RangeFieldKey {
  return key as RangeFieldKey;
}

function rangeValuePlaceholder(field: FieldDefinition): string {
  return nddScoreRangeValuePlaceholder(rangeFilters[rangeKey(field.key)].operator);
}

function rangeFilterLabel(field: FieldDefinition): string {
  return nddScoreRangeFilterLabel(field, rangeFilters[rangeKey(field.key)]);
}

function rangeFilterToggleClass(field: FieldDefinition): string {
  return nddScoreFilterDropdownToggleClass(rangeFilters[rangeKey(field.key)].operator === 'any');
}

function rangeFilterDropdownClass(field: FieldDefinition): Record<string, boolean> {
  return nddScoreFilterDropdownClass(rangeFilters[rangeKey(field.key)].operator === 'any');
}

function filterControlClass(key: FieldKey): Record<string, boolean> {
  return nddScoreFilterControlClass(!columnFilters[key]);
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

function activeFilterString(): string {
  return buildNddScoreGeneFilterString({
    search: search.value,
    columnFilters,
    rangeFilters,
    hpoTerms: hpoTermFilter.value,
  });
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
  return parseNddScoreGeneFilterClauses(filterString);
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

async function loadRows() {
  const serial = ++requestSerial;
  loading.value = true;
  loadError.value = '';

  try {
    const apiFilters = buildNddScoreGeneApiFilters({
      search: search.value,
      columnFilters,
      rangeFilters,
      hpoTerms: hpoTermFilter.value,
    });

    const result = await fetchGenePredictions({
      sort: normalizedSortForApi(),
      ...apiFilters,
      page: page.value,
      pageSize: pageSize.value,
      hgncId: undefined,
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
  } catch {
    if (serial === requestSerial) {
      rows.value = [];
      total.value = 0;
      loadError.value = 'NDDScore predictions are not available for the active release.';
      hasLoadedOnce.value = true;
    }
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

onMounted(() => {
  applyInitialQuery();
  void loadHpoTermOptions();
  void loadRows();
});
</script>

<style scoped src="./NddScoreGeneTable.styles.css"></style>
