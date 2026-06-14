// components/tables/useLogTable.ts
//
// State, data loading, cursor pagination, URL sync, filtering and delete/export
// orchestration for the audit-log table. Extracted from TablesLogs.vue so the
// SFC stays a thin shell (the view-logic lives here, the toolbar markup lives in
// LogFilterToolbar.vue). Composes the shared useTableData state container; the
// log-specific methods (load, cursor pagination, URL sync) are implemented here
// because they differ from the generic useTableMethods versions.

import { computed, nextTick, onMounted, ref, watch, type Ref } from 'vue';
import { useRoute } from 'vue-router';
// Import composables from the barrel so view specs that mock '@/composables'
// (e.g. TablesLogs.spec.ts) intercept these the same way the SFC did.
import { useToast, useUrlParsing, useColorAndSymbols, useText, useTableData } from '@/composables';
import Utils from '@/assets/js/utils';
import { useUiStore } from '@/stores/ui';
import {
  formatAbsoluteLogTime,
  formatLogDate,
  formatLogDuration,
  formatRelativeLogTime,
  getLogDurationClass,
  getLogMethodVariant,
  getLogStatusVariant,
} from './logTableFormatters';
import { extractApiErrorMessage } from '@/utils/api-errors';
import {
  listLogs,
  listLogsXlsx,
  deleteLogs as deleteLogsApi,
  type LogListResponse,
} from '@/api/logging';
import { listUsersByRole } from '@/api/user';
import { createLogTableRequestCache } from './logTableRequests';
import {
  LOG_TABLE_FIELDS,
  LOG_METHOD_OPTIONS,
  LOG_STATUS_OPTIONS,
  LOG_MOBILE_SORT_OPTIONS,
} from './logTableConfig';

const moduleLogRequestCache = createLogTableRequestCache();

export interface LogFilterField {
  content: string | null;
  join_char: string | null;
  operator: string;
}

export type LogFilter = Record<string, LogFilterField>;

// Single source of truth for the empty log-filter shape (used by both the
// initial filter ref and removeFilters() to avoid drift between the two).
export function createEmptyLogFilter(): LogFilter {
  return {
    any: { content: null, join_char: null, operator: 'contains' },
    id: { content: null, join_char: null, operator: 'contains' },
    timestamp: { content: null, join_char: null, operator: 'contains' },
    address: { content: null, join_char: null, operator: 'contains' },
    agent: { content: null, join_char: null, operator: 'contains' },
    host: { content: null, join_char: null, operator: 'contains' },
    user: { content: null, join_char: null, operator: 'contains' },
    request_method: { content: null, join_char: ',', operator: 'contains' },
    path: { content: null, join_char: ',', operator: 'contains' },
    query: { content: null, join_char: null, operator: 'contains' },
    post: { content: null, join_char: ',', operator: 'contains' },
    status: { content: null, join_char: ',', operator: 'contains' },
    duration: { content: null, join_char: ',', operator: 'contains' },
    file: { content: null, join_char: ',', operator: 'contains' },
    modified: { content: null, join_char: ',', operator: 'contains' },
  };
}

export interface UseLogTableProps {
  apiEndpoint?: string;
  sortInput?: string;
  filterInput?: string | null;
  pageAfterInput?: string;
  pageSizeInput?: number;
}

interface LogRow {
  id: number;
  [key: string]: unknown;
}

