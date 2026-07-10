// components/tables/useEntitiesTable.ts
//
// State, data loading, cursor pagination, URL sync, and the per-row
// disease-mapping lazy fetch for the entities table. Extracted from
// TablesEntities.vue so the SFC stays a thin template shell (mirrors
// useLogTable.ts / usePublicationsTable.ts, issue #346). Static column/
// filter/detail configuration lives in entityTableConfig.ts.

import { nextTick, onMounted, reactive, ref, watch } from 'vue';
import { useToast, useUrlParsing, useColorAndSymbols, useText, useTableData, useColumnTooltip } from '@/composables';
import { useUiStore } from '@/stores/ui';
import { withReturnTo } from '@/utils/returnNavigation';
import { listEntities, listEntitiesXlsx, type EntityListResponse } from '@/api/entity';
import { getEntityMappings } from '@/api/disease-mappings';
import { createTableRequestCoordinator } from '@/utils/tableRequestCoordinator';
import {
  ENTITY_TABLE_FIELDS,
  ENTITY_TABLE_FIELD_DETAILS,
  ENTITY_SHORT_LABELS,
  createEmptyEntityFilter,
  normalizeEntitySelectOptions,
  type EntityFilter,
  type EntityTableField,
} from './entityTableConfig';

// Module-level request coordinator: survives Vue Router remounts on URL
// change (a remounted instance dedupes against/rejects a stale response from
// a prior instance's in-flight request — see GeneView.spec.ts) and dedupes
// identical concurrent requests within a single instance.
const entitiesRequestCoordinator = createTableRequestCoordinator<EntityListResponse>();

export interface UseEntitiesTableProps {
  apiEndpoint?: string;
  showFilterControls?: boolean;
  showSearchInput?: boolean;
  showPaginationControls?: boolean;
  headerLabel?: string;
  sortInput?: string;
  filterInput?: string | null;
  fieldsInput?: string | null;
  pageAfterInput?: string;
  pageSizeInput?: number;
  fspecInput?: string;
  disableUrlSync?: boolean;
  headingLevel?: number;
}

interface EntityMappingState {
  data: unknown;
  loading: boolean;
  error: Error | null;
}

