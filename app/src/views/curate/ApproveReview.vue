<!-- views/curate/ApproveReview.vue -->
<!--
  ApproveReview.vue (Phase E.E5 rewrite — script setup + TypeScript).

  This view is the orchestrator. All presentational pieces have been lifted
  into `@/components/review/*` and the table state into
  `@/composables/review/useApprovalTableData` so that Phase E.E6 can repackage
  them behind a generic `ApprovalTableView` wrapper without rewriting.

  The protecting spec is `ApproveReview.spec.ts` (Phase C.C1 safety-net).
  Contract the rewrite preserves (see `defineExpose` at the bottom):
    - `items_ReviewTable`, `totalRows`, `reviewLoadedData`, `hasReviewChanges`
      remain reactive and exposed on the instance.
    - `infoApproveReview`, `handleApproveOk`, `submitReviewChange` remain
      callable via `wrapper.vm.<method>()`.
    - All HTTP calls go through `this.axios` (the `getAxios()` proxy bridge)
      so the spec's `routedAxios` mock intercepts them.
-->
<template>
  <div class="container-fluid">
    <BContainer fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol col md="12">
          <ReviewTable
            title="Approve Reviews"
            :items="filteredItems"
            :fields="fieldsReviewTable"
            :total-rows="totalRows"
            :current-page="currentPage"
            :per-page="perPage"
            :page-options="pageOptions"
            :sort-by="sortBy"
            :filter-text="filterText"
            :category-filter="filters.category.value"
            :user-filter="filters.user.value"
            :date-start="filters.dateStart.value"
            :date-end="filters.dateEnd.value"
            :category-options="categoryOptions"
            :user-options="userOptions"
            :legend-items="legendItems"
            :is-busy="isBusy"
            :loading="loadingReviewApprove"
            @approve-all="checkAllApprove"
            @refresh="loadReviewTableData"
            @update:current-page="currentPage = $event"
            @update:per-page="perPage = $event"
            @update:sort-by="sortBy = $event"
            @update:filter-text="filterText = $event"
            @update:category-filter="filters.category.value = $event"
            @update:user-filter="filters.user.value = $event"
            @update:date-start="filters.dateStart.value = $event"
            @update:date-end="filters.dateEnd.value = $event"
            @filtered="onFiltered"
          >
            <template #cell(entity_id)="data">
              <EntityBadge
                :entity-id="data.item.entity_id"
                :link-to="'/Entities/' + data.item.entity_id"
                size="sm"
              />
            </template>
            <template #cell(symbol)="data">
              <GeneBadge
                :symbol="data.item.symbol"
                :hgnc-id="data.item.hgnc_id"
                :link-to="'/Genes/' + data.item.hgnc_id"
                size="sm"
              />
            </template>
            <template #cell(disease_ontology_name)="data">
              <DiseaseBadge
                :name="data.item.disease_ontology_name"
                :ontology-id="data.item.disease_ontology_id_version"
                :link-to="
                  '/Ontology/' + data.item.disease_ontology_id_version.replace(/_.+/g, '')
                "
                :max-length="35"
                size="sm"
              />
            </template>
            <template #cell(hpo_mode_of_inheritance_term_name)="data">
              <InheritanceBadge
                :full-name="data.item.hpo_mode_of_inheritance_term_name"
                :hpo-term="data.item.hpo_mode_of_inheritance_term"
                size="sm"
              />
            </template>
            <template #cell(synopsis)="data">
              <ReviewRowCells
                kind="text-popover"
                :text="data.item.synopsis"
                title="Clinical Synopsis"
                icon-class="bi-file-text"
                :target-id="'synopsis-' + data.item.entity_id"
                :max-width="200"
              />
            </template>
            <template #cell(comment)="data">
              <ReviewRowCells
                kind="text-popover"
                :text="data.item.comment"
                title="Comment"
                icon-class="bi-chat-left-text"
                :target-id="'comment-' + data.item.entity_id"
                :max-width="150"
              />
            </template>
            <template #cell(review_date)="data">
              <ReviewRowCells kind="review-date" :text="data.item.review_date" />
            </template>
            <template #cell(review_user_name)="data">
              <ReviewRowCells
                kind="review-user"
                :text="data.item.review_user_name"
                :role-key="data.item.review_user_role"
                :user-style="user_style"
                :user-icon="user_icon"
              />
            </template>
            <template #cell(actions)="row">
              <ReviewRowActions
                :item="row.item"
                :expansion-showing="row.expansionShowing"
                :toggle-expansion="row.toggleExpansion"
                :stoplights-style="stoplights_style"
                @edit-review="infoReview"
                @edit-status="infoStatus"
                @approve="infoApproveReview"
                @dismiss="infoDismissReview"
              />
            </template>
            <template #row-expansion="row">
              <ReviewRowExpansion :item="row.item" />
            </template>
          </ReviewTable>
        </BCol>
      </BRow>

      <ApproveReviewModal
        :ref="approveModal.id"
        :modal-id="approveModal.id"
        :entity-title="approveModal.title"
        :is-duplicate="entity.duplicate === 'yes'"
        :has-status-change="Boolean(entity.status_change)"
        :status-approved="status_approved"
        @ok="handleApproveOk"
        @update:status-approved="status_approved = $event"
      />

      <EditReviewModal
        :ref="reviewModal.id"
        :modal-id="reviewModal.id"
        :loading="loading_review_modal"
        :review-info="review_info"
        :entity-info="entity_info"
        :phenotype-options="phenotypes_options"
        :variation-options="variation_ontology_options"
        :select-phenotype="select_phenotype"
        :select-variation="select_variation"
        :select-additional-references="select_additional_references"
        :select-gene-reviews="select_gene_reviews"
        :user-icon="user_icon"
        :tag-validator="tagValidatorPMID"
        @ok="submitReviewChange"
        @hide="onReviewModalHide"
        @update:review-info="review_info = $event"
        @update:select-phenotype="select_phenotype = $event"
        @update:select-variation="select_variation = $event"
        @update:select-additional-references="select_additional_references = $event"
        @update:select-gene-reviews="select_gene_reviews = $event"
      />

      <EditStatusModal
        :ref="statusModal.id"
        :modal-id="statusModal.id"
        :loading="loading_status_modal"
        :status-info="status_info"
        :entity-info="entity_info"
        :status-options="status_options"
        :user-icon="user_icon"
        @ok="submitStatusChange"
        @hide="onStatusModalHide"
        @update:status-info="status_info = $event"
      />

      <DismissReviewModal
        :ref="dismissModal.id"
        :modal-id="dismissModal.id"
        :entity-title="dismissModal.title"
        @ok="handleDismissOk"
      />

      <ApproveAllModal
        ref="approveAllModal"
        modal-id="approveAllModal"
        :total-rows="totalRows"
        :selected="approve_all_selected"
        @ok="handleAllReviewsOk"
        @update:selected="approve_all_selected = $event"
      />

      <AriaLiveRegion :message="a11yMessage" :politeness="a11yPoliteness" />

      <ConfirmDiscardDialog
        ref="confirmDiscardDialog"
        modal-id="approve-review-confirm-discard"
        @discard="onConfirmDiscard"
        @keep-editing="pendingDiscardTarget = null"
      />
    </BContainer>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, reactive, watch, getCurrentInstance } from 'vue';
