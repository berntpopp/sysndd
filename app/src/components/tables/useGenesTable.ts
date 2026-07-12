// components/tables/useGenesTable.ts
//
// State, data loading, cursor pagination, URL sync, filtering and Excel
// export orchestration for the /Genes table. Extracted from TablesGenes.vue
// so the SFC stays a thin shell (the view-logic lives here, the static
// column/filter config lives in geneTableConfig.ts). Composes the shared
// useTableData state container; the gene-specific methods (load, cursor
// pagination, URL sync, export) are implemented here directly — NOT via the
// generic useTableMethods composable — because that composable's
// requestExcel() needs an injected Axios instance, and this controller must
// use the typed `@/api/genes` client instead (#346 Wave 2).
//
// Gene-list cursors are HGNC symbol STRINGS (e.g. "ABCA5"), not numeric ids.
// useTableData's prevItemID/nextItemID/lastItemID refs are typed
// `Ref<number | null>` for the numeric-cursor domains (entities/logs); the
// assignments below intentionally cast through `unknown` because the actual
// runtime values are strings (or the literal "null" sentinel emitted by
// `generate_cursor_pag_inf()` on the R side). This mirrors the untyped
// behaviour of the original Options-API `TablesGenes.vue` byte-for-byte.

import { nextTick, onBeforeUnmount, onMounted, ref, watch, type Ref } from 'vue';
// Import composables from the barrel so view specs that mock '@/composables'
// (e.g. TablesGenes.spec.ts) intercept these the same way the SFC did.
import {
  useToast,
  useUrlParsing,
  useColorAndSymbols,
  useText,
  useTableData,
  useColumnTooltip,
} from '@/composables';
import { useUiStore } from '@/stores/ui';
import { withReturnTo } from '@/utils/returnNavigation';
import { listGenes, listGenesXlsx, type PaginatedGeneResponse } from '@/api/genes';
import { createTableRequestCoordinator, createTableRequestOwner } from '@/utils/tableRequestCoordinator';
import { GENE_TABLE_FIELDS, GENE_TABLE_DETAIL_FIELDS, type GeneTableField } from './geneTableConfig';

// Module-level coordinator so it survives component remounts (Vue Router
// remounts this component on URL changes); a per-instance coordinator would
// lose its in-flight/recent-response bookkeeping on every navigation.
const genesRequestCoordinator = createTableRequestCoordinator<PaginatedGeneResponse>();

export interface GeneFilterField {
  content: string | string[] | null;
  join_char: string | null;
  operator: string;
}

export type GeneFilter = Record<string, GeneFilterField>;

// Single source of truth for the empty gene-filter shape (used by both the
// initial filter ref and removeFilters(), avoiding drift between the two).
export function createEmptyGeneFilter(): GeneFilter {
  return {
    any: { content: null, join_char: null, operator: 'contains' },
    entity_id: { content: null, join_char: null, operator: 'contains' },
    symbol: { content: null, join_char: null, operator: 'contains' },
    disease_ontology_name: { content: null, join_char: null, operator: 'contains' },
    disease_ontology_id_version: { content: null, join_char: null, operator: 'contains' },
    hpo_mode_of_inheritance_term_name: { content: null, join_char: ',', operator: 'any' },
    hpo_mode_of_inheritance_term: { content: null, join_char: ',', operator: 'any' },
    ndd_phenotype_word: { content: null, join_char: null, operator: 'contains' },
    category: { content: null, join_char: ',', operator: 'any' },
    entities_count: { content: null, join_char: ',', operator: 'any' },
  };
}

export interface UseGenesTableProps {
  apiEndpoint?: string;
  sortInput?: string;
  filterInput?: string | null;
  pageAfterInput?: string;
  pageSizeInput?: number;
}

