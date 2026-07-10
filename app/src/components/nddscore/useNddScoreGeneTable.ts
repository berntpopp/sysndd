// Data-loading, URL-sync, filter/pagination state, and action-handler layer
// for the NDDScore gene predictions table (NddScoreGeneTable.vue). Extracted
// so the component stays a thin presentation shell (issue #346). Existing
// filter-construction (nddScoreGeneTableFilters.ts), filter-UI
// (nddScoreGeneTableFilterUi.ts), and column (nddScoreGeneTableColumns.ts)
// modules are reused as-is, not duplicated. NDDScore is a model-derived
// prediction layer, kept separate from curated SysNDD evidence; no
// NDDScore labelling/wording lives here (that stays owned by the component
// template and the column/formatter modules).

import { computed, onMounted, reactive, ref } from 'vue';
import { fetchGenePredictions, fetchHpoTerms, type NddScoreGenePrediction } from '@/api/nddscore';
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
import { displayValue } from './nddScoreGeneTableFormatters';
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

export type GenePredictionRow = NddScoreGenePrediction & {
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

export type SortEvent = {
  sortBy: string;
  sortDesc: boolean;
};

type FieldKey = NddScoreGeneFieldKey;
type FieldDefinition = NddScoreGeneFieldDefinition;

type RangeOperator = NddScoreGeneRangeOperator;
export type RangeFieldKey = 'ndd_score' | 'rank' | 'percentile';
export type RangeFilterState = {
  operator: RangeOperator;
  value: string;
  valueMax: string;
};
type UrlFilterClause = {
  operator: string;
  key: string;
  values: string[];
};

export function useNddScoreGeneTable() {
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

  /**
   * Load the HPO term filter options. Best-effort: an upstream failure
   * degrades to an empty option list rather than surfacing an error, so a
   * lookup outage never blocks the gene predictions table itself.
   */
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

  /** Reset every filter (search, column, range, HPO) and reload page 1. */
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

  /** Hydrate search/column/range/HPO/sort/page/page-size state from the URL. */
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

  /**
   * Load the current page of gene predictions. Guarded by a monotonic
   * request serial: an overlapping load (filter/sort/page change fired
   * before the previous request settled) may only commit its result -- on
   * success or on error -- when it is still the newest in-flight request, so
   * a slow, stale response (success or failure) can never clobber a newer
   * one that already landed.
   */
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

  return {
    // state
    rows,
    total,
    page,
    pageSize,
    loading,
    loadError,
    search,
    hpoTermFilter,
    hpoTermOptions,
    hpoTermSearch,
    isExporting,
    rangeOperatorOptions,
    fields,
    columnFilters,
    rangeFilters,
    columnHelp,
    // computed
    totalLabel,
    tableShellLoading,
    hasActiveFilters,
    sortBy,
    filteredHpoTermOptions,
    hpoFilterLabel,
    hpoFilterToggleClass,
    hpoFilterDropdownClass,
    // template helper functions
    selectOptionsFor,
    rangeKey,
    rangeValuePlaceholder,
    rangeFilterLabel,
    rangeFilterToggleClass,
    rangeFilterDropdownClass,
    filterControlClass,
    handleRangeOperatorChange,
    clearRangeFilter,
    toggleHpoTerm,
    clearHpoTerms,
    requestExcel,
    copyLinkToClipboard,
    removeFilters,
    handleSearchChange,
    handleColumnFilterChange,
    handleSortUpdate,
    handlePageChange,
    handlePageSizeChange,
    removeSearch,
    detailPath,
    // exposed for direct test coverage (load/URL hydration characterization)
    loadRows,
    applyInitialQuery,
  };
}

export default useNddScoreGeneTable;