import axios from 'axios';
import { useToast, useColorAndSymbols, useText, useAriaLive } from '@/composables';
import { useUiStore } from '@/stores/ui';

import AriaLiveRegion from '@/components/accessibility/AriaLiveRegion.vue';
import EntityBadge from '@/components/ui/EntityBadge.vue';
import GeneBadge from '@/components/ui/GeneBadge.vue';
import DiseaseBadge from '@/components/ui/DiseaseBadge.vue';
import InheritanceBadge from '@/components/ui/InheritanceBadge.vue';
import ConfirmDiscardDialog from '@/components/ui/ConfirmDiscardDialog.vue';

import ReviewTable from '@/components/review/ReviewTable.vue';
import ReviewRowActions from '@/components/review/ReviewRowActions.vue';
import ReviewRowCells from '@/components/review/ReviewRowCells.vue';
import ReviewRowExpansion from '@/components/review/ReviewRowExpansion.vue';
import ApproveReviewModal from '@/components/review/ApproveReviewModal.vue';
import EditReviewModal, {
  type ReviewInfoShape,
  type EntityInfoShape,
} from '@/components/review/EditReviewModal.vue';
import EditStatusModal, {
  type StatusInfoShape,
} from '@/components/review/EditStatusModal.vue';
import DismissReviewModal from '@/components/review/DismissReviewModal.vue';
import ApproveAllModal from '@/components/review/ApproveAllModal.vue';

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

