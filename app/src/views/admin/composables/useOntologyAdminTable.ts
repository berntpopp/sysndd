// views/admin/composables/useOntologyAdminTable.ts
//
// State, data loading, cursor pagination, URL sync, filtering, edit-modal
// orchestration and client-side Excel export for the Admin "Manage Ontology"
// (VariO variant-ontology) table. Extracted from ManageOntology.vue (#346
// Wave 2) so the SFC stays a thin shell; the static column/filter/select
// config lives in ontologyTableConfig.ts.
//
// This is an admin curation-metadata surface (see AGENTS.md "Admin curation
// metadata vocabularies"): editability, the update payload shape
// (`{ ontology_details: {...} }`), and the ontology outlink behaviour are
// unchanged by this extraction — only the responsibility's *location*
// moved. Every network call goes through the typed `@/api/ontology` client.

import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch, type Ref } from 'vue';
import useToast from '@/composables/useToast';
import useUrlParsing from '@/composables/useUrlParsing';
import useTableData from '@/composables/useTableData';
import { useExcelExport } from '@/composables/useExcelExport';
import { useUiStore } from '@/stores/ui';
import {
  listVariantOntology,
  updateVariantOntology,
  type VariantOntologyRow,
  type VariantOntologyListResponse,
  type UpdateVariantOntologyRequest,
} from '@/api/ontology';
import { createTableRequestCoordinator } from '@/utils/tableRequestCoordinator';
import {
  ONTOLOGY_TABLE_FIELDS,
  ONTOLOGY_ACTIVE_FILTER_OPTIONS,
  ONTOLOGY_OBSOLETE_FILTER_OPTIONS,
  ONTOLOGY_MOBILE_SORT_OPTIONS,
  ONTOLOGY_EXPORT_HEADERS,
  createEmptyOntologyFilter,
  type OntologyTableField,
  type OntologyFilter,
} from '../ontologyTableConfig';

// Module-level request coordinator (survives Vue Router remounts on URL
// change). Dedupes identical concurrent requests, serves a short recent
// cache, and (via isCurrent) drops stale responses — see
// useGenesTable.ts/useEntitiesTable.ts for the same pattern.
const ontologyRequestCoordinator = createTableRequestCoordinator<VariantOntologyListResponse>();

/** Shape of one `meta[0]` row returned by `GET /api/ontology/variant/table`. */
interface OntologyListMeta {
  totalItems: number;
  currentPage: number;
  totalPages: number;
  prevItemID: number | string;
  currentItemID: number | string;
  nextItemID: number | string;
  lastItemID: number | string;
  executionTime: number;
}

export interface OntologyActiveFilterEntry {
  key: string;
  label: string;
  value: string;
}

