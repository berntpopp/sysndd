// src/components/analyses/usePublicationsTable.ts
//
// Request/state orchestration for PublicationsNDDTable.vue: filter init,
// browser-URL sync, the request coordinator (dedupe identical concurrent
// requests; drop a stale response once a newer request supersedes it),
// response application, cursor/page/sort/filter handlers, Excel export, and
// link-copy state. Extracted so the SFC stays a thin template shell (mirrors
// useLogTable.ts / usePhenotypeClusterTable.ts, #346). Formatting stays
// delegated to publicationsTableFormatters.ts.

import { nextTick, onMounted, ref, watch, type Ref } from 'vue';
import { useRoute } from 'vue-router';
import { useToast, useUrlParsing, useColorAndSymbols, useText, useTableData } from '@/composables';
import Utils from '@/assets/js/utils';
import { useUiStore } from '@/stores/ui';
import { normalizeSelectOptions } from '@/utils/selectOptions';
import {
  getPubMedUrl,
  formatDate,
  formatAuthors,
  parseKeywords,
  type PublicationTableField,
} from './publicationsTableFormatters';
import {
  listPublications,
  listPublicationsXlsx,
  type PublicationListResponse,
  type PublicationRecord,
} from '@/api/publication';
import { createTableRequestCoordinator } from '@/utils/tableRequestCoordinator';

// Module-level request coordinator (survives Vue Router remounts on URL change).
// Dedupes identical concurrent requests and (via isCurrent) drops a response
// once it is stale, so an older in-flight request can never overwrite state
// after a newer, different query has superseded it.
const publicationsRequestCoordinator = createTableRequestCoordinator<PublicationListResponse>();

export interface UsePublicationsTableProps {
  apiEndpoint?: string;
  showFilterControls?: boolean;
  showPaginationControls?: boolean;
  headerLabel?: string;
  sortInput?: string;
  filterInput?: string | null;
  fieldsInput?: string | null;
  pageAfterInput?: string;
  pageSizeInput?: number;
  fspecInput?: string;
}

export interface PublicationFilterEntry {
  content: string | null;
  join_char: string | null;
  operator: string;
}
export type PublicationFilter = Record<string, PublicationFilterEntry>;

/** Single source of truth for the empty publications-filter shape. */
function createEmptyPublicationFilter(): PublicationFilter {
  return {
    any: { content: null, join_char: null, operator: 'contains' },
    publication_id: { content: null, join_char: null, operator: 'contains' },
    Title: { content: null, join_char: null, operator: 'contains' },
    Journal: { content: null, join_char: null, operator: 'contains' },
    Publication_date: { content: null, join_char: null, operator: 'contains' },
  };
}