import Review from '@/assets/js/classes/submission/submissionReview';
import Status from '@/assets/js/classes/submission/submissionStatus';

// ---------------------------------------------------------------------------
// Composables
// ---------------------------------------------------------------------------
const { makeToast } = useToast();
const { stoplights_style, user_style, user_icon } = useColorAndSymbols();
useText();
const { message: a11yMessage, politeness: a11yPoliteness, announce } = useAriaLive();
const uiStore = useUiStore();

// Resolve axios lazily so `this.axios` (Vue Test Utils mocks) wins over the
// module import during unit tests. See C1 spec contract.
const instance = getCurrentInstance();
const getAxios = () => {
  const injected = (instance?.proxy as unknown as { axios?: typeof axios } | undefined)?.axios;
  return injected ?? axios;
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
watch(filteredItems, (list) => { totalRows.value = list.length; });

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

interface ReviewLoadedSnapshot {
  synopsis: string; comment: string;
  phenotypes: string[]; variationOntology: string[];
  publications: string[]; genereviews: string[];
}
interface StatusLoadedSnapshot {
  category_id: number | null; comment: string; problematic: boolean;
}
const reviewLoadedData = ref<ReviewLoadedSnapshot | null>(null);
const statusLoadedData = ref<StatusLoadedSnapshot | null>(null);
const confirmDiscardDialog = ref<{ show: () => void; hide: () => void } | null>(null);

// ---------------------------------------------------------------------------
// Computed
// ---------------------------------------------------------------------------
const hasReviewChanges = computed<boolean>(() => {
  if (!reviewLoadedData.value) return false;
  const s = reviewLoadedData.value;
  return (
    (review_info.value.synopsis || '') !== s.synopsis ||
    (review_info.value.comment || '') !== s.comment ||
    !arraysAreEqual([...select_phenotype.value].sort(), [...s.phenotypes].sort()) ||
    !arraysAreEqual([...select_variation.value].sort(), [...s.variationOntology].sort()) ||
    !arraysAreEqual(
      [...select_additional_references.value].sort(),
      [...s.publications].sort()
    ) ||
    !arraysAreEqual([...select_gene_reviews.value].sort(), [...s.genereviews].sort())
  );
});
const hasStatusChanges = computed<boolean>(() => {
  if (!statusLoadedData.value) return false;
  const s = statusLoadedData.value;
  return (
    status_info.value.category_id !== s.category_id ||
    (status_info.value.comment || '') !== s.comment ||
    Boolean(status_info.value.problematic) !== s.problematic
  );
});

// ---------------------------------------------------------------------------
// Watchers (PMID sanitization on free-text tag inputs)
// ---------------------------------------------------------------------------
watch(select_additional_references, (val) => {
  const sanitized = val.map(sanitizeInput);
  if (!arraysAreEqual(val, sanitized)) select_additional_references.value = sanitized;
}, { deep: true });
watch(select_gene_reviews, (val) => {
  const sanitized = val.map(sanitizeInput);
  if (!arraysAreEqual(val, sanitized)) select_gene_reviews.value = sanitized;
}, { deep: true });

// ---------------------------------------------------------------------------
// Data loaders (HTTP surface lives in useReviewApprovalActions for E6 reuse)
// ---------------------------------------------------------------------------
async function loadStatusList(): Promise<void> {
  try {
    const r = await getAxios().get(`${import.meta.env.VITE_API_URL}/api/list/status?tree=true`);
    status_options.value = r.data;
  } catch (e) { makeToast(e, 'Error', 'danger'); }
}
async function loadPhenotypesList(): Promise<void> {
  try {
    const r = await getAxios().get(`${import.meta.env.VITE_API_URL}/api/list/phenotype?tree=true`);
    const raw = Array.isArray(r.data) ? r.data : r.data?.data || [];
    phenotypes_options.value = transformModifierTree(raw);
  } catch (e) { makeToast(e, 'Error', 'danger'); phenotypes_options.value = []; }
}
async function loadVariationOntologyList(): Promise<void> {
  try {
    const r = await getAxios().get(`${import.meta.env.VITE_API_URL}/api/list/variation_ontology?tree=true`);
    const raw = Array.isArray(r.data) ? r.data : r.data?.data || [];
    variation_ontology_options.value = transformModifierTree(raw);
  } catch (e) { makeToast(e, 'Error', 'danger'); variation_ontology_options.value = []; }
}
async function loadReviewTableData(): Promise<void> {
  isBusy.value = true;
  try {
    const r = await getAxios().get(`${import.meta.env.VITE_API_URL}/api/review`, {
      headers: { Authorization: `Bearer ${localStorage.getItem('token')}` },
    });
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
  } catch (e) { makeToast(e, 'Error', 'danger'); }
}

async function loadStatusInfo(status_id: number): Promise<void> {
  loading_status_modal.value = true;
  try {
    const loaded = await fetchStatusDetail(getAxios(), status_id);
    status_info.value = loaded.statusInfo as StatusInfoShape;
    statusLoadedData.value = loaded.snapshot;
    loading_status_modal.value = false;
  } catch (e) { makeToast(e, 'Error', 'danger'); }
}

async function getEntity(entity_id: number): Promise<void> {
  try {
    const row = await fetchEntity(getAxios(), entity_id);
    if (row) entity_info.value = row as EntityInfoShape;
  } catch (e) { makeToast(e, 'Error', 'danger'); }
}

// ---------------------------------------------------------------------------
// Modal openers
// ---------------------------------------------------------------------------
function infoReview(item: Record<string, unknown> & { entity_id?: number; review_id?: number }): void {
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
function infoDismissReview(item: Record<string, unknown> & { entity_id?: number; review_id?: number }): void {
  dismissModal.title = `sysndd:${item.entity_id}`;
  dismissModal.reviewId = item.review_id ?? null;
  showModal(dismissModal.id);
}
function infoStatus(item: Record<string, unknown> & { entity_id?: number; newest_status?: number }): void {
  statusModal.title = `sysndd:${item.entity_id}`;
  if (item.entity_id != null) getEntity(item.entity_id);
  if (item.newest_status != null) loadStatusInfo(item.newest_status);
  showModal(statusModal.id);
}
function checkAllApprove(): void { showModal('approveAllModal'); }

// ---------------------------------------------------------------------------
// Submissions (endpoint HTTP in useReviewApprovalActions; the view composes
// the reactive snapshot, fires the action, then resyncs.)
// ---------------------------------------------------------------------------
async function submitReviewChange(): Promise<void> {
  if (!hasReviewChanges.value) { hideModal(reviewModal.id); return; }
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
  } catch (e) { makeToast(e, 'Error', 'danger'); }
  finally { isBusy.value = false; }
}

async function submitStatusChange(): Promise<void> {
  if (!hasStatusChanges.value) { hideModal(statusModal.id); return; }
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
          'Success', 'success'
        );
        resetForm(); loadReviewTableData();
      } catch (e) { makeToast(e, 'Error', 'danger'); announce('Error submitting status', 'assertive'); }
    } else if (status_info.value.status_approved === 1) {
      status_info.value.status_user_name = null;
      status_info.value.status_user_role = null;
      status_info.value.status_approved = null;
      try {
        await submitStatusCreate(getAxios(), status_info.value);
        const message = 'The new status for this entity has been submitted successfully.';
        makeToast(message, 'Success', 'success');
        announce(message);
        resetForm(); loadReviewTableData();
      } catch (e) { makeToast(e, 'Error', 'danger'); announce('Error submitting status', 'assertive'); }
    }
  } finally { isBusy.value = false; }
}