export function useLogTable(props: UseLogTableProps) {
  const { makeToast } = useToast();
  const { filterObjToStr, filterStrToObj, sortStringToVariables } = useUrlParsing();
  const colorAndSymbols = useColorAndSymbols();
  const text = useText();

  const tableData = useTableData({
    pageSizeInput: props.pageSizeInput,
    sortInput: props.sortInput,
    pageAfterInput: props.pageAfterInput,
  });

  const route = useRoute();

  // Component-specific filter
  const filter = ref<LogFilter>(createEmptyLogFilter());

  // ── Local state (was data()) ─────────────────────────────────────────────
  const isInitializing = ref(true);
  const loadDataDebounceTimer = ref<ReturnType<typeof setTimeout> | null>(null);
  const totalPages = ref(0);
  const user_options = ref<Array<{ value: string; text: string }>>([]);
  const method_options = LOG_METHOD_OPTIONS;
  const showLogDetail = ref(false);
  const selectedLog = ref<LogRow | null>(null);
  const selectedLogIndex = ref(-1);
  const fields = ref<Array<Record<string, unknown>>>([...LOG_TABLE_FIELDS]);
  const fields_details = ref<unknown[]>([]);
  const status_options = LOG_STATUS_OPTIONS;
  const mobileSortOptions = LOG_MOBILE_SORT_OPTIONS;
  const showDeleteModal = ref(false);
  const deleteMode = ref('all'); // 'all', '3', '7', '14', '30' (days)
  const isDeleting = ref(false);
  // Large exports are gated behind a confirmation modal (replaces window.confirm).
  const showExportModal = ref(false);
  const LARGE_EXPORT_THRESHOLD = 30000;

  // Pull the table-state refs we reference by name below.
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

  // ── Computed (was computed) ──────────────────────────────────────────────
  const mobileSortValue = computed<string>({
    get() {
      return sort.value || '-id';
    },
    set(value: string) {
      const sort_object = sortStringToVariables(value);
      sortBy.value = sort_object.sortBy;
      sort.value = value;
      currentItemID.value = 0;
      filtered();
    },
  });
  const canNavigatePrev = computed(() => selectedLogIndex.value > 0);
  const canNavigateNext = computed(() => selectedLogIndex.value < items.value.length - 1);
  const hasActiveFilters = computed(() =>
    Object.values(filter.value).some((f) => f.content !== null && f.content !== '')
  );
  const activeFilters = computed(() => {
    const filters: Array<{ key: string; label: string; value: string }> = [];
    if (filter.value.any.content) {
      filters.push({ key: 'any', label: 'Search', value: filter.value.any.content });
    }
    if (filter.value.user.content) {
      filters.push({ key: 'user', label: 'User', value: filter.value.user.content });
    }
    if (filter.value.request_method.content) {
      filters.push({
        key: 'request_method',
        label: 'Method',
        value: filter.value.request_method.content,
      });
    }
    if (filter.value.status.content) {
      filters.push({ key: 'status', label: 'Status', value: filter.value.status.content });
    }
    if (filter.value.path.content) {
      filters.push({ key: 'path', label: 'Path', value: filter.value.path.content });
    }
    return filters;
  });
  const removeFiltersButtonVariant = computed(() =>
    hasActiveFilters.value ? 'outline-danger' : 'outline-secondary'
  );
  const removeFiltersButtonTitle = computed(() =>
    hasActiveFilters.value ? 'Clear all filters' : 'No active filters'
  );

  // ── Methods ────────────────────────────────────────────────────────────────
  function handleRowClick(row: LogRow): void {
    selectedLog.value = row;
    selectedLogIndex.value = items.value.findIndex((item) => (item as LogRow).id === row.id);
    showLogDetail.value = true;
  }
  function navigateToPreviousLog(): void {
    if (selectedLogIndex.value > 0) {
      selectedLogIndex.value -= 1;
      selectedLog.value = items.value[selectedLogIndex.value] as LogRow;
    }
  }
  function navigateToNextLog(): void {
    if (selectedLogIndex.value < items.value.length - 1) {
      selectedLogIndex.value += 1;
      selectedLog.value = items.value[selectedLogIndex.value] as LogRow;
    }
  }

  async function loadUserList(): Promise<void> {
    try {
      const data = await listUsersByRole();
      user_options.value = data.map((item: { user_name: string; user_role: string }) => ({
        value: item.user_name,
        text: `${item.user_name} (${item.user_role})`,
      }));
    } catch (_e) {
      makeToast('Failed to load user list', 'Error', 'danger');
    }
  }

  // Debounced loadData to prevent duplicate calls from multiple triggers
  function loadData(): void {
    if (loadDataDebounceTimer.value) {
      clearTimeout(loadDataDebounceTimer.value);
    }
    loadDataDebounceTimer.value = setTimeout(() => {
      loadDataDebounceTimer.value = null;
      void doLoadData();
    }, 50);
  }

  async function doLoadData(): Promise<void> {
    const params = {
      sort: sort.value,
      filter: filter_string.value,
      page_after: currentItemID.value,
      page_size: perPage.value,
    };
    isBusy.value = true;

    try {
      const result = await moduleLogRequestCache.load(params, () => listLogs(params));
      applyApiResponse(result.response);

      // Update URL AFTER API success to prevent component remount during API call
      if (!result.fromCache) {
        updateBrowserUrl();
      }
      isBusy.value = false;
    } catch (error) {
      makeToast(`Error: ${(error as Error).message}`, 'Error loading logs', 'danger');
      isBusy.value = false;
    }
  }

  function applyApiResponse(data: LogListResponse): void {
    items.value = data.data;
    const meta = (data.meta as Array<Record<string, unknown>>)[0];
    totalRows.value = meta.totalItems as number;
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
    // Apply fspec from API for column filters (like TablesEntities)
    const fspec = meta.fspec as { fspec?: Array<Record<string, unknown>> } | undefined;
    if (fspec && fspec.fspec) {
      fields.value = fspec.fspec;
    }

    const uiStore = useUiStore();
    uiStore.requestScrollbarUpdate();
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
    void navigator.clipboard.writeText(`${import.meta.env.VITE_URL + route.path}?${urlParam}`);
  }

  function handleSortByOrDescChange(): void {
    currentItemID.value = 0;
    const sortColumn = sortBy.value.length > 0 ? sortBy.value[0].key : 'id';
    const sortOrder = sortBy.value.length > 0 ? sortBy.value[0].order : 'desc';
    sort.value = (sortOrder === 'desc' ? '-' : '+') + sortColumn;
    filtered();
  }

  function handleSortUpdate({ sortBy: key, sortDesc }: { sortBy: string; sortDesc: boolean }): void {
    sortBy.value = [{ key, order: sortDesc ? 'desc' : 'asc' }];
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

  function filtered(): void {
    const filter_string_loc = filterObjToStr(filter.value);
    if (filter_string_loc !== filter_string.value) {
      filter_string.value = filterObjToStr(filter.value);
    }
    loadData();
  }

  function removeFilters(): void {
    filter.value = createEmptyLogFilter();
  }

  function removeSearch(): void {
    filter.value.any.content = null;
  }

  // Single mutation entry point for the toolbar (props-down / events-up): the
  // toolbar emits update-filter; the composable owns the filter object.
  function setFilterField(key: string, value: string | null): void {
    if (filter.value[key]) {
      filter.value[key].content = value;
    }
    filtered();
  }

  function clearFilter(key: string): void {
    if (filter.value[key]) {
      filter.value[key].content = null;
    }
    filtered();
  }

  // Entry point bound to the toolbar's export button. Large exports open a
  // confirmation modal (the app's modal language) before downloading; smaller
  // exports proceed directly.
  function requestExcel(): void | Promise<void> {
    if (totalRows.value > LARGE_EXPORT_THRESHOLD) {
      showExportModal.value = true;
      return undefined;
    }
    return doExportExcel();
  }

  // Confirmed by the export modal (or reached directly for small exports).
  async function doExportExcel(): Promise<void> {
    showExportModal.value = false;
    downloading.value = true;
    try {
      const blob = await listLogsXlsx({
        page_after: 0,
        page_size: 'all',
        filter: filter_string.value,
        sort: sort.value,
      });

      const date = new Date().toISOString().split('T')[0];
      const filename = `sysndd_audit_logs_${date}.xlsx`;

      const fileURL = window.URL.createObjectURL(new Blob([blob]));
      const fileLink = document.createElement('a');
      fileLink.href = fileURL;
      fileLink.setAttribute('download', filename);
      document.body.appendChild(fileLink);
      fileLink.click();
      document.body.removeChild(fileLink);
      window.URL.revokeObjectURL(fileURL);

      makeToast(`Exported ${totalRows.value} log entries`, 'Export Complete', 'success');
    } catch (e) {
      makeToast(extractApiErrorMessage(e, 'Export failed'), 'Export failed', 'danger');
    }
    downloading.value = false;
  }

  function truncate(str: string, n: number): string {
    return Utils.truncate(str, n);
  }
  function formatDate(dateStr: string) {
    return formatLogDate(dateStr);
  }
  function formatRelativeTime(dateStr: string) {
    return formatRelativeLogTime(dateStr);
  }
  function formatAbsoluteTime(dateStr: string) {
    return formatAbsoluteLogTime(dateStr);
  }
  function getStatusVariant(status: number | string) {
    return getLogStatusVariant(status);
  }
  function getMethodVariant(method: string) {
    return getLogMethodVariant(method);
  }
  function formatDuration(duration: number) {
    return formatLogDuration(duration);
  }
  function getDurationClass(duration: number) {
    return getLogDurationClass(duration);
  }

  async function deleteLogs(): Promise<void> {
    isDeleting.value = true;
    try {
      const olderThanDays = deleteMode.value === 'all' ? 0 : parseInt(deleteMode.value, 10);
      const response = await deleteLogsApi({ older_than_days: olderThanDays });

      const deletedCount = response.deleted_count || 0;
      const message =
        deleteMode.value === 'all'
          ? `Successfully deleted ${deletedCount.toLocaleString()} log entries`
          : `Successfully deleted ${deletedCount.toLocaleString()} log entries older than ${deleteMode.value} days`;

      makeToast(message, 'Logs Deleted', 'success');
      // Closing the modal triggers its @hidden reset (confirm text + mode)
      showDeleteModal.value = false;
      currentItemID.value = 0;
      loadData();
    } catch (error) {
      const errorMsg = extractApiErrorMessage(error, 'Failed to delete logs');
      makeToast(`Failed to delete logs: ${errorMsg}`, 'Error', 'danger');
    } finally {
      isDeleting.value = false;
    }
  }

  // ── Watchers ───────────────────────────────────────────────────────────────
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
    (newVal) => {
      if (isInitializing.value) return;
      const newSortColumn = newVal && newVal.length > 0 ? newVal[0].key : 'id';
      const newSortOrder = newVal && newVal.length > 0 ? newVal[0].order : 'desc';
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
    if (props.sortInput) {
      const sort_object = sortStringToVariables(props.sortInput);
      sortBy.value = sort_object.sortBy;
      sort.value = props.sortInput;
    }

    if (props.pageAfterInput && props.pageAfterInput !== '0') {
      currentItemID.value = parseInt(props.pageAfterInput, 10) || 0;
    }

    loadUserList();

    void nextTick(() => {
      if (props.filterInput && props.filterInput !== 'null' && props.filterInput !== '') {
        filter.value = filterStrToObj(props.filterInput, filter.value) as LogFilter;
        filter_string.value = props.filterInput;
      }
      loadData();
      void nextTick(() => {
        isInitializing.value = false;
      });
    });

    loading.value = false;
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
    user_options,
    method_options,
    status_options,
    mobileSortOptions,
    showLogDetail,
    selectedLog,
    selectedLogIndex,
    fields,
    fields_details,
    showDeleteModal,
    deleteMode,
    isDeleting,
    showExportModal,
    // computed
    mobileSortValue,
    canNavigatePrev,
    canNavigateNext,
    hasActiveFilters,
    activeFilters,
    removeFiltersButtonVariant,
    removeFiltersButtonTitle,
    // methods
    handleRowClick,
    navigateToPreviousLog,
    navigateToNextLog,
    loadUserList,
    loadData,
    doLoadData,
    applyApiResponse,
    updateBrowserUrl,
    copyLinkToClipboard,
    handleSortByOrDescChange,
    handleSortUpdate,
    handlePageChange,
    handlePerPageChange,
    filtered,
    removeFilters,
    removeSearch,
    setFilterField,
    clearFilter,
    requestExcel,
    doExportExcel,
    truncate,
    formatDate,
    formatRelativeTime,
    formatAbsoluteTime,
    getStatusVariant,
    getMethodVariant,
    formatDuration,
    getDurationClass,
    deleteLogs,
  };
}
