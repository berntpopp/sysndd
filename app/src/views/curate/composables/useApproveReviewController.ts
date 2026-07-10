// views/curate/composables/useApproveReviewController.ts
/**
 * Controller composable for `ApproveReview.vue` (Wave 2 Task 8, #346).
 *
 * Owns state, data loading, modal orchestration, submission, reset, and
 * discard-confirmation logic the view previously inlined in its
 * `<script setup>` block; the view stays a thin shell wiring these return
 * values into the template. Behavior-preserving: every reactive name and
 * method returned here is re-exported by the view's `defineExpose` under
 * the exact same name (see the C1 functional spec and the locked
 * `verify the correct approver role appears in the audit trail` handshake
 * in `ApproveReview.spec.ts`).
 *
 * `useReviewApprovalActions` (HTTP plumbing) and `useReviewHelpers` (pure
 * PMID/tree/table helpers) stay untouched, separate composables. The
 * synopsis/comment/category/problematic dirty-state comparisons live in
 * `../utils/reviewApprovalSnapshots` so they are unit-testable standalone.
 */

import { computed, getCurrentInstance, onMounted, reactive, ref, watch } from 'vue';
import type { AxiosInstance } from 'axios';
import { apiClient } from '@/api/client';
import { useToast, useColorAndSymbols, useText, useAriaLive } from '@/composables';
import { useUiStore } from '@/stores/ui';

import type { ReviewInfoShape, EntityInfoShape } from '@/components/review/EditReviewModal.vue';
import type { StatusInfoShape } from '@/components/review/EditStatusModal.vue';

import useApprovalTableData from '@/composables/review/useApprovalTableData';
import {
  fetchReviewDetail,
  fetchStatusDetail,
  fetchEntity,
  approveReview,
  dismissReview,
  approveStatus,
  approveAllReviews,
  submitReviewUpdate,
  submitStatusUpdate,
  submitStatusCreate,
} from '@/composables/review/useReviewApprovalActions';
import {
  sanitizePMID as sanitizeInput,
  tagValidatorPMID,
  transformModifierTree,
  arraysAreEqual,
  reviewTableFields,
  reviewLegendItems,
  type TreeNode,
} from '@/composables/review/useReviewHelpers';
import {
  hasReviewSnapshotChanges,
  hasStatusSnapshotChanges,
  type ReviewLoadedSnapshot,
  type StatusLoadedSnapshot,
} from '../utils/reviewApprovalSnapshots';

import Review from '@/assets/js/classes/submission/submissionReview';
import Status from '@/assets/js/classes/submission/submissionStatus';