export function useEntitiesTable(props: UseEntitiesTableProps) {
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
    sortBy,
    sort,
    filter_string,
    downloading,
    loading,
    isBusy,
  } = tableData;

  // Component-specific filter
  const filter = ref<EntityFilter>(createEmptyEntityFilter());

  // ── Local state (was data()) ─────────────────────────────────────────────
  const isInitializing = ref(true);
  const loadDataDebounceTimer = ref<ReturnType<typeof setTimeout> | null>(null);
  const totalPages = ref(0);
  const fields = ref<EntityTableField[]>([...ENTITY_TABLE_FIELDS]);
  const fields_details: EntityTableField[] = ENTITY_TABLE_FIELD_DETAILS;

  // Per-row disease-mapping lazy fetch state.
  const entityMappingsMap = reactive<Record<string, EntityMappingState>>({});

  /** Lazily fetches ontology mappings for an entity and stores the result in entityMappingsMap. */
  async function fetchEntityMappings(entityId: number | string): Promise<void> {
    const key = String(entityId);
    if (!entityMappingsMap[key]) {
      entityMappingsMap[key] = { data: null, loading: false, error: null };
    }
    if (entityMappingsMap[key].data !== null || entityMappingsMap[key].loading) {
      return; // already fetched or in flight
    }
    entityMappingsMap[key].loading = true;
    try {
      entityMappingsMap[key].data = await getEntityMappings(key);
    } catch (e) {
      entityMappingsMap[key].error = e instanceof Error ? e : new Error(String(e));
    } finally {
      entityMappingsMap[key].loading = false;
    }
  }

  /** Returns the current mapping state for an entity id, or a safe default. */
  function getEntityMappingState(entityId: number | string): EntityMappingState {
    return entityMappingsMap[String(entityId)] ?? { data: null, loading: false, error: null };
  }

  // Prune entityMappingsMap when the page changes so map entries don't grow
  // unboundedly. Mirrors the expandedRows pruning in EntitiesMobileRows.vue.
  watch(
    items,
    (currentItems) => {
      const currentKeys = new Set(
        (currentItems as Array<Record<string, unknown>>)
          .map((item) => String(item.entity_id ?? ''))
          .filter(Boolean)
      );
      for (const key of Object.keys(entityMappingsMap)) {
        if (!currentKeys.has(key)) {
          delete entityMappingsMap[key];
        }
      }
    },
    { deep: false }
  );

  // ── Methods ────────────────────────────────────────────────────────────────
  function withCurrentReturnTo(path: string): string {
    return withReturnTo(path);
  }

  /** Syncs the browser URL to table state via history.replaceState (no Router remount). */
  function updateBrowserUrl(): void {
    // Don't update URL during initialization - preserves URL params from navigation
    if (isInitializing.value) return;
    // When embedded (e.g. GeneView), skip URL updates to keep URL clean
    if (props.disableUrlSync) return;

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

  /** Rebuilds filter_string from the filter object and reloads (URL is updated AFTER success). */
  function filtered(): void {
    const filterStringLoc = filterObjToStr(filter.value);
    if (filterStringLoc !== filter_string.value) {
      filter_string.value = filterStringLoc;
    }
    loadData();
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

  function handlePerPageChange(newPerPage: number | string): void {
    perPage.value = parseInt(String(newPerPage), 10);
    currentItemID.value = 0;
    filtered();
  }

  function handleSortByOrDescChange(): void {
    currentItemID.value = 0;
    const sortColumn = sortBy.value.length > 0 ? sortBy.value[0].key : 'entity_id';
    const sortOrder = sortBy.value.length > 0 ? sortBy.value[0].order : 'asc';
    const isDesc = sortOrder === 'desc';
    sort.value = (isDesc ? '-' : '+') + sortColumn;
    filtered();
  }

  function handleSortUpdate({ sortBy: key, sortDesc }: { sortBy: string; sortDesc: boolean }): void {
    sortBy.value = [{ key, order: sortDesc ? 'desc' : 'asc' }];
  }

  /** Mutates existing filter entries' content in place (no currentItemID reset — matches original). */
  function removeFilters(): void {
    Object.keys(filter.value).forEach((key) => {
      const entry = filter.value[key];
      if (entry && typeof entry === 'object' && 'content' in entry) {
        entry.content = null;
      }
    });
    filtered();
  }

  function removeSearch(): void {
    if (filter.value.any) {
      filter.value.any.content = null;
    }
    filtered();
  }

  /** Debounced wrapper for doLoadData to prevent duplicate calls from multiple triggers. */
  function loadData(): void {
    if (loadDataDebounceTimer.value) {
      clearTimeout(loadDataDebounceTimer.value);
    }
    loadDataDebounceTimer.value = setTimeout(() => {
      loadDataDebounceTimer.value = null;
      void doLoadData();
    }, 50);
  }

  // v11.3 §4.2.3 option (B): initial-load path that bypasses the debounce so
  // the mount-time fetch starts immediately (within the spec's <=100 ms
  // after-nav budget). Used only by the onMounted hook below; reactivity
  // triggers continue to use loadData() with its 50 ms debounce.
  function loadDataImmediate(): void {
    if (loadDataDebounceTimer.value) {
      clearTimeout(loadDataDebounceTimer.value);
      loadDataDebounceTimer.value = null;
    }
    void doLoadData();
  }

  /** Fetches /api/entity via the coordinator (dedupe + stale-response guard). */
  async function doLoadData(): Promise<void> {
    // `compact` changes the server response shape (count == count_filtered,
    // no global fspec) so it MUST be part of the dedup key — otherwise a
    // remounted instance with different controls visibility would receive a
    // stale response with the wrong fspec semantics.
    const buildParams = () =>
      `sort=${sort.value}&filter=${filter_string.value}&page_after=${currentItemID.value}` +
      `&page_size=${perPage.value}&compact=${!props.showFilterControls}`;
    const urlParam = buildParams();
    isBusy.value = true;

    const result = await entitiesRequestCoordinator.request({
      params: urlParam,
      fetcher: () =>
        listEntities({
          sort: sort.value,
          filter: filter_string.value,
          page_after: currentItemID.value,
          page_size: String(perPage.value),
          // Embedded callers (GeneView/EntityView) hide the filter dropdowns,
          // so they don't need the global-fspec round-trip. Compact mode
          // pushes the filter to SQL and skips the wasted fspec compute.
          compact: !props.showFilterControls,
        }),
      apply: (data, source) => {
        applyApiResponse(data);
        if (source === 'network') {
          // Update URL AFTER API success to prevent component remount during API call
          updateBrowserUrl();
        }
      },
      onError: (e) => {
        makeToast(e, 'Error', 'danger');
      },
      isCurrent: (params) => buildParams() === params,
    });

    if (result.handled) {
      isBusy.value = false;
      loading.value = false;
    }
  }

  /** Applies API response data to state; reused by every coordinator apply() path. */
  function applyApiResponse(data: EntityListResponse): void {
    items.value = data.data;
    const metaArr = data.meta as Array<Record<string, unknown>>;
    const meta = metaArr[0];
    totalRows.value = (meta.totalItems as number) || 0;
    // this solves an update issue in b-pagination component
    // based on https://github.com/bootstrap-vue/bootstrap-vue/issues/3541
    void nextTick(() => {
      currentPage.value = meta.currentPage as number;
    });
    totalPages.value = meta.totalPages as number;
    prevItemID.value = Number(meta.prevItemID) || 0;
    currentItemID.value = Number(meta.currentItemID) || 0;
    nextItemID.value = Number(meta.nextItemID) || 0;
    lastItemID.value = Number(meta.lastItemID) || 0;
    executionTime.value = meta.executionTime as number;

    // Apply short label overrides for mobile-friendly stacked table headers
    const fspec = meta.fspec;
    if (Array.isArray(fspec)) {
      fields.value = (fspec as EntityTableField[]).map((field) =>
        ENTITY_SHORT_LABELS[field.key]
          ? { ...field, label: ENTITY_SHORT_LABELS[field.key] }
          : field
      );
    }

    const uiStore = useUiStore();
    uiStore.requestScrollbarUpdate();
  }

  /** Normalize select options for BFormSelect. */
  function normalizeSelectOptions(options: unknown): Array<{ value: unknown; text: unknown }> {
    return normalizeEntitySelectOptions(options);
  }

  /**
   * Truncates a string to n chars + ellipsis. Kept distinct from
   * `Utils.truncate` (which reserves 3 chars for the ellipsis instead of 1) —
   * this mirrors the previous `useTableMethods().truncate` this table used.
   */
  function truncate(str: string, n: number): string {
    return str.length > n ? `${str.substring(0, n - 1)}...` : str;
  }

  /** Makes a call to /api/entity with format=xlsx to fetch an Excel file. */
  async function requestExcel(): Promise<void> {
    downloading.value = true;
    try {
      const blob = await listEntitiesXlsx({
        sort: sort.value,
        filter: filter_string.value,
        page_after: 0,
        page_size: 'all',
      });

      const fileURL = window.URL.createObjectURL(new Blob([blob]));
      const fileLink = document.createElement('a');
      fileLink.setAttribute('download', `sysndd_${props.apiEndpoint || 'entity'}_table.xlsx`);
      fileLink.href = fileURL;
      document.body.appendChild(fileLink);
      fileLink.click();
      document.body.removeChild(fileLink);
      window.URL.revokeObjectURL(fileURL);
    } catch (e) {
      makeToast(e as Error, 'Error', 'danger');
    } finally {
      downloading.value = false;
    }
  }

  /** Copies the current table state (sort, filter, pagination) to the clipboard as a URL. */
  function copyLinkToClipboard(): void {
    const urlParam = `sort=${sort.value}&filter=${filter_string.value}&page_after=${currentItemID.value}&page_size=${perPage.value}`;
    navigator.clipboard.writeText(
      `${import.meta.env.VITE_URL + window.location.pathname}?${urlParam}`
    );
  }

  // ── Watchers ───────────────────────────────────────────────────────────────
  // Watch for filter changes (deep required for Vue 3 behavior).
  // Skip during initialization to prevent multiple API calls.
  watch(
    filter,
    () => {
      if (isInitializing.value) return;
      filtered();
    },
    { deep: true }
  );
  // Watch for sortBy changes (deep watch for array).
  // Skip during initialization to prevent multiple API calls.
  // Only trigger if sort actually changed to prevent resetting currentItemID during pagination.
  watch(
    sortBy,
    (newVal) => {
      if (isInitializing.value) return;
      const newSortColumn = newVal && newVal.length > 0 ? newVal[0].key : 'entity_id';
      const newSortOrder = newVal && newVal.length > 0 ? newVal[0].order : 'asc';
      const newSortString = (newSortOrder === 'desc' ? '-' : '+') + newSortColumn;
      // Only trigger if sort actually changed - prevents resetting currentItemID during pagination
      if (newSortString !== sort.value) {
        handleSortByOrDescChange();
      }
    },
    { deep: true }
  );

  // ── Lifecycle (was mounted) ──────────────────────────────────────────────
  onMounted(() => {
    // Transform input sort string to Bootstrap-Vue-Next array format.
    if (props.sortInput) {
      const sortObject = sortStringToVariables(props.sortInput);
      sortBy.value = sortObject.sortBy;
      sort.value = props.sortInput; // Also set the sort string for API calls
    }

    // Initialize pagination from URL if provided.
    if (props.pageAfterInput && props.pageAfterInput !== '0') {
      currentItemID.value = parseInt(props.pageAfterInput, 10) || 0;
    }

    // Transform input filter string to object and load data.
    // Use nextTick to ensure Vue reactivity is fully initialized.
    void nextTick(() => {
      if (props.filterInput && props.filterInput !== 'null' && props.filterInput !== '') {
        // Parse URL filter string into filter object for proper UI state
        filter.value = filterStrToObj(props.filterInput, filter.value) as EntityFilter;
        // Also set filter_string so the API call uses the URL filter
        filter_string.value = props.filterInput;
      }
      // Skip the 50 ms initial-load debounce so the entity request starts
      // within the spec's <=100 ms after-nav budget. The debounce remains
      // for subsequent filter/sort/pagination calls.
      loadDataImmediate();
      // Delay marking initialization complete to ensure watchers triggered
      // by filter/sortBy changes above see isInitializing=true
      void nextTick(() => {
        isInitializing.value = false;
      });
    });
    // Note: `loading` flips to false inside doLoadData() once the API responds.
  });

  return {
    // composable passthroughs (spread for template/vm access parity)
    ...colorAndSymbols,
    ...text,
    ...tableData,
    filterObjToStr,
    filterStrToObj,
    sortStringToVariables,
    // local state
    filter,
    isInitializing,
    loadDataDebounceTimer,
    totalPages,
    fields,
    fields_details,
    entityMappingsMap,
    // computed/helpers
    getTooltipText,
    normalizeSelectOptions,
    truncate,
    withCurrentReturnTo,
    // methods
    fetchEntityMappings,
    getEntityMappingState,
    updateBrowserUrl,
    filtered,
    handlePageChange,
    handlePerPageChange,
    handleSortByOrDescChange,
    handleSortUpdate,
    removeFilters,
    removeSearch,
    loadData,
    loadDataImmediate,
    doLoadData,
    applyApiResponse,
    requestExcel,
    copyLinkToClipboard,
  };
}

export default useEntitiesTable;