async function handleDismissOk(): Promise<void> {
  try {
    await dismissReview(getAxios(), dismissModal.reviewId ?? undefined);
    announce('Review dismissed successfully');
    loadReviewTableData();
  } catch (e) { makeToast(e, 'Error', 'danger'); announce('Error dismissing review', 'assertive'); }
}
async function handleApproveOk(): Promise<void> {
  const reviewId = (entity.value as { review_id?: number }).review_id;
  try {
    await approveReview(getAxios(), reviewId);
    announce('Review approved successfully');
  } catch (e) { makeToast(e, 'Error', 'danger'); announce('Error approving review', 'assertive'); }
  if (status_approved.value === true && (entity.value as { status_change?: number }).status_change === 1) {
    const newestStatus = (entity.value as { newest_status?: number }).newest_status;
    try {
      await approveStatus(getAxios(), newestStatus);
      announce('Status also approved');
    } catch (e) { makeToast(e, 'Error', 'danger'); announce('Error approving status', 'assertive'); }
  }
  resetApproveModal();
  loadReviewTableData();
}
async function handleAllReviewsOk(): Promise<void> {
  if (!approve_all_selected.value) return;
  try { await approveAllReviews(getAxios()); loadReviewTableData(); }
  catch (e) { makeToast(e, 'Error', 'danger'); }
}

