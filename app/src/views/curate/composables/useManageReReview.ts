// app/src/views/curate/composables/useManageReReview.ts
/**
 * Controller composable for ManageReReview.vue (#346 WP9 decomposition).
 *
 * Owns the entire re-review management workflow that previously lived inline in
 * the 1.5k-line view: shared reactive state, derived counts, filter options,
 * the four mount loaders, the manual entity-assignment actions, batch
 * reassignment, and batch recalculation. Extracted verbatim so the view becomes
 * a thin shell delegating the table/toolbar and the modals to child components.
 *
 * Behaviour is intentionally preserved 1:1 with the original Options-API view —
 * the nine authed endpoint calls, the Plumber scalar-array total unwrap, the
 * selection validation, the fallback success copy, and the refresh side effects
 * all match the pre-refactor semantics. Toast + aria-live are injected (like the
 * sibling ModifyEntity composables) so the composable stays framework-light and
 * directly unit-testable without a mounted host.
 */

import { computed, ref, watch } from 'vue';
import {
  assignReReviewBatch,
  assignReReviewEntities,
  getAssignmentTable,
  listAvailableReReviewEntities,
  recalculateReReviewBatch,
  reassignReReviewBatch,
  unassignReReviewBatch,
  type AvailableReReviewEntity,
  type RecalculateBatchRequest,
} from '@/api/re_review';
import { listUsersByRole } from '@/api/user';
import { listStatusCategories, type StatusCategoryRow } from '@/api/list';
import { useUiStore } from '@/stores/ui';
import {
  filterReReviewBatches,
  sortReReviewBatches,
  type ReReviewBatchRow,
  type ReReviewAssignmentFilter,
} from '@/views/curate/utils/reReviewFilters';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type BatchMode = 'criteria' | 'manual' | null;

export interface UserOption {
  value: number;
  text: string;
  role?: string;
}

export interface SelectOption {
  value: string | number | null;
  text: string;
}

export interface ReReviewSortEntry {
  key: string;
  order: 'asc' | 'desc';
}

export interface RecalculateCriteria {
  date_range: { start: string | null; end: string | null };
  gene_list: number[];
  status_filter: number | null;
  batch_size: number;
}

export interface UseManageReReviewDeps {
  onToast: (...args: unknown[]) => void;
  announce: (message: string, politeness?: 'polite' | 'assertive') => void;
}

/** Pull `response.data.message` off an unknown (axios) error, strict-safely. */
function errorMessage(error: unknown, fallback: string): string {
  const message = (error as { response?: { data?: { message?: string } } })?.response?.data
    ?.message;
  return message || fallback;
}

