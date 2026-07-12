// components/tables/usePhenotypeEntitiesTable.ts
//
// State, phenotype-option loading, cursor pagination, URL sync, and
// AND/OR-filter orchestration for the phenotype-entities search table.
// Extracted from TablesPhenotypes.vue (#346) so the SFC stays a thin shell;
// the phenotype multi-select toolbar markup lives in
// PhenotypeFilterToolbar.vue. Mirrors the useLogTable.ts composable shape.

import { nextTick, onBeforeUnmount, onMounted, ref, watch, type Ref } from 'vue';
import {
  useToast,
  useUrlParsing,
  useColorAndSymbols,
  useText,
  useColumnTooltip,
  useTableData,
} from '@/composables';
import Utils from '@/assets/js/utils';
import { useUiStore } from '@/stores/ui';
import { withReturnTo } from '@/utils/returnNavigation';
import {
  browsePhenotypeEntities,
  browsePhenotypeEntitiesXlsx,
  type BrowsePhenotypeEntitiesResponse,
} from '@/api/phenotype';
import { listPhenotypes, type PhenotypeRow } from '@/api/list';
import { createTableRequestCoordinator, createTableRequestOwner } from '@/utils/tableRequestCoordinator';
import {
  createDefaultPhenotypeFilter,
  phenotypeLogicOperator,
  type PhenotypeTableFilter,
} from './phenotypeTableFilters';
import type { SortBy } from '@/types/components';

const phenotypeEntitiesRequestCoordinator =
  createTableRequestCoordinator<BrowsePhenotypeEntitiesResponse>();

// Module-level cache for the phenotype option list (loaded once, reused
// across remounts) -- mirrors the pre-refactor module-level cache that lived
// directly in TablesPhenotypes.vue.
export type PhenotypeOption = PhenotypeRow;

let modulePhenotypesListCache: PhenotypeOption[] | null = null;
let modulePhenotypesListLoading = false;

export interface UsePhenotypeEntitiesTableProps {
  sortInput?: string;
  filterInput?: string | null;
  pageAfterInput?: string;
  pageSizeInput?: number;
}

const PHENOTYPE_TABLE_FIELDS: Array<Record<string, unknown>> = [
  {
    key: 'entity_id',
    label: 'Entity',
    sortable: true,
    sortDirection: 'desc',
    class: 'text-start',
  },
  {
    key: 'symbol',
    label: 'Gene Symbol',
    sortable: true,
    class: 'text-start',
  },
  {
    key: 'disease_ontology_name',
    label: 'Disease',
    sortable: true,
    class: 'text-start',
  },
  {
    key: 'hpo_mode_of_inheritance_term_name',
    label: 'Inheritance',
    sortable: true,
    class: 'text-start',
  },
  {
    key: 'category',
    label: 'Category',
    sortable: true,
    class: 'text-start',
  },
  {
    key: 'ndd_phenotype_word',
    label: 'NDD',
    sortable: true,
    class: 'text-start',
  },
  {
    key: 'details',
    label: 'Details',
  },
];

const PHENOTYPE_TABLE_FIELDS_DETAILS: Array<Record<string, unknown>> = [
  { key: 'hgnc_id', label: 'HGNC ID', class: 'text-start' },
  {
    key: 'disease_ontology_id_version',
    label: 'Ontology ID version',
    class: 'text-start',
  },
  {
    key: 'disease_ontology_name',
    label: 'Disease ontology name',
    class: 'text-start',
  },
  { key: 'entry_date', label: 'Entry date', class: 'text-start' },
  { key: 'last_update', label: 'Last updated', class: 'text-start' },
];