// ---------------------------------------------------------------------------
// Resets + modal hide confirm
// ---------------------------------------------------------------------------
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
function resetApproveModal(): void { status_approved.value = false; }

interface ModalHideEvent { preventDefault: () => void }
function onStatusModalHide(event: ModalHideEvent): void {
  if (pendingDiscardTarget.value === 'status') { pendingDiscardTarget.value = null; return; }
  if (hasStatusChanges.value && !isBusy.value) {
    event.preventDefault();
    pendingDiscardTarget.value = 'status';
    confirmDiscardDialog.value?.show();
  }
}
function onReviewModalHide(event: ModalHideEvent): void {
  if (pendingDiscardTarget.value === 'review') { pendingDiscardTarget.value = null; return; }
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

// ---------------------------------------------------------------------------
// defineExpose — the C1 spec drives state/methods through wrapper.vm.
// Every name here is part of the documented contract; do not rename.
// ---------------------------------------------------------------------------
defineExpose({
  items_ReviewTable, totalRows, currentPage, perPage, sortBy,
  entity, entity_info, review_info, status_info,
  select_phenotype, select_variation, select_additional_references, select_gene_reviews,
  status_approved, approve_all_selected,
  reviewLoadedData, statusLoadedData,
  hasReviewChanges, hasStatusChanges,
  loadReviewTableData, loadReviewInfo, loadStatusInfo,
  submitReviewChange, submitStatusChange,
  handleApproveOk, handleDismissOk, handleAllReviewsOk,
  infoReview, infoStatus, infoApproveReview, infoDismissReview,
  checkAllApprove, resetForm, resetApproveModal,
  onReviewModalHide, onStatusModalHide, onConfirmDiscard, onFiltered,
  tagValidatorPMID, sanitizeInput,
});
</script>

<style scoped>
.text-truncate-multiline {
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  text-overflow: ellipsis;
  line-height: 1.4;
}
.text-popover-trigger { cursor: help; border-bottom: 1px dotted #6c757d; }
.text-popover-trigger:hover {
  background-color: rgba(0, 123, 255, 0.05);
  border-radius: 2px;
}
</style>

<style>
.wide-popover { max-width: 400px !important; }
.wide-popover .popover-header {
  font-size: 0.85rem; font-weight: 600;
  background-color: #f8f9fa; border-bottom: 1px solid #e9ecef;
}
.wide-popover .popover-body {
  max-height: 250px; overflow-y: auto;
  font-size: 0.85rem; line-height: 1.5;
}
.popover-text-content { white-space: pre-wrap; word-break: break-word; }
</style>