export function useApproveReviewController() {
  const { makeToast } = useToast();
  const { stoplights_style, user_style, user_icon } = useColorAndSymbols();
  useText();
  const { message: a11yMessage, politeness: a11yPoliteness, announce } = useAriaLive();
  const uiStore = useUiStore();

  // Lazy injected compatibility: resolve the HTTP client and modal $refs via
  // the live component instance so `this.axios` (Vue Test Utils mocks) wins
  // over the production fallback (`apiClient.raw`, same singleton + 401/
  // Authorization interceptors) during unit tests. `getCurrentInstance()` is
  // valid here because this composable is invoked synchronously from the
  // view's own setup — see the C1 functional spec.
  const instance = getCurrentInstance();
  const getAxios = (): AxiosInstance => {
    const injected = (instance?.proxy as unknown as { axios?: AxiosInstance } | undefined)?.axios;
    return injected ?? (apiClient.raw as unknown as AxiosInstance);
  };
  const showModal = (id: string): void => {
    const handle = (instance?.proxy as unknown as { $refs?: Record<string, unknown> } | undefined)
      ?.$refs?.[id] as { show?: () => void } | undefined;
    handle?.show?.();
  };
  const hideModal = (id: string): void => {
    const handle = (instance?.proxy as unknown as { $refs?: Record<string, unknown> } | undefined)
      ?.$refs?.[id] as { hide?: () => void } | undefined;
    handle?.hide?.();
  };

  // Table data
  const {
    items: items_ReviewTable,
    totalRows,
    currentPage,
    perPage,
    pageOptions,
    sortBy,
    isBusy,
    filters,
    categoryOptions,
    userOptions,
    filteredItems,
  } = useApprovalTableData({
    initialSortBy: [{ key: 'review_user_name', order: 'asc' }],
    initialPerPage: 100,
  });
  const filterText = ref<string | null>(null);
  watch(filteredItems, (list) => {
    totalRows.value = list.length;
  });

  // Flags
  const loadingReviewApprove = ref(true);
  const loading_review_modal = ref(true);
  const loading_status_modal = ref(true);

  const legendItems = reviewLegendItems;
  const fieldsReviewTable = reviewTableFields;

  // Modal descriptors (preserve names the C1 spec expects)
  const approveModal = reactive({ id: 'approve-modal', title: '' });
  const reviewModal = reactive({ id: 'review-modal', title: '' });
  const dismissModal = reactive({
    id: 'dismiss-modal',
    title: '',
    reviewId: null as number | null,
  });
  const statusModal = reactive({ id: 'status-modal', title: '' });

  // Domain state
  const phenotypes_options = ref<TreeNode[]>([]);
  const variation_ontology_options = ref<TreeNode[]>([]);
  const status_options = ref<Array<{ id: number | string; label: string }>>([]);

  const initialEntityInfo: EntityInfoShape = {
    entity_id: 0,
    symbol: '',
    hgnc_id: '',
    disease_ontology_id_version: '',
    disease_ontology_name: '',
    hpo_mode_of_inheritance_term_name: '',
    hpo_mode_of_inheritance_term: '',
  };

  const entity = ref<Record<string, unknown>>({});
  const entity_info = ref<EntityInfoShape>({ ...initialEntityInfo });
  const review_info = ref<ReviewInfoShape>(new Review() as unknown as ReviewInfoShape);
  const status_info = ref<StatusInfoShape>(new Status() as unknown as StatusInfoShape);
  const select_phenotype = ref<string[]>([]);
  const select_variation = ref<string[]>([]);
  const select_additional_references = ref<string[]>([]);
  const select_gene_reviews = ref<string[]>([]);
  const approve_all_selected = ref(false);
  const status_approved = ref(false);
  const pendingDiscardTarget = ref<'review' | 'status' | null>(null);

  const reviewLoadedData = ref<ReviewLoadedSnapshot | null>(null);
  const statusLoadedData = ref<StatusLoadedSnapshot | null>(null);
  const confirmDiscardDialog = ref<{ show: () => void; hide: () => void } | null>(null);

  // Computed
  const hasReviewChanges = computed<boolean>(() =>
    hasReviewSnapshotChanges(
      {
        synopsis: review_info.value.synopsis,
        comment: review_info.value.comment,
        phenotypes: select_phenotype.value,
        variationOntology: select_variation.value,
        publications: select_additional_references.value,
        genereviews: select_gene_reviews.value,
      },
      reviewLoadedData.value
    )
  );
  const hasStatusChanges = computed<boolean>(() =>
    hasStatusSnapshotChanges(
      {
        category_id: status_info.value.category_id,
        comment: status_info.value.comment,
        problematic: status_info.value.problematic,
      },
      statusLoadedData.value
    )
  );

  // Watchers (PMID sanitization on free-text tag inputs)
  watch(
    select_additional_references,
    (val) => {
      const sanitized = val.map(sanitizeInput);
      if (!arraysAreEqual(val, sanitized)) select_additional_references.value = sanitized;
    },
    { deep: true }
  );
  watch(
    select_gene_reviews,
    (val) => {
      const sanitized = val.map(sanitizeInput);
      if (!arraysAreEqual(val, sanitized)) select_gene_reviews.value = sanitized;
    },
    { deep: true }
  );

  // Data loaders (HTTP surface lives in useReviewApprovalActions for E6 reuse)
  async function loadStatusList(): Promise<void> {
    try {
      const r = await getAxios().get(`${import.meta.env.VITE_API_URL}/api/list/status?tree=true`);
      status_options.value = r.data;
    } catch (e) {
      makeToast(e, 'Error', 'danger');
    }
  }
  async function loadPhenotypesList(): Promise<void> {
    try {
      const r = await getAxios().get(
        `${import.meta.env.VITE_API_URL}/api/list/phenotype?tree=true`
      );
      const raw = Array.isArray(r.data) ? r.data : r.data?.data || [];
      phenotypes_options.value = transformModifierTree(raw);
    } catch (e) {
      makeToast(e, 'Error', 'danger');
      phenotypes_options.value = [];
    }
  }
  async function loadVariationOntologyList(): Promise<void> {
    try {
      const r = await getAxios().get(
        `${import.meta.env.VITE_API_URL}/api/list/variation_ontology?tree=true`
      );
      const raw = Array.isArray(r.data) ? r.data : r.data?.data || [];
      variation_ontology_options.value = transformModifierTree(raw);
    } catch (e) {
      makeToast(e, 'Error', 'danger');
      variation_ontology_options.value = [];
    }
  }
  async function loadReviewTableData(): Promise<void> {
    isBusy.value = true;
    try {
      // v11.0 closeout F2a: the inline Authorization header construction
      // here has been removed. The `apiClient` request interceptor
      // (`@/api/client`) reads `useAuth().token.value` and injects the
      // Bearer header on every outbound call against the shared axios
      // singleton. `getAxios()` resolves to either the `this.axios` test
      // proxy or the singleton, both of which flow through the interceptor.
      const r = await getAxios().get(`${import.meta.env.VITE_API_URL}/api/review`);
      items_ReviewTable.value = r.data;
      totalRows.value = r.data.length;
    } catch (e) {
      makeToast(e, 'Error', 'danger');
    } finally {
      uiStore.requestScrollbarUpdate();
      isBusy.value = false;
      loadingReviewApprove.value = false;
    }
  }

  async function loadReviewInfo(review_id: number): Promise<void> {
    loading_review_modal.value = true;
    try {
      const loaded = await fetchReviewDetail(getAxios(), review_id);
      review_info.value = loaded.reviewInfo as ReviewInfoShape;
      select_phenotype.value = loaded.selectPhenotype;
      select_variation.value = loaded.selectVariation;
      select_additional_references.value = loaded.selectAdditionalReferences;
      select_gene_reviews.value = loaded.selectGeneReviews;
      reviewLoadedData.value = loaded.snapshot;
      loading_review_modal.value = false;
    } catch (e) {
      makeToast(e, 'Error', 'danger');
    }
  }

  async function loadStatusInfo(status_id: number): Promise<void> {
    loading_status_modal.value = true;
    try {
      const loaded = await fetchStatusDetail(getAxios(), status_id);
      status_info.value = loaded.statusInfo as StatusInfoShape;
      statusLoadedData.value = loaded.snapshot;
      loading_status_modal.value = false;
    } catch (e) {
      makeToast(e, 'Error', 'danger');
    }
  }

  async function getEntity(entity_id: number): Promise<void> {
    try {
      const row = await fetchEntity(getAxios(), entity_id);
      if (row) entity_info.value = row as EntityInfoShape;
    } catch (e) {
      makeToast(e, 'Error', 'danger');
    }
  }

  // Modal openers
  function infoReview(
    item: Record<string, unknown> & { entity_id?: number; review_id?: number }
  ): void {
    reviewModal.title = `sysndd:${item.entity_id}`;
    if (item.entity_id != null) getEntity(item.entity_id);
    if (item.review_id != null) loadReviewInfo(item.review_id);
    showModal(reviewModal.id);
  }
  function infoApproveReview(item: Record<string, unknown>): void {
    approveModal.title = `sysndd:${item.entity_id}`;
    entity.value = {};
    entity.value = item;
    showModal(approveModal.id);
  }
  function infoDismissReview(
    item: Record<string, unknown> & { entity_id?: number; review_id?: number }
  ): void {
    dismissModal.title = `sysndd:${item.entity_id}`;
    dismissModal.reviewId = item.review_id ?? null;
    showModal(dismissModal.id);
  }
  function infoStatus(
    item: Record<string, unknown> & { entity_id?: number; newest_status?: number }
  ): void {
    statusModal.title = `sysndd:${item.entity_id}`;
    if (item.entity_id != null) getEntity(item.entity_id);
    if (item.newest_status != null) loadStatusInfo(item.newest_status);
    showModal(statusModal.id);
  }
  function checkAllApprove(): void {
    showModal('approveAllModal');
  }

  // Submissions (endpoint HTTP in useReviewApprovalActions; the controller
  // composes the reactive snapshot, fires the action, then resyncs).
  async function submitReviewChange(): Promise<void> {
    if (!hasReviewChanges.value) {
      hideModal(reviewModal.id);
      return;
    }
    isBusy.value = true;
    try {
      await submitReviewUpdate(getAxios(), {
        reviewInfo: review_info.value,
        selectPhenotype: select_phenotype.value,
        selectVariation: select_variation.value,
        selectAdditionalReferences: select_additional_references.value,
        selectGeneReviews: select_gene_reviews.value,
        sanitize: sanitizeInput,
      });
      const message = 'The new review for this entity has been submitted successfully.';
      makeToast(message, 'Success', 'success');
      announce(message);
      resetForm();
      loadReviewTableData();
    } catch (e) {
      makeToast(e, 'Error', 'danger');
    } finally {
      isBusy.value = false;
    }
  }

  async function submitStatusChange(): Promise<void> {
    if (!hasStatusChanges.value) {
      hideModal(statusModal.id);
      return;
    }
    isBusy.value = true;
    try {
      if (status_info.value.status_approved === 0) {
        status_info.value.status_user_name = null;
        status_info.value.status_user_role = null;
        status_info.value.entity_id = null;
        status_info.value.status_approved = null;
        try {
          const r = await submitStatusUpdate(getAxios(), status_info.value);
          makeToast(
            `The new status for this entity has been submitted (status ${r.status} (${r.statusText}).`,
            'Success',
            'success'
          );
          resetForm();
          loadReviewTableData();
        } catch (e) {
          makeToast(e, 'Error', 'danger');
          announce('Error submitting status', 'assertive');
        }
      } else if (status_info.value.status_approved === 1) {
        status_info.value.status_user_name = null;
        status_info.value.status_user_role = null;
        status_info.value.status_approved = null;
        try {
          await submitStatusCreate(getAxios(), status_info.value);
          const message = 'The new status for this entity has been submitted successfully.';
          makeToast(message, 'Success', 'success');
          announce(message);
          resetForm();
          loadReviewTableData();
        } catch (e) {
          makeToast(e, 'Error', 'danger');
          announce('Error submitting status', 'assertive');
        }
      }
    } finally {
      isBusy.value = false;
    }
  }

  async function handleDismissOk(): Promise<void> {
    try {
      await dismissReview(getAxios(), dismissModal.reviewId ?? undefined);
      announce('Review dismissed successfully');
      loadReviewTableData();
    } catch (e) {
      makeToast(e, 'Error', 'danger');
      announce('Error dismissing review', 'assertive');
    }
  }
  async function handleApproveOk(): Promise<void> {
    const reviewId = (entity.value as { review_id?: number }).review_id;
    try {
      await approveReview(getAxios(), reviewId);
      announce('Review approved successfully');
    } catch (e) {
      makeToast(e, 'Error', 'danger');
      announce('Error approving review', 'assertive');
    }
    if (
      status_approved.value === true &&
      (entity.value as { status_change?: number }).status_change === 1
    ) {
      const newestStatus = (entity.value as { newest_status?: number }).newest_status;
      try {
        await approveStatus(getAxios(), newestStatus);
        announce('Status also approved');
      } catch (e) {
        makeToast(e, 'Error', 'danger');
        announce('Error approving status', 'assertive');
      }
    }
    resetApproveModal();
    loadReviewTableData();
  }
  async function handleAllReviewsOk(): Promise<void> {
    if (!approve_all_selected.value) return;
    try {
      await approveAllReviews(getAxios());
      loadReviewTableData();
    } catch (e) {
      makeToast(e, 'Error', 'danger');
    }
  }

  // Resets + modal hide confirm
  function resetForm(): void {
    entity_info.value = { ...initialEntityInfo };
    review_info.value = new Review() as unknown as ReviewInfoShape;
    select_phenotype.value = [];
    select_variation.value = [];
    select_additional_references.value = [];
    select_gene_reviews.value = [];
    statusLoadedData.value = null;
    reviewLoadedData.value = null;
  }
  function resetApproveModal(): void {
    status_approved.value = false;
  }

  interface ModalHideEvent {
    preventDefault: () => void;
  }
  function onStatusModalHide(event: ModalHideEvent): void {
    if (pendingDiscardTarget.value === 'status') {
      pendingDiscardTarget.value = null;
      return;
    }
    if (hasStatusChanges.value && !isBusy.value) {
      event.preventDefault();
      pendingDiscardTarget.value = 'status';
      confirmDiscardDialog.value?.show();
    }
  }
  function onReviewModalHide(event: ModalHideEvent): void {
    if (pendingDiscardTarget.value === 'review') {
      pendingDiscardTarget.value = null;
      return;
    }
    if (hasReviewChanges.value && !isBusy.value) {
      event.preventDefault();
      pendingDiscardTarget.value = 'review';
      confirmDiscardDialog.value?.show();
    }
  }
  function onConfirmDiscard(): void {
    if (pendingDiscardTarget.value === 'review') hideModal(reviewModal.id);
    else if (pendingDiscardTarget.value === 'status') hideModal(statusModal.id);
  }
  function onFiltered(filteredList: unknown[]): void {
    totalRows.value = filteredList.length;
    currentPage.value = 1;
  }

  onMounted(() => {
    loadStatusList();
    loadPhenotypesList();
    loadVariationOntologyList();
    loadReviewTableData();
  });

  return {
    // color/symbols + a11y passthroughs the template binds directly
    stoplights_style,
    user_style,
    user_icon,
    a11yMessage,
    a11yPoliteness,

    // table data
    items_ReviewTable,
    totalRows,
    currentPage,
    perPage,
    pageOptions,
    sortBy,
    isBusy,
    filters,
    categoryOptions,
    userOptions,
    filteredItems,
    filterText,

    // flags
    loadingReviewApprove,
    loading_review_modal,
    loading_status_modal,

    // static table config
    legendItems,
    fieldsReviewTable,

    // modal descriptors
    approveModal,
    reviewModal,
    dismissModal,
    statusModal,
    confirmDiscardDialog,

    // domain state
    phenotypes_options,
    variation_ontology_options,
    status_options,
    entity,
    entity_info,
    review_info,
    status_info,
    select_phenotype,
    select_variation,
    select_additional_references,
    select_gene_reviews,
    approve_all_selected,
    status_approved,
    pendingDiscardTarget,
    reviewLoadedData,
    statusLoadedData,
    hasReviewChanges,
    hasStatusChanges,

    // loaders
    loadReviewTableData,
    loadReviewInfo,
    loadStatusInfo,

    // submissions
    submitReviewChange,
    submitStatusChange,
    handleApproveOk,
    handleDismissOk,
    handleAllReviewsOk,

    // modal openers
    infoReview,
    infoStatus,
    infoApproveReview,
    infoDismissReview,
    checkAllApprove,

    // resets + discard
    resetForm,
    resetApproveModal,
    onReviewModalHide,
    onStatusModalHide,
    onConfirmDiscard,
    onFiltered,

    // pure helpers re-exposed for the C1 spec contract
    tagValidatorPMID,
    sanitizeInput,
  };
}

export default useApproveReviewController;