export function useManageReReview(deps: UseManageReReviewDeps) {
  const { onToast, announce } = deps;

  // -------------------------------------------------------------------------
  // Shared state
  // -------------------------------------------------------------------------
  const filter = ref<string | null>(null);
  const userFilter = ref<string | null>(null);
  const assignmentFilter = ref<ReReviewAssignmentFilter>(null);
  const activeBatchMode = ref<BatchMode>(null);

  const loadingReReviewManagment = ref(false);
  const user_options = ref<UserOption[]>([]);
  const user_id_assignment = ref<number>(0);
  const items_ReReviewTable = ref<ReReviewBatchRow[]>([]);
  const sortBy = ref<ReReviewSortEntry[]>([{ key: 'user_name', order: 'asc' }]);
  const currentPage = ref(1);
  const perPage = ref(25);
  const totalRows = ref(0);
  const pageOptions = [10, 25, 50, 100];

  // Gene-specific assignment (RRV-06)
  const availableEntities = ref<AvailableReReviewEntity[]>([]);
  const availableEntityTotal = ref(0);
  const selectedEntityIds = ref<number[]>([]);
  const manualEntityFilter = ref<string | null>(null);
  const entityAssignUserId = ref<number | null>(null);
  const entityAssignBatchName = ref('');
  const isLoadingEntities = ref(false);
  const isAssigningEntities = ref(false);

  // Gene-atomic batch boundary hint (issue #29). Set by the batch preview when
  // the soft-LIMIT engaged and a gene was partially included.
  const previewBoundaryGene = ref<string | null>(null);
  const previewGeneCount = ref(0);
  const previewEntityCount = ref(0);

  // Reassignment
  const reassignModalShow = ref(false);
  const reassignBatchId = ref<number | null>(null);
  const reassignNewUserId = ref<number | null>(null);

  // Recalculation (RRV-05)
  const recalculateModalShow = ref(false);
  const recalculateBatchId = ref<number | null>(null);
  const recalculateCriteria = ref<RecalculateCriteria>({
    date_range: { start: null, end: null },
    gene_list: [],
    status_filter: null,
    batch_size: 20,
  });
  const isRecalculating = ref(false);

  // Status options for the recalculate modal
  const status_options = ref<SelectOption[]>([]);

  // -------------------------------------------------------------------------
  // Derived state
  // -------------------------------------------------------------------------
  const assignedBatchCount = computed(
    () => items_ReReviewTable.value.filter((item) => item.user_id).length
  );
  const unassignedBatchCount = computed(
    () => items_ReReviewTable.value.filter((item) => !item.user_id).length
  );

  const boundaryGeneAlertVisible = computed(() => Boolean(previewBoundaryGene.value));
  const boundaryGeneAlertMessage = computed(() => {
    if (!previewBoundaryGene.value) return '';
    return (
      `Batch is gene-atomic: to keep gene ${previewBoundaryGene.value} together, ` +
      `the available-entity list holds ${previewEntityCount.value} entities across ` +
      `${previewGeneCount.value} gene(s). The last gene was extended past the ` +
      `batch_size cap to avoid splitting it. Tighten criteria or increase ` +
      `batch size to avoid the overflow.`
    );
  });

  const userFilterOptions = computed<SelectOption[]>(() => {
    const uniqueUsers = [
      ...new Set(
        items_ReReviewTable.value
          .filter((item) => item.user_name)
          .map((item) => item.user_name as string)
      ),
    ];
    return uniqueUsers.map((name) => ({ value: name, text: name }));
  });

  const assignmentFilterOptions: SelectOption[] = [
    { value: 'assigned', text: 'Assigned' },
    { value: 'unassigned', text: 'Unassigned' },
  ];

  const filteredItems = computed<ReReviewBatchRow[]>(() =>
    filterReReviewBatches(items_ReReviewTable.value, {
      text: filter.value,
      userName: userFilter.value,
      assignment: assignmentFilter.value,
    })
  );

  const sortedItems = computed<ReReviewBatchRow[]>(() =>
    sortReReviewBatches(filteredItems.value, sortBy.value)
  );

  const paginatedItems = computed<ReReviewBatchRow[]>(() => {
    const start = (currentPage.value - 1) * perPage.value;
    return sortedItems.value.slice(start, start + perPage.value);
  });

  // Keep totalRows synced with the filtered set (matches the original watcher).
  watch(filteredItems, (newItems) => {
    totalRows.value = newItems.length;
  });

  // -------------------------------------------------------------------------
  // Loaders
  // -------------------------------------------------------------------------
  async function loadUserList(): Promise<void> {
    try {
      const data = await listUsersByRole({ roles: 'Curator,Reviewer' });
      user_options.value = Array.isArray(data)
        ? data.map((item) => ({
            value: item.user_id,
            text: item.user_name,
            role: item.user_role,
          }))
        : [];
    } catch (e) {
      onToast(e, 'Error', 'danger');
      user_options.value = [];
    }
  }

  async function loadReReviewTableData(): Promise<void> {
    loadingReReviewManagment.value = true;
    try {
      const data: unknown = await getAssignmentTable();
      if (Array.isArray(data)) {
        items_ReReviewTable.value = data as ReReviewBatchRow[];
        totalRows.value = data.length;
      } else if (
        data &&
        typeof data === 'object' &&
        Array.isArray((data as { data?: unknown }).data)
      ) {
        const paginated = data as {
          data: ReReviewBatchRow[];
          meta?: Array<{ totalItems?: number }>;
        };
        items_ReReviewTable.value = paginated.data;
        totalRows.value = paginated.meta?.[0]?.totalItems || paginated.data.length;
      } else {
        console.error('Unexpected re-review table response format:', data);
        items_ReReviewTable.value = [];
        totalRows.value = 0;
      }
    } catch (e) {
      onToast(e, 'Error', 'danger');
      items_ReReviewTable.value = [];
      totalRows.value = 0;
    } finally {
      const uiStore = useUiStore();
      uiStore.requestScrollbarUpdate();
      loadingReReviewManagment.value = false;
    }
  }

  async function loadAvailableEntities(): Promise<void> {
    isLoadingEntities.value = true;
    try {
      const responseData = await listAvailableReReviewEntities({
        q: manualEntityFilter.value || '',
        page: 1,
        page_size: 100,
      });
      availableEntities.value = responseData.data || [];
      const total = responseData.meta?.total;
      availableEntityTotal.value = Array.isArray(total)
        ? (total[0] ?? availableEntities.value.length)
        : (total ?? availableEntities.value.length);
      previewBoundaryGene.value = null;
      previewGeneCount.value = 0;
      previewEntityCount.value = 0;
    } catch (_e) {
      onToast('Failed to load available entities', 'Error', 'danger');
    } finally {
      isLoadingEntities.value = false;
    }
  }

  async function loadStatusOptions(): Promise<void> {
    try {
      const raw: unknown = await listStatusCategories();
      const rows: unknown = Array.isArray(raw) ? raw : ((raw as { data?: unknown })?.data ?? raw);
      status_options.value = Array.isArray(rows)
        ? (rows as StatusCategoryRow[]).map((item) => ({
            value: item.category_id,
            text: item.category,
          }))
        : [];
    } catch (_e) {
      status_options.value = [];
    }
  }

  /**
   * Fire all four mount loaders concurrently (fire-and-forget), matching the
   * original `mounted()` hook. Intentionally not awaited so a slow loader never
   * head-of-line blocks the others.
   */
  function initialize(): void {
    loadUserList();
    loadReReviewTableData();
    loadAvailableEntities();
    loadStatusOptions();
  }

  // -------------------------------------------------------------------------
  // Filter / pagination / sort handlers
  // -------------------------------------------------------------------------
  function applyFilters(): void {
    currentPage.value = 1;
  }

  function handlePageChange(page: number): void {
    currentPage.value = page;
  }

  function handlePerPageChange(nextPerPage: number): void {
    perPage.value = nextPerPage;
    currentPage.value = 1;
  }

  function handleSortUpdate(payload: { sortBy: string; sortDesc: boolean }): void {
    sortBy.value = [{ key: payload.sortBy, order: payload.sortDesc ? 'desc' : 'asc' }];
    currentPage.value = 1;
  }

  // -------------------------------------------------------------------------
  // Legacy batch assignment
  // -------------------------------------------------------------------------
  async function handleNewBatchAssignment(): Promise<void> {
    try {
      await assignReReviewBatch({ user_id: user_id_assignment.value });
      onToast('New batch assigned successfully.', 'Success', 'success');
      announce('New batch assigned successfully');
    } catch (e) {
      onToast(e, 'Error', 'danger');
      announce('Failed to assign batch', 'assertive');
    }
    loadReReviewTableData();
  }

  async function handleBatchUnAssignment(batch_id: number): Promise<void> {
    try {
      await unassignReReviewBatch({ re_review_batch: batch_id });
      onToast('Batch unassigned successfully.', 'Success', 'success');
      announce('Batch unassigned successfully');
    } catch (e) {
      onToast(e, 'Error', 'danger');
      announce('Failed to unassign batch', 'assertive');
    }
    loadReReviewTableData();
  }

  // -------------------------------------------------------------------------
  // Criteria-batch creation callback
  // -------------------------------------------------------------------------
  function onBatchCreated(): void {
    loadReReviewTableData();
    loadAvailableEntities();
    onToast('Batch created and table refreshed', 'Success', 'success');
    announce('Batch created successfully');
  }

  // -------------------------------------------------------------------------
  // Manual entity assignment (RRV-06)
  // -------------------------------------------------------------------------
  function toggleEntitySelection(entityId: number): void {
    if (selectedEntityIds.value.includes(entityId)) {
      selectedEntityIds.value = selectedEntityIds.value.filter((id) => id !== entityId);
      return;
    }
    selectedEntityIds.value = [...selectedEntityIds.value, entityId];
  }

  function clearManualSelection(): void {
    selectedEntityIds.value = [];
  }

  async function handleEntityAssignment(): Promise<void> {
    if (selectedEntityIds.value.length === 0) {
      onToast('Please select at least one entity', 'Validation', 'warning');
      return;
    }
    if (!entityAssignUserId.value) {
      onToast('Please select a user', 'Validation', 'warning');
      return;
    }

    isAssigningEntities.value = true;
    try {
      const responseData = await assignReReviewEntities({
        entity_ids: selectedEntityIds.value,
        user_id: entityAssignUserId.value,
        batch_name: entityAssignBatchName.value || null,
      });

      const result = responseData.entry;
      const message =
        result?.batch_id != null && result?.entity_count != null
          ? `Created batch ${result.batch_id} with ${result.entity_count} entities`
          : 'Created assignment batch, but the batch summary was unavailable';
      onToast(message, 'Success', 'success');
      announce(message);

      selectedEntityIds.value = [];
      entityAssignUserId.value = null;
      entityAssignBatchName.value = '';
      loadReReviewTableData();
      loadAvailableEntities();
    } catch (e) {
      onToast(errorMessage(e, 'Assignment failed'), 'Error', 'danger');
      announce('Failed to assign entities', 'assertive');
    } finally {
      isAssigningEntities.value = false;
    }
  }

  // -------------------------------------------------------------------------
  // Reassignment
  // -------------------------------------------------------------------------
  function openReassignModal(item: ReReviewBatchRow): void {
    reassignBatchId.value = (item.re_review_batch as number) ?? null;
    reassignNewUserId.value = (item.user_id as number) ?? null; // Pre-select current user
    reassignModalShow.value = true;
  }

  async function handleBatchReassignment(): Promise<void> {
    if (!reassignNewUserId.value) {
      onToast('Please select a user', 'Validation', 'warning');
      return;
    }

    try {
      await reassignReReviewBatch({
        re_review_batch: reassignBatchId.value as number,
        user_id: reassignNewUserId.value,
      });
      onToast('Batch reassigned successfully', 'Success', 'success');
      announce('Batch reassigned successfully');
      reassignModalShow.value = false;
      loadReReviewTableData();
    } catch (e) {
      onToast(errorMessage(e, 'Reassignment failed'), 'Error', 'danger');
      announce('Failed to reassign batch', 'assertive');
    }
  }

  // -------------------------------------------------------------------------
  // Recalculation (RRV-05)
  // -------------------------------------------------------------------------
  function openRecalculateModal(item: ReReviewBatchRow): void {
    recalculateBatchId.value = (item.re_review_batch as number) ?? null;
    // Reset criteria to defaults
    recalculateCriteria.value = {
      date_range: { start: null, end: null },
      gene_list: [],
      status_filter: null,
      batch_size: 20,
    };
    recalculateModalShow.value = true;
  }

  async function handleBatchRecalculation(): Promise<void> {
    isRecalculating.value = true;
    try {
      const payload: RecalculateBatchRequest = {
        re_review_batch: recalculateBatchId.value as number,
        batch_size: recalculateCriteria.value.batch_size,
      };

      const { start, end } = recalculateCriteria.value.date_range;
      if (start && end) {
        payload.date_range = { start, end };
      }

      if (recalculateCriteria.value.status_filter !== null) {
        payload.status_filter = recalculateCriteria.value.status_filter;
      }

      const responseData = await recalculateReReviewBatch(payload);

      const result = responseData.entry;
      const message =
        result?.batch_id != null && result?.entity_count != null
          ? `Batch ${result.batch_id} recalculated with ${result.entity_count} entities`
          : 'Batch recalculated, but the batch summary was unavailable';
      onToast(message, 'Success', 'success');
      announce(message);
      recalculateModalShow.value = false;
      loadReReviewTableData();
      loadAvailableEntities();
    } catch (e) {
      onToast(errorMessage(e, 'Recalculation failed'), 'Error', 'danger');
      announce('Failed to recalculate batch', 'assertive');
    } finally {
      isRecalculating.value = false;
    }
  }

  return {
    // shared state
    filter,
    userFilter,
    assignmentFilter,
    activeBatchMode,
    loadingReReviewManagment,
    user_options,
    user_id_assignment,
    items_ReReviewTable,
    sortBy,
    currentPage,
    perPage,
    totalRows,
    pageOptions,
    availableEntities,
    availableEntityTotal,
    selectedEntityIds,
    manualEntityFilter,
    entityAssignUserId,
    entityAssignBatchName,
    isLoadingEntities,
    isAssigningEntities,
    previewBoundaryGene,
    previewGeneCount,
    previewEntityCount,
    reassignModalShow,
    reassignBatchId,
    reassignNewUserId,
    recalculateModalShow,
    recalculateBatchId,
    recalculateCriteria,
    isRecalculating,
    status_options,
    // derived
    assignedBatchCount,
    unassignedBatchCount,
    boundaryGeneAlertVisible,
    boundaryGeneAlertMessage,
    userFilterOptions,
    assignmentFilterOptions,
    filteredItems,
    sortedItems,
    paginatedItems,
    // loaders
    loadUserList,
    loadReReviewTableData,
    loadAvailableEntities,
    loadStatusOptions,
    initialize,
    // handlers
    applyFilters,
    handlePageChange,
    handlePerPageChange,
    handleSortUpdate,
    handleNewBatchAssignment,
    handleBatchUnAssignment,
    onBatchCreated,
    toggleEntitySelection,
    clearManualSelection,
    handleEntityAssignment,
    openReassignModal,
    handleBatchReassignment,
    openRecalculateModal,
    handleBatchRecalculation,
  };
}

export type UseManageReReviewReturn = ReturnType<typeof useManageReReview>;

export default useManageReReview;