export function usePhenotypeEntitiesTable(props: UsePhenotypeEntitiesTableProps) {
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
    pageOptions,
    sortBy,
    sort,
    filter_string,
    downloading,
    loading,
    isBusy,
  } = tableData;

  // Preserve the original [10, 25, 50, 200] page-size options; useTableData's
  // shared default ([10, 25, 50, 100]) differs from what this table shipped.
  pageOptions.value = [10, 25, 50, 200];

  // ── Local state (was data()) ─────────────────────────────────────────────
  const isInitializing = ref(true);
  const loadDataDebounceTimer = ref<ReturnType<typeof setTimeout> | null>(null);
  const totalPages = ref(0);
  const phenotypes_options = ref<PhenotypeOption[]>([]);
  const fields = ref<Array<Record<string, unknown>>>([...PHENOTYPE_TABLE_FIELDS]);
  const fields_details = ref<Array<Record<string, unknown>>>([...PHENOTYPE_TABLE_FIELDS_DETAILS]);
  const filter = ref<PhenotypeTableFilter>(createDefaultPhenotypeFilter());
  const checked = ref(false);

  // ── Methods ────────────────────────────────────────────────────────────────
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
    const currentId = Number(currentItemID.value) || 0;
    if (currentId > 0) {
      searchParams.set('page_after', String(currentId));
    }
    searchParams.set('page_size', String(perPage.value));

    const newUrl = `${window.location.pathname}?${searchParams.toString()}`;
    window.history.replaceState({ ...window.history.state }, '', newUrl);
  }

  function copyLinkToClipboard(): void {
    const urlParam = `sort=${sort.value}&filter=${filter_string.value}&page_after=${currentItemID.value}&page_size=${perPage.value}`;
    void navigator.clipboard.writeText(
      `${import.meta.env.VITE_URL + window.location.pathname}?${urlParam}`
    );
  }

  function handleSortByOrDescChange(): void {
    currentItemID.value = 0;
    const sortColumn = sortBy.value.length > 0 ? sortBy.value[0].key : 'entity_id';
    const sortOrder = sortBy.value.length > 0 ? sortBy.value[0].order : 'desc';
    sort.value = (sortOrder === 'desc' ? '-' : '+') + sortColumn;
    filtered();
  }

  /**
   * Handle sort-by updates from Bootstrap-Vue-Next BTable.
   */
  function handleSortByUpdate(newSortBy: SortBy[]): void {
    sortBy.value = newSortBy;
  }

  // Note: intentionally ignores any emitted value (matches the pre-refactor
  // behavior) -- perPage itself is never reassigned from user interaction.
  function handlePerPageChange(): void {
    currentItemID.value = 0;
    filtered();
  }

  function handlePageChange(value: number): void {
    if (value === 1) {
      currentItemID.value = 0;
    } else if (value === totalPages.value) {
      currentItemID.value = Number(lastItemID.value) || 0;
    } else if (value > currentPage.value) {
      currentItemID.value = Number(nextItemID.value) || 0;
    } else if (value < currentPage.value) {
      currentItemID.value = Number(prevItemID.value) || 0;
    }
    filtered();
  }

  function filtered(): void {
    // In-place (idempotent) AND/OR operator; reassigning re-loops the deep
    // watcher (#466).
    filter.value.modifier_phenotype_id.operator = phenotypeLogicOperator(checked.value === true);
    const filter_string_loc = filterObjToStr(filter.value);
    if (filter_string_loc !== filter_string.value) {
      filter_string.value = filterObjToStr(filter.value);
    }

    // Note: updateBrowserUrl() is called in doLoadEntitiesFromPhenotypes()
    // AFTER API success. This prevents component remount during the API call.
    requestSelected();
  }

  function removeFilters(): void {
    filter.value = createDefaultPhenotypeFilter();
  }

  function removeSearch(): void {
    filter.value.any.content = null;
  }

  async function loadPhenotypesList(): Promise<void> {
    // Use cached phenotypes list if available (prevents reload on component remount)
    if (modulePhenotypesListCache) {
      phenotypes_options.value = modulePhenotypesListCache;
      return;
    }

    // Prevent duplicate loading if already in progress
    if (modulePhenotypesListLoading) {
      return;
    }

    modulePhenotypesListLoading = true;
    try {
      const response = await listPhenotypes();
      // The typed `listPhenotypes()` helper always returns the
      // `{ links, meta, data }` envelope per W3 spec; consume that shape
      // directly so any future contract drift fails the build instead of
      // being papered over by a fallback.
      const phenotypeData = response.data;
      modulePhenotypesListCache = phenotypeData;
      phenotypes_options.value = phenotypeData;
    } catch (e) {
      makeToast(e, 'Error', 'danger');
    } finally {
      modulePhenotypesListLoading = false;
    }
  }

  // The modifier_phenotype_id content is always managed as a string[] by
  // this table (createDefaultPhenotypeFilter seeds an array, and
  // filterStrToObj only ever parses it back into an array for the
  // any/all operators this field uses). Narrow defensively instead of
  // trusting the broader FilterField union type.
  function phenotypeIdList(): string[] {
    const entry = filter.value.modifier_phenotype_id;
    if (!Array.isArray(entry.content)) {
      entry.content = [];
    }
    return entry.content as string[];
  }

  /**
   * Toggle phenotype selection.
   */
  function togglePhenotype(phenotypeId: string): void {
    const ids = phenotypeIdList();
    const index = ids.indexOf(phenotypeId);
    if (index === -1) {
      ids.push(phenotypeId);
    } else {
      ids.splice(index, 1);
    }
    filtered();
  }

  /**
   * Clear all selected phenotypes.
   */
  function clearAllPhenotypes(): void {
    filter.value.modifier_phenotype_id.content = [];
    filtered();
  }

  /**
   * Set the logic mode (AND/OR) for phenotype filtering.
   */
  function setLogicMode(isOr: boolean): void {
    checked.value = isOr;
    filtered();
  }

  /**
   * Remove a phenotype from selection.
   */
  function removePhenotype(phenotypeId: string): void {
    const ids = phenotypeIdList();
    const index = ids.indexOf(phenotypeId);
    if (index !== -1) {
      ids.splice(index, 1);
      filtered();
    }
  }

  function loadEntitiesFromPhenotypes(): void {
    if (requestOwner.isDisposed()) return;
    const intent = requestOwner.beginIntent();
    // Debounce to prevent duplicate calls from multiple triggers
    if (loadDataDebounceTimer.value) {
      clearTimeout(loadDataDebounceTimer.value);
    }
    loadDataDebounceTimer.value = setTimeout(() => {
      loadDataDebounceTimer.value = null;
      void doLoadEntitiesFromPhenotypes(intent);
    }, 50);
  }

  async function doLoadEntitiesFromPhenotypes(intent = requestOwner.beginIntent()): Promise<void> {
    const currentUrlParam = () =>
      `sort=${sort.value}&filter=${filter_string.value}&page_after=${currentItemID.value}&page_size=${perPage.value}`;
    const urlParam = currentUrlParam();
    const isCurrentIntent = () => requestOwner.isCurrent(intent);
    if (!isCurrentIntent()) return;
    isBusy.value = true;

    const result = await phenotypeEntitiesRequestCoordinator.request({
      consumer: requestConsumer,
      params: urlParam,
      fetcher: () =>
        browsePhenotypeEntities({
          sort: sort.value,
          filter: filter_string.value,
          page_after: currentItemID.value,
          page_size: String(perPage.value),
      }),
      apply: (data, source) => {
        applyApiResponse(data, isCurrentIntent);
        if (source === 'network') {
          // Update URL AFTER API success to prevent component remount during the API call
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
   * when skipping duplicate API calls.
   */
  function applyApiResponse(
    data: BrowsePhenotypeEntitiesResponse,
    isCurrentIntent: () => boolean = () => true
  ): void {
    const meta = (data.meta as Array<Record<string, unknown>>)[0];
    fields.value = meta.fspec as Array<Record<string, unknown>>;
    items.value = data.data;
    totalRows.value = meta.totalItems as number;
    // this solves an update issue in b-pagination component
    // based on https://github.com/bootstrap-vue/bootstrap-vue/issues/3541
    void nextTick(() => {
      if (isCurrentIntent()) currentPage.value = meta.currentPage as number;
    });
    totalPages.value = meta.totalPages as number;
    prevItemID.value = Number(meta.prevItemID) || 0;
    currentItemID.value = Number(meta.currentItemID) || 0;
    nextItemID.value = Number(meta.nextItemID) || 0;
    lastItemID.value = Number(meta.lastItemID) || 0;
    executionTime.value = meta.executionTime as number;

    const uiStore = useUiStore();
    uiStore.requestScrollbarUpdate();
  }

  function requestSelected(): void {
    if (phenotypeIdList().length > 0) {
      loadEntitiesFromPhenotypes();
    } else {
      requestOwner.beginIntent();
      items.value = [];
      totalRows.value = 0;
      isBusy.value = false;
      loading.value = false;
    }
  }

  function requestSelectedExcel(): void {
    if (phenotypeIdList().length > 0) {
      void requestExcel();
    }
  }

  async function requestExcel(): Promise<void> {
    downloading.value = true;

    try {
      const blob = await browsePhenotypeEntitiesXlsx({
        sort: sort.value,
        filter: filter_string.value,
        page_after: 0,
        page_size: 'all',
      });

      // browsePhenotypeEntitiesXlsx() already returns a Blob (typed
      // `Promise<Blob>` in src/api/phenotype.ts via the apiClient.raw call
      // with responseType: 'blob'). Pass the original Blob straight through.
      const fileURL = window.URL.createObjectURL(blob);
      const fileLink = document.createElement('a');

      fileLink.href = fileURL;
      fileLink.setAttribute('download', 'phenotype_search.xlsx');
      document.body.appendChild(fileLink);

      fileLink.click();
    } catch (e) {
      makeToast(e, 'Error', 'danger');
    }

    downloading.value = false;
  }

  // Function to truncate a string to a specified length. If the string is
  // longer than the specified length, it adds '...' to the end.
  function truncate(str: string, n: number): string {
    return Utils.truncate(str, n);
  }

  // ── Watchers ───────────────────────────────────────────────────────────────
  // Watch for filter changes (deep required for Vue 3 behavior). Skip during
  // initialization to prevent multiple API calls.
  watch(
    filter,
    () => {
      if (isInitializing.value) return;
      filtered();
    },
    { deep: true }
  );
  // Watch for sortBy changes (deep watch for array). Skip during
  // initialization to prevent multiple API calls.
  watch(
    sortBy as Ref<SortBy[]>,
    () => {
      if (isInitializing.value) return;
      handleSortByOrDescChange();
    },
    { deep: true }
  );
  watch(perPage, () => {
    if (isInitializing.value) return;
    handlePerPageChange();
  });

  // ── Lifecycle ─────────────────────────────────────────────────────────────
  // Equivalent to the pre-refactor created() hook: kick the phenotype option
  // list load off as early as possible.
  void loadPhenotypesList();

  onMounted(() => {
    // Transform input sort string to Bootstrap-Vue-Next array format
    if (props.sortInput) {
      const sort_object = sortStringToVariables(props.sortInput);
      sortBy.value = sort_object.sortBy;
      sort.value = props.sortInput; // Also set the sort string for API calls
    }

    // Initialize pagination from URL if provided
    if (props.pageAfterInput && props.pageAfterInput !== '0' && props.pageAfterInput !== '') {
      currentItemID.value = parseInt(props.pageAfterInput, 10) || 0;
    }

    // Transform input filter string to object and load data.
    // Use nextTick to ensure Vue reactivity is fully initialized.
    void nextTick(() => {
      if (requestOwner.isDisposed()) return;
      if (props.filterInput && props.filterInput !== 'null' && props.filterInput !== '') {
        // Parse URL filter string into filter object for proper UI state
        filter.value = filterStrToObj(props.filterInput, filter.value) as PhenotypeTableFilter;
        // Also set filter_string so the API call uses the URL filter
        filter_string.value = props.filterInput;
      }
      // Load data first while still in initializing state
      requestSelected();
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
    isInitializing,
    loadDataDebounceTimer,
    totalPages,
    phenotypes_options,
    fields,
    fields_details,
    filter,
    checked,
    // methods
    withCurrentReturnTo,
    updateBrowserUrl,
    copyLinkToClipboard,
    handleSortByOrDescChange,
    handleSortByUpdate,
    handlePerPageChange,
    handlePageChange,
    filtered,
    removeFilters,
    removeSearch,
    loadPhenotypesList,
    togglePhenotype,
    clearAllPhenotypes,
    setLogicMode,
    removePhenotype,
    loadEntitiesFromPhenotypes,
    doLoadEntitiesFromPhenotypes,
    applyApiResponse,
    requestSelected,
    requestSelectedExcel,
    requestExcel,
    truncate,
  };
}