/** Shape of one `meta[0]` row returned by `GET /api/gene`. */
interface GeneListMeta {
  totalItems: number;
  currentPage: number;
  totalPages: number;
  prevItemID: string | number;
  currentItemID: string | number;
  nextItemID: string | number;
  lastItemID: string | number;
  executionTime: number;
  // The API returns the flat fspec array directly at meta[0].fspec (not
  // nested under a further `.fspec` key) — see TablesEntities.vue's
  // identical `this.fields = data.meta[0].fspec` pattern.
  fspec: unknown;
}

export function useGenesTable(props: UseGenesTableProps) {
  const requestConsumer = {};
  const requestOwner = createTableRequestOwner();
  const { makeToast } = useToast();
  const { filterObjToStr, filterStrToObj, sortStringToVariables } = useUrlParsing();
  const colorAndSymbols = useColorAndSymbols();
  const text = useText();
  const { getTooltipText } = useColumnTooltip();

  const tableData = useTableData({
    pageSizeInput: props.pageSizeInput,
    sortInput: props.sortInput,
    pageAfterInput: props.pageAfterInput,
  });

  // Component-specific filter
  const filter = ref<GeneFilter>(createEmptyGeneFilter());

  // ── Local state (was data()) ─────────────────────────────────────────────
  const isInitializing = ref(true);
  const loadDataDebounceTimer = ref<ReturnType<typeof setTimeout> | null>(null);
  const totalPages = ref(0);
  const fields = ref<GeneTableField[]>([...GENE_TABLE_FIELDS]);
  const fields_details = ref<GeneTableField[]>([...GENE_TABLE_DETAIL_FIELDS]);

  // Pull the table-state refs referenced by name below.
  const {
    items,
    totalRows,
    currentPage,
    currentItemID,
    prevItemID,
    nextItemID,
    lastItemID,
    executionTime,
    perPage,
    sortBy,
    sort,
    filter_string,
    downloading,
    loading,
    isBusy,
  } = tableData;

  // ── Methods ────────────────────────────────────────────────────────────
  function withCurrentReturnTo(path: string): string {
    return withReturnTo(path);
  }

  // Update browser URL with current table state. Uses history.replaceState
  // instead of router.replace to prevent component remount.
  function updateBrowserUrl(): void {
    if (isInitializing.value) return;

    const searchParams = new URLSearchParams();
    if (sort.value) {
      searchParams.set('sort', sort.value);
    }
    if (filter_string.value) {
      searchParams.set('filter', filter_string.value);
    }
    // Genes uses string IDs (gene symbols like "ABCA5"), not numeric IDs.
    if (currentItemID.value && currentItemID.value !== 0) {
      searchParams.set('page_after', String(currentItemID.value));
    }
    searchParams.set('page_size', String(perPage.value));

    const newUrl = `${window.location.pathname}?${searchParams.toString()}`;
    window.history.replaceState({ ...window.history.state }, '', newUrl);
  }

  function filtered(): void {
    const filter_string_loc = filterObjToStr(filter.value);
    if (filter_string_loc !== filter_string.value) {
      filter_string.value = filter_string_loc;
    }
    loadData();
  }

  function handlePageChange(value: number): void {
    if (value === 1) {
      currentItemID.value = 0;
    } else if (value === totalPages.value) {
      currentItemID.value = lastItemID.value as unknown as number | string;
    } else if (value > currentPage.value) {
      currentItemID.value = nextItemID.value as unknown as number | string;
    } else if (value < currentPage.value) {
      currentItemID.value = prevItemID.value as unknown as number | string;
    }
    filtered();
  }

  function handlePerPageChange(newPerPage: number | string): void {
    perPage.value = parseInt(String(newPerPage), 10);
    currentItemID.value = 0;
    filtered();
  }

  function handleSortByOrDescChange(): void {
    currentItemID.value = 0;
    const sortColumn = sortBy.value.length > 0 ? sortBy.value[0].key : '';
    const sortOrder = sortBy.value.length > 0 ? sortBy.value[0].order : 'asc';
    const isDesc = sortOrder === 'desc';
    sort.value = (isDesc ? '-' : '+') + sortColumn;
    filtered();
  }

  function handleSortByUpdate(newSortBy: Array<{ key: string; order: 'asc' | 'desc' }>): void {
    sortBy.value = newSortBy;
    // handleSortByOrDescChange is triggered by the sortBy watcher below.
  }

  // Debounced loadData to prevent duplicate calls from multiple triggers
  // (e.g. the filter watcher firing alongside a direct filtered() call).
  function loadData(): void {
    if (requestOwner.isDisposed()) return;
    const intent = requestOwner.beginIntent();
    if (loadDataDebounceTimer.value) {
      clearTimeout(loadDataDebounceTimer.value);
    }
    loadDataDebounceTimer.value = setTimeout(() => {
      loadDataDebounceTimer.value = null;
      void doLoadData(intent);
    }, 50);
  }

  async function doLoadData(intent = requestOwner.beginIntent()): Promise<void> {
    const currentUrlParam = () =>
      `sort=${sort.value}&filter=${filter_string.value}&page_after=${currentItemID.value}&page_size=${perPage.value}`;

    const isCurrentIntent = () => requestOwner.isCurrent(intent);
    if (!isCurrentIntent()) return;
    isBusy.value = true;

    const result = await genesRequestCoordinator.request({
      consumer: requestConsumer,
      params: currentUrlParam(),
      fetcher: () =>
        listGenes({
          sort: sort.value,
          filter: filter_string.value,
          page_after: String(currentItemID.value ?? ''),
          page_size: String(perPage.value),
      }),
      apply: (data, source) => {
        applyApiResponse(data, isCurrentIntent);
        if (source === 'network') {
          // Update URL AFTER API success to prevent component remount during
          // the API call.
          updateBrowserUrl();
        }
      },
      onError: (e) => {
        makeToast(e, 'Error', 'danger');
      },
      isCurrent: (params) => isCurrentIntent() && currentUrlParam() === params,
    });

    if (result.handled) {
      isBusy.value = false;
      loading.value = false;
    }
  }

  /**
   * Apply API response data to component state. Extracted to allow reuse
   * when skipping duplicate API calls (see doLoadData's `apply` callback).
   */
  function applyApiResponse(
    data: PaginatedGeneResponse,
    isCurrentIntent: () => boolean = () => true
  ): void {
    const meta = data.meta[0] as GeneListMeta;

    items.value = data.data;
    totalRows.value = meta.totalItems;
    // this solves an update issue in b-pagination component
    // based on https://github.com/bootstrap-vue/bootstrap-vue/issues/3541
    void nextTick(() => {
      if (isCurrentIntent()) currentPage.value = meta.currentPage;
    });
    totalPages.value = meta.totalPages;
    prevItemID.value = meta.prevItemID as unknown as number | null;
    currentItemID.value = meta.currentItemID;
    nextItemID.value = meta.nextItemID as unknown as number | null;
    lastItemID.value = meta.lastItemID as unknown as number | null;
    executionTime.value = meta.executionTime;
    fields.value = meta.fspec as unknown as GeneTableField[];

    const uiStore = useUiStore();
    uiStore.requestScrollbarUpdate();
  }

  function copyLinkToClipboard(): void {
    const urlParam = `sort=${sort.value}&filter=${filter_string.value}&page_after=${currentItemID.value}&page_size=${perPage.value}`;
    void navigator.clipboard.writeText(
      `${import.meta.env.VITE_URL + window.location.pathname}?${urlParam}`
    );
  }

  function removeFilters(): void {
    filter.value = createEmptyGeneFilter();
  }

  function removeSearch(): void {
    filter.value.any.content = null;
    filtered();
  }

  /**
   * Requests and downloads the current table view as an Excel file. Mirrors
   * useTableMethods.requestExcel(), but uses the typed `listGenesXlsx()`
   * client instead of an injected Axios instance. Filename stays
   * `sysndd_<apiEndpoint>_table.xlsx` (`sysndd_gene_table.xlsx` by default).
   */
  async function requestExcel(): Promise<void> {
    downloading.value = true;

    try {
      const blob = await listGenesXlsx({
        sort: sort.value,
        filter: filter_string.value,
        page_after: '0',
        page_size: 'all',
      });

      const fileURL = window.URL.createObjectURL(new Blob([blob]));
      const fileLink = document.createElement('a');
      fileLink.setAttribute('download', `sysndd_${props.apiEndpoint ?? 'gene'}_table.xlsx`);
      fileLink.href = fileURL;
      document.body.appendChild(fileLink);
      fileLink.click();
      document.body.removeChild(fileLink);
      window.URL.revokeObjectURL(fileURL);
    } catch (e) {
      makeToast(e, 'Error', 'danger');
    } finally {
      downloading.value = false;
    }
  }

  function truncate(str: string, n: number): string {
    return str.length > n ? `${str.substr(0, n - 1)}...` : str;
  }

  // ── Watchers ───────────────────────────────────────────────────────────
  // Skip during initialization to prevent multiple API calls on mount.
  watch(
    filter,
    () => {
      if (isInitializing.value) return;
      filtered();
    },
    { deep: true }
  );
  watch(
    sortBy as Ref<Array<{ key: string; order: 'asc' | 'desc' }>>,
    () => {
      if (isInitializing.value) return;
      handleSortByOrDescChange();
    },
    { deep: true }
  );

  // ── Lifecycle (was mounted) ──────────────────────────────────────────────
  onMounted(() => {
    // Transform input sort string to Bootstrap-Vue-Next array format
    if (props.sortInput) {
      const sort_object = sortStringToVariables(props.sortInput);
      sortBy.value = sort_object.sortBy;
      sort.value = props.sortInput; // Also set the sort string for API calls
    }

    // Initialize pagination from URL if provided
    if (props.pageAfterInput && props.pageAfterInput !== '0' && props.pageAfterInput !== '') {
      currentItemID.value = props.pageAfterInput;
    }

    // Transform input filter string to object and load data. Use $nextTick
    // to ensure Vue reactivity is fully initialized.
    void nextTick(() => {
      if (requestOwner.isDisposed()) return;
      if (props.filterInput && props.filterInput !== 'null' && props.filterInput !== '') {
        // Parse URL filter string into filter object for proper UI state
        filter.value = filterStrToObj(props.filterInput, filter.value) as GeneFilter;
        // Also set filter_string so the API call uses the URL filter
        filter_string.value = props.filterInput;
      }
      // Load data first while still in initializing state
      loadData();
      // Delay marking initialization complete to ensure watchers triggered
      // by filter/sortBy changes above see isInitializing=true
      void nextTick(() => {
        if (!requestOwner.isDisposed()) isInitializing.value = false;
      });
    });
  });

  onBeforeUnmount(() => {
    requestOwner.dispose();
    if (loadDataDebounceTimer.value) clearTimeout(loadDataDebounceTimer.value);
  });

  return {
    // composable passthroughs (spread for template/vm access parity)
    ...colorAndSymbols,
    ...text,
    ...tableData,
    filterObjToStr,
    filterStrToObj,
    sortStringToVariables,
    getTooltipText,
    // local state
    filter,
    isInitializing,
    loadDataDebounceTimer,
    totalPages,
    fields,
    fields_details,
    // methods
    withCurrentReturnTo,
    updateBrowserUrl,
    filtered,
    handlePageChange,
    handlePerPageChange,
    handleSortByOrDescChange,
    handleSortByUpdate,
    loadData,
    doLoadData,
    applyApiResponse,
    copyLinkToClipboard,
    removeFilters,
    removeSearch,
    requestExcel,
    truncate,
  };
}