export function useOntologyAdminTable() {
  const requestConsumer = {};
  const { makeToast } = useToast();
  const { filterObjToStr, filterStrToObj, sortStringToVariables } = useUrlParsing();
  const { isExporting, exportToExcel } = useExcelExport();

  const tableData = useTableData({
    pageSizeInput: 25,
    sortInput: '+vario_id',
    pageAfterInput: '0',
  });

  // Only the state actually read/written by this composable's functions is
  // destructured here; everything else (pageOptions, downloading, loading,
  // sortDesc, sortColumn, removeFiltersButtonVariant/Title, filterOn) is
  // still exposed to the template/spec via the `...tableData` spread below.
  const {
    currentPage,
    currentItemID,
    executionTime,
    perPage,
    sortBy,
    sort,
    filter_string,
    isBusy,
    totalRows,
  } = tableData;
  // VariO cursor IDs are strings (e.g. "VariO:0026"), not numbers —
  // useTableData's generic prevItemID/nextItemID/lastItemID types are narrower
  // (`number | null`), so widen locally rather than coerce with Number()
  // (which would map every VariO cursor to NaN → 0 and pin the table to page 1,
  // #531). Mirrors usePublicationsTable's PMID-cursor handling.
  const prevItemID = tableData.prevItemID as unknown as Ref<string | number>;
  const nextItemID = tableData.nextItemID as unknown as Ref<string | number>;
  const lastItemID = tableData.lastItemID as unknown as Ref<string | number>;

  // Component-specific filter shape.
  const filter = ref<OntologyFilter>(createEmptyOntologyFilter());

  // ── Local state (was data()) ─────────────────────────────────────────────
  const isInitializing = ref(true);
  const loadDataDebounceTimer = ref<ReturnType<typeof setTimeout> | null>(null);
  let tableIntentGeneration = 0;
  let disposed = false;
  const totalPages = ref(0);
  const ontologies = ref<VariantOntologyRow[]>([]);
  const fields = ref<OntologyTableField[]>([...ONTOLOGY_TABLE_FIELDS]);
  const mobileSortOptions = ONTOLOGY_MOBILE_SORT_OPTIONS;
  const activeFilterOptions = ONTOLOGY_ACTIVE_FILTER_OPTIONS;
  const obsoleteFilterOptions = ONTOLOGY_OBSOLETE_FILTER_OPTIONS;

  // Modal visibility state - Bootstrap-Vue-Next uses v-model pattern.
  const showEditModal = ref(false);
  const ontologyToEdit = ref<Partial<VariantOntologyRow>>({});

  // ── Computed ───────────────────────────────────────────────────────────
  const mobileSortValue = computed<string>({
    get() {
      return sort.value || '+vario_id';
    },
    set(value: string) {
      const sort_object = sortStringToVariables(value);
      sortBy.value = sort_object.sortBy;
      sort.value = value;
      currentItemID.value = 0;
      filtered();
    },
  });

  const hasActiveFilters = computed<boolean>(() =>
    Object.values(filter.value).some((f) => f.content !== null && f.content !== '')
  );

  const activeFilters = computed<OntologyActiveFilterEntry[]>(() => {
    const filters: OntologyActiveFilterEntry[] = [];
    if (filter.value.any.content) {
      filters.push({ key: 'any', label: 'Search', value: String(filter.value.any.content) });
    }
    if (filter.value.is_active.content !== null) {
      filters.push({
        key: 'is_active',
        label: 'Status',
        value: filter.value.is_active.content === '1' ? 'Active' : 'Inactive',
      });
    }
    if (filter.value.obsolete.content !== null) {
      filters.push({
        key: 'obsolete',
        label: 'Terms',
        value: filter.value.obsolete.content === '1' ? 'Obsolete' : 'Current',
      });
    }
    return filters;
  });

  // ── Methods ────────────────────────────────────────────────────────────

  // Update browser URL with current table state. Uses history.replaceState
  // instead of router.replace to prevent component remount.
  function updateBrowserUrl(): void {
    // Don't update URL during initialization - preserves URL params from navigation.
    if (isInitializing.value) return;

    const searchParams = new URLSearchParams();

    if (sort.value) {
      searchParams.set('sort', sort.value);
    }
    if (filter_string.value) {
      searchParams.set('filter', filter_string.value);
    }
    // Emit page_after for any meaningful cursor — string VariO IDs included
    // (Number(cursor) > 0 would drop them, leaving the URL un-bookmarkable and
    // failing to reflect the current page, #531). 0 / "0" / null are the
    // page-1 sentinel and are omitted.
    const cursor = currentItemID.value;
    if (cursor != null && cursor !== 0 && cursor !== '0' && cursor !== '') {
      searchParams.set('page_after', String(cursor));
    }
    searchParams.set('page_size', String(perPage.value));

    const newUrl = `${window.location.pathname}?${searchParams.toString()}`;
    window.history.replaceState({ ...window.history.state }, '', newUrl);
  }

  // Filter method that triggers data load.
  function filtered(): void {
    const filter_string_loc = filterObjToStr(filter.value);
    if (filter_string_loc !== filter_string.value) {
      filter_string.value = filter_string_loc;
    }
    currentItemID.value = 0; // Reset to first page on filter change
    loadData();
  }

  // Handle page change events.
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
    // Load directly with the cursor computed above — do NOT route through
    // filtered(), whose unconditional `currentItemID = 0` reset (kept for real
    // filter/sort/per-page changes) would clobber the cursor back to 0 and pin
    // every next/prev/last request to page_after=0, i.e. always page 1 (#531).
    // The filter is unchanged on a page change, so filter_string is already in
    // sync and needs no recompute.
    loadData();
  }

  // Handle per-page change events.
  function handlePerPageChange(newPerPage: number | string): void {
    perPage.value = parseInt(String(newPerPage), 10);
    currentItemID.value = 0;
    filtered();
  }

  // Handle sort changes.
  function handleSortByOrDescChange(): void {
    currentItemID.value = 0;
    const sortColumnKey = sortBy.value.length > 0 ? sortBy.value[0].key : '';
    const sortOrder = sortBy.value.length > 0 ? sortBy.value[0].order : 'asc';
    const isDesc = sortOrder === 'desc';
    sort.value = (isDesc ? '-' : '+') + sortColumnKey;
    filtered();
  }

  // Remove all filters.
  function removeFilters(): void {
    Object.keys(filter.value).forEach((key) => {
      const entry = filter.value[key];
      if (entry && typeof entry === 'object' && 'content' in entry) {
        entry.content = null;
      }
    });
    filtered();
  }

  // Clear a specific filter.
  function clearFilter(key: string): void {
    if (filter.value[key]) {
      filter.value[key].content = null;
    }
    filtered();
  }

  // Handle sort updates from GenericTable.
  function handleSortUpdate(newSortBy: Array<{ key: string; order: 'asc' | 'desc' }>): void {
    sortBy.value = newSortBy;
    handleSortByOrDescChange();
  }

  // Load data with debouncing.
  function loadData(): void {
    if (disposed) return;
    const intentGeneration = ++tableIntentGeneration;
    if (loadDataDebounceTimer.value) {
      clearTimeout(loadDataDebounceTimer.value);
    }
    loadDataDebounceTimer.value = setTimeout(() => {
      loadDataDebounceTimer.value = null;
      void doLoadData(intentGeneration);
    }, 50);
  }

  // Actual data loading method with module-level request coordination.
  async function doLoadData(intentGeneration = ++tableIntentGeneration): Promise<void> {
    const buildParams = () =>
      `sort=${sort.value}&filter=${filter_string.value}&page_after=${currentItemID.value}&page_size=${perPage.value}`;
    const urlParam = buildParams();
    const isIntentCurrent = () => !disposed && tableIntentGeneration === intentGeneration;
    if (!isIntentCurrent()) return;
    isBusy.value = true;

    const result = await ontologyRequestCoordinator.request({
      consumer: requestConsumer,
      params: urlParam,
      fetcher: () =>
        listVariantOntology({
          sort: sort.value,
          filter: filter_string.value,
          page_after: currentItemID.value,
          page_size: perPage.value,
      }),
      apply: (data, source) => {
        applyApiResponse(data, isIntentCurrent);
        if (source === 'network') {
          updateBrowserUrl();
        }
      },
      onError: (e) => makeToast(e, 'Error', 'danger'),
      isCurrent: (params) => isIntentCurrent() && buildParams() === params,
    });

    if (result.handled) {
      isBusy.value = false;
    }
  }

  /**
   * Apply API response data to component state. Extracted to allow reuse
   * when skipping duplicate API calls (see doLoadData's `apply` callback).
   */
  function applyApiResponse(
    data: VariantOntologyListResponse,
    isIntentCurrent: () => boolean = () => true
  ): void {
    const meta = (data.meta as OntologyListMeta[])[0];

    ontologies.value = data.data;
    totalRows.value = meta.totalItems;
    void nextTick(() => {
      if (isIntentCurrent()) {
        currentPage.value = meta.currentPage;
      }
    });
    totalPages.value = meta.totalPages;
    // VariO cursor IDs are strings like "VariO:0026" — store them as-is so the
    // cursor survives to the next page request. Only null/undefined/"null"
    // collapse to the page-1 sentinel 0 (Number() would map every string to
    // 0, #531). Mirrors usePublicationsTable's cursorOrZero.
    const cursorOrZero = (v: unknown): string | number =>
      v === 'null' ? 0 : (v as string | number) || 0;
    prevItemID.value = cursorOrZero(meta.prevItemID);
    currentItemID.value = cursorOrZero(meta.currentItemID);
    nextItemID.value = cursorOrZero(meta.nextItemID);
    lastItemID.value = cursorOrZero(meta.lastItemID);
    executionTime.value = meta.executionTime;

    const uiStore = useUiStore();
    uiStore.requestScrollbarUpdate();
  }

  /** Handle client-side Excel export of the currently loaded page. */
  function handleExport(): void {
    void exportToExcel(ontologies.value, {
      filename: `ontology_export_${new Date().toISOString().split('T')[0]}`,
      sheetName: 'Ontology',
      headers: ONTOLOGY_EXPORT_HEADERS,
    });
  }

  /** Opens the edit modal with the selected ontology data (deep copy to prevent direct mutation). */
  function editOntology(item: VariantOntologyRow): void {
    ontologyToEdit.value = JSON.parse(JSON.stringify(item)) as VariantOntologyRow;
    showEditModal.value = true;
  }

  /** Updates the ontology data via the API. */
  async function updateOntologyData(): Promise<void> {
    try {
      const data = await updateVariantOntology({
        ontology_details:
          ontologyToEdit.value as unknown as UpdateVariantOntologyRequest['ontology_details'],
      });
      makeToast(data.message, 'Success', 'success');
      // Update the ontology in the local state.
      const index = ontologies.value.findIndex((o) => o.vario_id === ontologyToEdit.value.vario_id);
      if (index !== -1) {
        ontologies.value.splice(index, 1, { ...ontologyToEdit.value } as VariantOntologyRow);
      }
      // Close the modal after successful update.
      showEditModal.value = false;
      // Reset the ontologyToEdit object.
      ontologyToEdit.value = {};
    } catch (e) {
      const err = e as { response?: { data?: { error?: string } }; message?: string };
      makeToast(err.response?.data?.error || err.message, 'Error', 'danger');
    }
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
    // Initialize from URL parameters.
    const urlParams = new URLSearchParams(window.location.search);
    if (urlParams.get('sort')) {
      const sort_object = sortStringToVariables(urlParams.get('sort') as string);
      sortBy.value = sort_object.sortBy;
      sort.value = urlParams.get('sort') as string;
    }
    if (urlParams.get('filter')) {
      filter.value = filterStrToObj(urlParams.get('filter'), filter.value) as OntologyFilter;
      filter_string.value = urlParams.get('filter') as string;
    }
    if (urlParams.get('page_after')) {
      // Keep the raw cursor: VariO IDs are strings, so parseInt() would map a
      // bookmarked "VariO:0026" to NaN → 0 and reset to page 1 (#531). The API
      // accepts a numeric page_after ("5") as a string just as well.
      currentItemID.value = urlParams.get('page_after') as string;
    }
    if (urlParams.get('page_size')) {
      perPage.value = parseInt(urlParams.get('page_size') as string, 10) || 25;
    }

    void nextTick(() => {
      if (disposed) return;
      loadData();
      void nextTick(() => {
        if (!disposed) isInitializing.value = false;
      });
    });
  });

  onBeforeUnmount(() => {
    disposed = true;
    tableIntentGeneration += 1;
    if (loadDataDebounceTimer.value) clearTimeout(loadDataDebounceTimer.value);
  });

  return {
    // tableData passthrough (spread for template/vm access parity)
    ...tableData,
    // Re-export the string-widened cursor refs so the exposed type matches the
    // runtime value (VariO IDs are strings) — same underlying refs as the
    // spread above, only the type surface is widened. Mirrors usePublicationsTable.
    prevItemID,
    nextItemID,
    lastItemID,
    filterObjToStr,
    filterStrToObj,
    sortStringToVariables,
    isExporting,
    exportToExcel,
    // local state
    filter,
    isInitializing,
    loadDataDebounceTimer,
    totalPages,
    ontologies,
    fields,
    mobileSortOptions,
    showEditModal,
    ontologyToEdit,
    // computed
    mobileSortValue,
    activeFilterOptions,
    obsoleteFilterOptions,
    hasActiveFilters,
    activeFilters,
    // methods
    updateBrowserUrl,
    filtered,
    handlePageChange,
    handlePerPageChange,
    handleSortByOrDescChange,
    removeFilters,
    clearFilter,
    handleSortUpdate,
    loadData,
    doLoadData,
    applyApiResponse,
    handleExport,
    editOntology,
    updateOntologyData,
  };
}

export default useOntologyAdminTable;
