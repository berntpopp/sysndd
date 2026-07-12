import { getCurrentInstance, nextTick, onBeforeUnmount, ref } from 'vue';

import { getUserTable, getRoleList, listUsersByRole } from '@/api/user';
import type { UserTableResponse } from '@/api/user';
import { useTableData, useExcelExport, useFilterPresets, useUrlParsing } from '@/composables';

// Module-level TRANSPORT dedup + 500ms response cache (preserves the existing
// cross-instance semantics from ManageUser.vue line 760). The cached response is
// keyed by its own params (`moduleLastApiResponseParams`) so it is never served
// for a request whose params differ (#535 S5b). Consumer-state ownership is
// instance-local (see `instanceGeneration`), so one instance cannot suppress
// another's response or leave its `isBusy` stuck.
let moduleLastApiParams: string | null = null;
let moduleLastApiCallTime = 0;
let moduleApiCallInProgress = false;
let moduleLastApiResponse: unknown = null;
let moduleLastApiResponseParams: string | null = null;

/** Reset the module-level cache — for use in tests only. */
export function __resetUserDataCache(): void {
  moduleLastApiParams = null;
  moduleLastApiCallTime = 0;
  moduleApiCallInProgress = false;
  moduleLastApiResponse = null;
  moduleLastApiResponseParams = null;
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

  // Instance-local request ownership (#535 S5b). Two orthogonal signals:
  //  - `latestIntent` is the params string of the most recent load intent, set the
  //    moment a load is requested (loadData schedule / loadDataNow). An in-flight
  //    response applies only if its params still equal `latestIntent`, which closes
  //    the 50ms debounce window (refs already describe P2 while P1 is in flight)
  //    WITHOUT orphaning a deduped identical request (same params → same intent).
  //  - `startGeneration` is bumped only when a fetch actually starts, so among
  //    same-params requests only the latest-started may apply (true A-B-A: A#1, B,
  //    A2 all in flight → only A2 wins). `disposed` stops any late continuation
  //    from mutating a torn-down instance.
  let startGeneration = 0;
  let latestIntent: string | null = null;
  let disposed = false;

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

  function buildUrlParam(): string {
    return `sort=${tableData.sort.value}&filter=${tableData.filter_string.value}&page_after=${tableData.currentItemID.value}&page_size=${tableData.perPage.value}`;
  }

  function applyApiResponse(data: UserTableResponse, stillOwner: () => boolean): void {
    // meta is typed `unknown` on the envelope; it's a 1-element array of paging
    // scalars (Plumber may serialize numbers as strings, hence Number()).
    const meta = ((data.meta as Array<Record<string, unknown>>) ?? [])[0] ?? {};
    users.value = data.data as unknown as Array<Record<string, unknown>>;
    tableData.totalRows.value = Number(meta.totalItems) || 0;
    nextTick(() => {
      // The deferred write must re-check ownership: a newer request or an unmount
      // may have superseded this response between the sync apply and this tick.
      if (stillOwner()) tableData.currentPage.value = Number(meta.currentPage) || 0;
    });
    totalPages.value = Number(meta.totalPages) || 0;
    tableData.prevItemID.value = Number(meta.prevItemID) || 0;
    tableData.currentItemID.value = Number(meta.currentItemID) || 0;
    tableData.nextItemID.value = Number(meta.nextItemID) || 0;
    tableData.lastItemID.value = Number(meta.lastItemID) || 0;
    tableData.executionTime.value = Number(meta.executionTime) || 0;
    onScrollbarUpdate?.();
  }

  async function doLoadData(): Promise<void> {
    const urlParam = buildUrlParam();
    const now = Date.now();

    // Recent-response cache: serve only a NON-NULL response stored under THESE
    // params, and only if this instance still wants them.
    if (
      moduleLastApiResponseParams === urlParam &&
      moduleLastApiResponse != null &&
      now - moduleLastApiCallTime < 500
    ) {
      if (!disposed && urlParam === latestIntent) {
        // A current cache hit is a completed current intent: apply, sync the URL,
        // and clear busy — otherwise a still-pending superseded request (A→B→cached-A)
        // could leave isBusy stuck true forever.
        applyApiResponse(
          moduleLastApiResponse as UserTableResponse,
          () => !disposed && urlParam === latestIntent
        );
        updateBrowserUrl();
        tableData.isBusy.value = false;
      }
      return;
    }
    // Transport dedup: an identical request is already in flight. Do NOT bump the
    // start generation here — the in-flight request is the same intent.
    if (moduleApiCallInProgress && moduleLastApiParams === urlParam) return;

    // A real fetch starts now → own the start generation. `stillOwner` combines it
    // with the params intent so it stays stable across applyApiResponse's own ref
    // mutations (latestIntent only moves on a new loadData/loadDataNow call).
    const myGen = ++startGeneration;
    const stillOwner = (): boolean =>
      !disposed && myGen === startGeneration && urlParam === latestIntent;

    moduleLastApiParams = urlParam;
    moduleLastApiCallTime = now;
    moduleApiCallInProgress = true;
    // A fresh request invalidates any stored response until this one records its own.
    moduleLastApiResponse = null;
    moduleLastApiResponseParams = null;
    if (stillOwner()) tableData.isBusy.value = true;

    try {
      const data = await getUserTable({
        sort: tableData.sort.value,
        filter: tableData.filter_string.value,
        page_after: tableData.currentItemID.value,
        page_size: String(tableData.perPage.value),
      });
      // Transport bookkeeping: the completing fetch clears the in-flight flag and
      // records its param-keyed response regardless of which intent is now current
      // (param-keying makes late-completion order irrelevant to correctness).
      moduleApiCallInProgress = false;
      moduleLastApiResponse = data;
      moduleLastApiResponseParams = urlParam;
      // Consumer apply: only the latest-started request for the current intent.
      if (!stillOwner()) return;
      applyApiResponse(data, stillOwner);
      updateBrowserUrl();
    } catch (e) {
      moduleApiCallInProgress = false;
      if (!stillOwner()) return;
      onToast?.(e, 'Error', 'danger');
    } finally {
      if (stillOwner()) tableData.isBusy.value = false;
    }
  }

  function loadData(): void {
    // Record the new intent immediately (before the debounce) so an in-flight
    // response for the previous intent is superseded even during the 50ms window.
    latestIntent = buildUrlParam();
    if (loadDataDebounceTimer) clearTimeout(loadDataDebounceTimer);
    loadDataDebounceTimer = setTimeout(() => {
      loadDataDebounceTimer = null;
      void doLoadData();
    }, 50);
  }

  // Bypasses debounce for tests + first-paint
  async function loadDataNow(): Promise<void> {
    latestIntent = buildUrlParam();
    return doLoadData();
  }

  async function loadRoleList(): Promise<void> {
    try {
      const roles = await getRoleList();
      role_options.value = roles.map((item) => ({
        value: item.role,
        text: item.role,
      }));
    } catch (e) {
      onToast?.(e, 'Error', 'danger');
    }
  }

  async function loadUserList(): Promise<void> {
    try {
      const list = await listUsersByRole({ roles: 'Curator,Reviewer' });
      user_options.value = list.map((item) => ({
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
    const currentItemID = String(tableData.currentItemID.value);
    if (currentItemID !== '' && currentItemID !== '0') {
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

  // Filter-preset naming uses the app's modal language (SavePresetModal) rather
  // than a native window.prompt(); the modal state lives here next to the
  // preset actions it drives.
  const savePresetModalOpen = ref(false);

  function confirmSavePreset(name: string): void {
    saveFilterPreset(name);
    onToast?.(`Saved preset: ${name}`, 'Filter Preset', 'success', true, 3000);
  }

  function setInitialized(): void {
    nextTick(() => {
      isInitializing.value = false;
    });
  }

  // Teardown: cancel a pending debounce and invalidate ownership so a late
  // response cannot apply rows or call history.replaceState() after the view has
  // unmounted/navigated away. Guarded so a bare composable call (unit tests) does
  // not warn about a lifecycle hook registered outside a component setup.
  function dispose(): void {
    disposed = true;
    if (loadDataDebounceTimer) {
      clearTimeout(loadDataDebounceTimer);
      loadDataDebounceTimer = null;
    }
  }
  if (getCurrentInstance()) {
    onBeforeUnmount(dispose);
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
    savePresetModalOpen,
    confirmSavePreset,
    setInitialized,
    // Teardown hook (auto-invoked on unmount when mounted; exposed for tests).
    dispose,
  };
}
