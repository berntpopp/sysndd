import { nextTick, ref } from 'vue';

import { apiClient } from '@/api/client';
import { useTableData, useExcelExport, useFilterPresets, useUrlParsing } from '@/composables';

// Module-level dedup cache (preserves the existing semantics from ManageUser.vue line 760).
let moduleLastApiParams: string | null = null;
let moduleLastApiCallTime = 0;
let moduleApiCallInProgress = false;
let moduleLastApiResponse: unknown = null;

/** Reset the module-level cache — for use in tests only. */
export function __resetUserDataCache(): void {
  moduleLastApiParams = null;
  moduleLastApiCallTime = 0;
  moduleApiCallInProgress = false;
  moduleLastApiResponse = null;
}

export interface FilterEntry {
  content: string | null;
  join_char: string | null;
  operator: string;
}

export type ManageUserFilter = Record<string, FilterEntry>;

export interface RoleOption {
  value: string;
  text: string;
}

export interface UserOption {
  value: number;
  text: string;
  role: string;
}

export interface UseUserDataOptions {
  onToast?: (...args: unknown[]) => void;
  onScrollbarUpdate?: () => void;
}

export function useUserData(options: UseUserDataOptions = {}) {
  const { onToast, onScrollbarUpdate } = options;
  const apiBase = import.meta.env.VITE_API_URL ?? '';

  const tableData = useTableData({
    pageSizeInput: 25,
    sortInput: '+user_name',
    pageAfterInput: '0',
  });
  const { filterObjToStr, filterStrToObj, sortStringToVariables } = useUrlParsing();
  const filterPresets = useFilterPresets('sysndd-manage-user-presets');
  const { isExporting, exportToExcel } = useExcelExport();

  const users = ref<Array<Record<string, unknown>>>([]);
  const role_options = ref<RoleOption[]>([]);
  const user_options = ref<UserOption[]>([]);
  const totalPages = ref(0);
  const isInitializing = ref(true);
  let loadDataDebounceTimer: ReturnType<typeof setTimeout> | null = null;

  const filter = ref<ManageUserFilter>({
    any: { content: null, join_char: null, operator: 'contains' },
    user_name: { content: null, join_char: null, operator: 'contains' },
    email: { content: null, join_char: null, operator: 'contains' },
    user_role: { content: null, join_char: ',', operator: 'any' },
    approved: { content: null, join_char: null, operator: 'equals' },
    abbreviation: { content: null, join_char: null, operator: 'contains' },
    first_name: { content: null, join_char: null, operator: 'contains' },
    family_name: { content: null, join_char: null, operator: 'contains' },
    orcid: { content: null, join_char: null, operator: 'contains' },
    comment: { content: null, join_char: null, operator: 'contains' },
  });

  function applyApiResponse(data: any): void {
    users.value = data.data;
    tableData.totalRows.value = data.meta[0].totalItems;
    nextTick(() => {
      tableData.currentPage.value = data.meta[0].currentPage;
    });
    totalPages.value = data.meta[0].totalPages;
    tableData.prevItemID.value = Number(data.meta[0].prevItemID) || 0;
    tableData.currentItemID.value = Number(data.meta[0].currentItemID) || 0;
    tableData.nextItemID.value = Number(data.meta[0].nextItemID) || 0;
    tableData.lastItemID.value = Number(data.meta[0].lastItemID) || 0;
    tableData.executionTime.value = data.meta[0].executionTime;
    onScrollbarUpdate?.();
  }

  async function doLoadData(): Promise<void> {
    const urlParam = `sort=${tableData.sort.value}&filter=${tableData.filter_string.value}&page_after=${tableData.currentItemID.value}&page_size=${tableData.perPage.value}`;
    const now = Date.now();
    if (moduleLastApiParams === urlParam && now - moduleLastApiCallTime < 500) {
      if (moduleLastApiResponse) applyApiResponse(moduleLastApiResponse);
      return;
    }
    if (moduleApiCallInProgress && moduleLastApiParams === urlParam) return;
    moduleLastApiParams = urlParam;
    moduleLastApiCallTime = now;
    moduleApiCallInProgress = true;
    tableData.isBusy.value = true;

    try {
      const response = await apiClient.raw.get(`${apiBase}/api/user/table?${urlParam}`);
      moduleApiCallInProgress = false;
      moduleLastApiResponse = response.data;
      applyApiResponse(response.data);
      updateBrowserUrl();
    } catch (e) {
      moduleApiCallInProgress = false;
      onToast?.(e, 'Error', 'danger');
    } finally {
      tableData.isBusy.value = false;
    }
  }

  function loadData(): void {
    if (loadDataDebounceTimer) clearTimeout(loadDataDebounceTimer);
    loadDataDebounceTimer = setTimeout(() => {
      loadDataDebounceTimer = null;
      void doLoadData();
    }, 50);
  }

  // Bypasses debounce for tests + first-paint
  async function loadDataNow(): Promise<void> {
    return doLoadData();
  }

  async function loadRoleList(): Promise<void> {
    try {
      const response = await apiClient.raw.get(`${apiBase}/api/user/role_list`);
      role_options.value = (response.data as Array<{ role: string }>).map((item) => ({
        value: item.role,
        text: item.role,
      }));
    } catch (e) {
      onToast?.(e, 'Error', 'danger');
    }
  }

  async function loadUserList(): Promise<void> {
    try {
      const response = await apiClient.raw.get(
        `${apiBase}/api/user/list?roles=Curator,Reviewer`,
      );
      user_options.value = (
        response.data as Array<{ user_id: number; user_name: string; user_role: string }>
      ).map((item) => ({
        value: item.user_id,
        text: item.user_name,
        role: item.user_role,
      }));
    } catch (e) {
      onToast?.(e, 'Error', 'danger');
    }
  }

  function updateBrowserUrl(): void {
    if (isInitializing.value) return;
    const searchParams = new URLSearchParams();
    if (tableData.sort.value) searchParams.set('sort', tableData.sort.value);
    if (tableData.filter_string.value) searchParams.set('filter', tableData.filter_string.value);
    if (tableData.currentItemID.value > 0) {
      searchParams.set('page_after', String(tableData.currentItemID.value));
    }
    searchParams.set('page_size', String(tableData.perPage.value));
    const newUrl = `${window.location.pathname}?${searchParams.toString()}`;
    window.history.replaceState({ ...window.history.state }, '', newUrl);
  }

  function filtered(): void {
    const next = filterObjToStr(filter.value);
    if (next !== tableData.filter_string.value) tableData.filter_string.value = next;
    loadData();
  }

  function handlePageChange(value: number): void {
    if (value === 1) tableData.currentItemID.value = 0;
    else if (value === totalPages.value)
      tableData.currentItemID.value = Number(tableData.lastItemID.value) || 0;
    else if (value > tableData.currentPage.value)
      tableData.currentItemID.value = Number(tableData.nextItemID.value) || 0;
    else if (value < tableData.currentPage.value)
      tableData.currentItemID.value = Number(tableData.prevItemID.value) || 0;
    filtered();
  }

  function handlePerPageChange(newPerPage: number | string): void {
    tableData.perPage.value = parseInt(String(newPerPage), 10);
    tableData.currentItemID.value = 0;
    filtered();
  }

  function handleSortByOrDescChange(): void {
    tableData.currentItemID.value = 0;
    const sortColumn = tableData.sortBy.value.length > 0 ? tableData.sortBy.value[0].key : '';
    const sortOrder = tableData.sortBy.value.length > 0 ? tableData.sortBy.value[0].order : 'asc';
    tableData.sort.value = (sortOrder === 'desc' ? '-' : '+') + sortColumn;
    filtered();
  }

  function handleSortUpdate(newSortBy: Array<{ key: string; order: 'asc' | 'desc' }>): void {
    tableData.sortBy.value = newSortBy;
    handleSortByOrDescChange();
  }

  function removeFilters(): void {
    Object.keys(filter.value).forEach((key) => {
      const entry = filter.value[key];
      if (entry && typeof entry === 'object' && 'content' in entry) entry.content = null;
    });
    filtered();
  }

  function clearFilter(key: string): void {
    if (filter.value[key]) filter.value[key].content = null;
    filtered();
  }

  function handleExport(): void {
    exportToExcel(users.value, {
      filename: `users_export_${new Date().toISOString().split('T')[0]}`,
      sheetName: 'Users',
      headers: {
        user_name: 'User Name',
        email: 'Email',
        user_role: 'Role',
        approved: 'Approved',
        abbreviation: 'Abbreviation',
        first_name: 'First Name',
        family_name: 'Family Name',
        orcid: 'ORCID',
        comment: 'Comment',
        created_at: 'Created',
      },
    });
  }

  function loadFilterPreset(name: string): boolean {
    const preset = filterPresets.loadPreset(name);
    if (!preset) return false;
    Object.keys(preset).forEach((key) => {
      if (filter.value[key]) filter.value[key] = preset[key] as FilterEntry;
    });
    filtered();
    return true;
  }

  function deleteFilterPreset(name: string): void {
    filterPresets.deletePreset(name);
  }

  function saveFilterPreset(name: string): void {
    filterPresets.savePreset(name, JSON.parse(JSON.stringify(filter.value)));
  }

  function setInitialized(): void {
    nextTick(() => {
      isInitializing.value = false;
    });
  }

  return {
    // table-data passthrough (so the view doesn't need to re-pull useTableData)
    ...tableData,
    isExporting,
    exportToExcel,
    filterPresets,
    filterObjToStr,
    filterStrToObj,
    sortStringToVariables,
    // owned state
    users,
    role_options,
    roleOptions: role_options, // canonical TS name
    user_options,
    totalPages,
    filter,
    isInitializing,
    // actions
    loadData,
    loadDataNow,
    loadRoleList,
    loadUserList,
    filtered,
    handlePageChange,
    handlePerPageChange,
    handleSortByOrDescChange,
    handleSortUpdate,
    removeFilters,
    clearFilter,
    handleExport,
    loadFilterPreset,
    deleteFilterPreset,
    saveFilterPreset,
    setInitialized,
  };
}