export function usePublicationsTable(props: UsePublicationsTableProps) {
  const { makeToast } = useToast();
  const { filterObjToStr, filterStrToObj, sortStringToVariables } = useUrlParsing();
  const colorAndSymbols = useColorAndSymbols();
  const text = useText();
  const route = useRoute();

  const tableData = useTableData({
    pageSizeInput: props.pageSizeInput,
    sortInput: props.sortInput,
    pageAfterInput: props.pageAfterInput,
  });

  const {
    totalRows,
    currentPage,
    currentItemID,
    executionTime,
    perPage,
    sortBy,
    sort,
    filter_string,
    downloading,
    loading,
    isBusy,
  } = tableData;
  // Publication cursor IDs are PMID strings (e.g. "PMID:12345678"), not
  // numbers — useTableData's generic prevItemID/nextItemID/lastItemID types
  // are narrower than that, so widen locally rather than coerce at runtime.
  const items = tableData.items as unknown as Ref<PublicationRecord[]>;
  const prevItemID = tableData.prevItemID as unknown as Ref<string | number>;
  const nextItemID = tableData.nextItemID as unknown as Ref<string | number>;
  const lastItemID = tableData.lastItemID as unknown as Ref<string | number>;

  // Component-specific filter
  const filter = ref<PublicationFilter>(createEmptyPublicationFilter());

  // ── Local state (was data()) ─────────────────────────────────────────────
  const isInitializing = ref(true); // guards watchers during initial load
  const loadDataDebounceTimer = ref<ReturnType<typeof setTimeout> | null>(null);
  const totalPages = ref(0); // cursor pagination info not in useTableData

  // Table columns
  const filterableCol = { sortable: true, class: 'text-start', filterable: true };
  const fields = ref<PublicationTableField[]>([
    { key: 'publication_id', label: 'PMID', sortDirection: 'asc', ...filterableCol },
    { key: 'Title', label: 'Title', ...filterableCol },
    { key: 'Publication_date', label: 'Date', ...filterableCol },
    { key: 'Journal', label: 'Journal', ...filterableCol },
    { key: 'details', label: 'Details', class: 'text-center' },
  ]);
  // Detail fields shown in expandable row view (static, never reassigned)
  const fields_details = [
    { key: 'Abstract', label: 'Abstract', class: 'text-start' },
    { key: 'Lastname', label: 'Authors (Last names)', class: 'text-start' },
    { key: 'Firstname', label: 'Authors (First names)', class: 'text-start' },
    { key: 'Keywords', label: 'Keywords', class: 'text-start' },
  ];

  // ── Methods ──────────────────────────────────────────────────────────────
  /** Syncs the browser URL to table state via history.replaceState (no Router remount). */
  function updateBrowserUrl(): void {
    // Don't update URL during initialization - preserves URL params from navigation
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

  /** Debounced wrapper for doLoadData to prevent duplicate calls. */
  function loadData(): void {
    if (loadDataDebounceTimer.value) {
      clearTimeout(loadDataDebounceTimer.value);
    }
    loadDataDebounceTimer.value = setTimeout(() => {
      loadDataDebounceTimer.value = null;
      void doLoadData();
    }, 50);
  }

  /** Fetches /api/publication via the coordinator (dedupe + stale-response guard). */
  async function doLoadData(): Promise<void> {
    const buildParams = () =>
      `sort=${sort.value}` +
      `&filter=${filter_string.value}` +
      `&page_after=${currentItemID.value}` +
      `&page_size=${perPage.value}`;
    const urlParam = buildParams();
    isBusy.value = true;

    const result = await publicationsRequestCoordinator.request({
      params: urlParam,
      fetcher: () =>
        listPublications({
          sort: sort.value,
          filter: filter_string.value,
          page_after: String(currentItemID.value),
          page_size: String(perPage.value),
          fields: props.fspecInput,
        }),
      apply: (data, source) => {
        applyApiResponse(data);
        if (source === 'network') {
          // Update URL AFTER API success to prevent component remount mid-call
          updateBrowserUrl();
        }
      },
      onError: (error) => makeToast(error, 'Error', 'danger'),
      isCurrent: (params) => buildParams() === params,
    });

    if (result.handled) {
      isBusy.value = false;
    }
  }

  /** Applies API response data to state; reused by every coordinator apply() path. */
  function applyApiResponse(data: PublicationListResponse): void {
    items.value = data.data;

    const metaArr = data.meta as Array<Record<string, unknown>> | undefined;
    if (metaArr && metaArr.length > 0) {
      const metaObj = metaArr[0];
      totalRows.value = (metaObj.totalItems as number) || 0;

      // Fix for b-pagination
      void nextTick(() => {
        currentPage.value = metaObj.currentPage as number;
      });
      totalPages.value = metaObj.totalPages as number;
      // Publication IDs are strings like "PMID:12345", not numbers. Store as-is
      // for cursor pagination, only convert to 0 if null/undefined.
      const cursorOrZero = (v: unknown): string | number =>
        v === 'null' ? 0 : (v as string | number) || 0;
      prevItemID.value = cursorOrZero(metaObj.prevItemID);
      currentItemID.value = cursorOrZero(metaObj.currentItemID);
      nextItemID.value = cursorOrZero(metaObj.nextItemID);
      lastItemID.value = cursorOrZero(metaObj.lastItemID);
      executionTime.value = metaObj.executionTime as number;

      // Use API fspec directly but filter to visible columns
      const fspec = metaObj.fspec;
      if (fspec && Array.isArray(fspec)) {
        const visibleKeys = ['publication_id', 'Title', 'Publication_date', 'Journal'];
        const shortLabels: Record<string, string> = {
          publication_id: 'PMID',
          Publication_date: 'Date',
        };
        const filteredFields = (fspec as PublicationTableField[])
          .filter((f) => visibleKeys.includes(f.key))
          .map((f) => ({ ...f, label: shortLabels[f.key] || f.label, class: 'text-start' }));
        // Add details column
        filteredFields.push({ key: 'details', label: 'Details', class: 'text-center', sortable: false });
        fields.value = filteredFields;
      }
    }
    const uiStore = useUiStore();
    uiStore.requestScrollbarUpdate();
  }

  /** Moves to the next/previous "page" in cursor pagination. */
  function handlePageChange(value: number): void {
    if (value === 1) {
      currentItemID.value = 0;
    } else if (value === totalPages.value) {
      currentItemID.value = lastItemID.value;
    } else if (value > currentPage.value) {
      currentItemID.value = nextItemID.value;
    } else if (value < currentPage.value) {
      currentItemID.value = prevItemID.value;
    }
    filtered();
  }

  /** Called by the child TablePaginationControls when user picks a new page size. */
  function handlePerPageChange(newSize: number | string): void {
    perPage.value = parseInt(String(newSize), 10) || 10;
    currentItemID.value = 0;
    filtered();
  }

  /** Rebuilds filter_string from filter object, calls loadData. */
  function filtered(): void {
    const filterStringLoc = filterObjToStr(filter.value);
    if (filterStringLoc !== filter_string.value) {
      filter_string.value = filterStringLoc;
    }
    loadData();
  }

  /** Clears the filter object, resets to page=1, reloads data. */
  function removeFilters(): void {
    filter.value = createEmptyPublicationFilter();
    currentItemID.value = 0;
    filtered();
  }

  /** Clears the "any" filter so column-specific filters remain. */
  function removeSearch(): void {
    filter.value.any.content = null;
  }

  /** GenericTable header-click event; converts legacy shape to array sortBy format. */
  function handleSortUpdate(ctx: { sortBy: string; sortDesc: boolean }): void {
    sortBy.value = [{ key: ctx.sortBy, order: ctx.sortDesc ? 'desc' : 'asc' }];
  }

  /** Rebuilds the sort param string (+ or -). */
  function handleSortByOrDescChange(): void {
    currentItemID.value = 0;
    const sortColumn =
      sortBy.value.length > 0 && sortBy.value[0].key ? sortBy.value[0].key : 'publication_id';
    const sortOrder = sortBy.value.length > 0 && sortBy.value[0].order ? sortBy.value[0].order : 'asc';
    const isDesc = sortOrder === 'desc';
    sort.value = (isDesc ? '-' : '+') + sortColumn;
    filtered();
  }

  /** Makes a call to the same endpoint with format=xlsx to fetch an Excel file. */
  async function requestExcel(): Promise<void> {
    downloading.value = true;

    try {
      const blob = await listPublicationsXlsx({
        sort: sort.value,
        filter: filter_string.value,
        page_after: '0',
        page_size: 'all',
        fields: props.fspecInput,
      });

      const fileURL = window.URL.createObjectURL(blob);
      const fileLink = document.createElement('a');
      fileLink.href = fileURL;
      fileLink.setAttribute('download', 'publications.xlsx');
      document.body.appendChild(fileLink);
      fileLink.click();
    } catch (error) {
      makeToast(error, 'Error downloading Excel', 'danger');
    }
    downloading.value = false;
  }

  /** Copies the current table state (sort, filter, pagination) to the clipboard as a URL. */
  function copyLinkToClipboard(): void {
    const urlParam =
      `sort=${sort.value}` +
      `&filter=${filter_string.value}` +
      `&page_after=${currentItemID.value}` +
      `&page_size=${perPage.value}`;
    const fullUrl = `${import.meta.env.VITE_URL + route.path}?${urlParam}`;
    navigator.clipboard.writeText(fullUrl);
    makeToast('Link copied to clipboard', 'Info', 'info');
  }

  /** Shortens text to n chars + ellipsis, from utils.js. */
  function truncate(str: string, n: number): string {
    return Utils.truncate(str, n);
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
  watch(
    sortBy,
    (newVal) => {
      if (isInitializing.value) return;
      // Build new sort string from sortBy. Must validate that we have a valid
      // sort column before triggering an API call.
      const sortColumn = newVal.length > 0 && newVal[0].key ? newVal[0].key : null;
      if (!sortColumn) return;
      const sortOrder = newVal.length > 0 && newVal[0].order ? newVal[0].order : 'asc';
      const newSortString = (sortOrder === 'desc' ? '-' : '+') + sortColumn;
      // Only trigger if sort actually changed
      if (newSortString !== sort.value) {
        handleSortByOrDescChange();
      }
    },
    { deep: true }
  );
  // NOTE: We intentionally do not watch(perPage) / watch(sortDesc) to avoid
  // double-calling; handlePerPageChange(newSize) and the sortBy watcher above
  // are the sole triggers.

  // ── Lifecycle (was mounted) ──────────────────────────────────────────────
  onMounted(() => {
    // Transform input sort string to Bootstrap-Vue-Next array format.
    if (props.sortInput) {
      const sortObject = sortStringToVariables(props.sortInput);
      sortBy.value = sortObject.sortBy;
      sort.value = props.sortInput; // Also set the sort string for API calls
    }

    // Initialize pagination from URL if provided
    if (props.pageAfterInput && props.pageAfterInput !== '0') {
      currentItemID.value = parseInt(props.pageAfterInput, 10) || 0;
    }

    // Transform input filter string to object and load data.
    // Use nextTick to ensure Vue reactivity is fully initialized.
    void nextTick(() => {
      if (props.filterInput && props.filterInput !== 'null' && props.filterInput !== '') {
        // Parse URL filter string into filter object for proper UI state
        filter.value = filterStrToObj(props.filterInput, filter.value) as PublicationFilter;
        // Also set filter_string so the API call uses the URL filter
        filter_string.value = props.filterInput;
      }
      // Load data first while still in initializing state
      loadData();
      // Delay marking initialization complete to ensure watchers triggered
      // by filter/sortBy changes above see isInitializing=true
      void nextTick(() => {
        isInitializing.value = false;
      });
    });

    setTimeout(() => {
      loading.value = false;
    }, 500);
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
    // typed overrides of the tableData spread above (string-capable cursors)
    items,
    prevItemID,
    nextItemID,
    lastItemID,
    // methods
    updateBrowserUrl,
    loadData,
    doLoadData,
    applyApiResponse,
    handlePageChange,
    handlePerPageChange,
    filtered,
    removeFilters,
    removeSearch,
    handleSortUpdate,
    handleSortByOrDescChange,
    requestExcel,
    copyLinkToClipboard,
    truncate,
    getPubMedUrl,
    formatDate,
    normalizeSelectOptions,
    formatAuthors,
    parseKeywords,
  };
}
