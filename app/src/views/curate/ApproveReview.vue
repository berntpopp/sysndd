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
  <AuthenticatedPageShell
    title="Approve Reviews"
    content-class="authenticated-route-content"
    full-width
  >
    <div class="container-fluid">
      <BContainer fluid>
        <BRow class="justify-content-md-center py-2">
          <BCol col md="12">
            <ReviewTable
              title="Review Queue"
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
              <template #mobile-rows="{ items }">
                <ApprovalMobileRows
                  :items="items"
                  user-field="review_user_name"
                  role-field="review_user_role"
                  date-field="review_date"
                  show-status-edit
                  @edit="infoReview"
                  @edit-status="infoStatus"
                  @approve="infoApproveReview"
                  @dismiss="infoDismissReview"
                />
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
  </AuthenticatedPageShell>
</template>

<script setup lang="ts">
import AuthenticatedPageShell from '@/components/layout/AuthenticatedPageShell.vue';

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
import ApprovalMobileRows from './components/ApprovalMobileRows.vue';
import ApproveReviewModal from '@/components/review/ApproveReviewModal.vue';
import EditReviewModal from '@/components/review/EditReviewModal.vue';
import EditStatusModal from '@/components/review/EditStatusModal.vue';
import DismissReviewModal from '@/components/review/DismissReviewModal.vue';
import ApproveAllModal from '@/components/review/ApproveAllModal.vue';

import { useApproveReviewController } from './composables/useApproveReviewController';

// ---------------------------------------------------------------------------
// Controller (Wave 2 Task 8, #346): owns state/load/modal/submission/reset/
// discard orchestration so this view stays a thin template-wiring shell.
// Every name destructured below is part of the C1 spec's documented
// `defineExpose` contract (see `useApproveReviewController.ts`) — do not
// rename.
// ---------------------------------------------------------------------------
const {
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
  loadingReviewApprove,
  loading_review_modal,
  loading_status_modal,
  legendItems,
  fieldsReviewTable,
  approveModal,
  reviewModal,
  dismissModal,
  statusModal,
  confirmDiscardDialog,
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
  loadReviewTableData,
  loadReviewInfo,
  loadStatusInfo,
  submitReviewChange,
  submitStatusChange,
  handleApproveOk,
  handleDismissOk,
  handleAllReviewsOk,
  infoReview,
  infoStatus,
  infoApproveReview,
  infoDismissReview,
  checkAllApprove,
  resetForm,
  resetApproveModal,
  onReviewModalHide,
  onStatusModalHide,
  onConfirmDiscard,
  onFiltered,
  tagValidatorPMID,
  sanitizeInput,
  stoplights_style,
  user_style,
  user_icon,
  a11yMessage,
  a11yPoliteness,
} = useApproveReviewController();

// ---------------------------------------------------------------------------
// defineExpose — the C1 spec drives state/methods through wrapper.vm.
// Every name here is part of the documented contract; do not rename.
// ---------------------------------------------------------------------------
defineExpose({
  items_ReviewTable,
  totalRows,
  currentPage,
  perPage,
  sortBy,
  entity,
  entity_info,
  review_info,
  status_info,
  select_phenotype,
  select_variation,
  select_additional_references,
  select_gene_reviews,
  status_approved,
  approve_all_selected,
  reviewLoadedData,
  statusLoadedData,
  hasReviewChanges,
  hasStatusChanges,
  loadReviewTableData,
  loadReviewInfo,
  loadStatusInfo,
  submitReviewChange,
  submitStatusChange,
  handleApproveOk,
  handleDismissOk,
  handleAllReviewsOk,
  infoReview,
  infoStatus,
  infoApproveReview,
  infoDismissReview,
  checkAllApprove,
  resetForm,
  resetApproveModal,
  onReviewModalHide,
  onStatusModalHide,
  onConfirmDiscard,
  onFiltered,
  tagValidatorPMID,
  sanitizeInput,
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
.text-popover-trigger {
  cursor: help;
  border-bottom: 1px dotted #6c757d;
}
.text-popover-trigger:hover {
  background-color: rgba(0, 123, 255, 0.05);
  border-radius: 2px;
}
</style>

<style>
.wide-popover {
  max-width: 400px !important;
}
.wide-popover .popover-header {
  font-size: 0.85rem;
  font-weight: 600;
  background-color: #f8f9fa;
  border-bottom: 1px solid #e9ecef;
}
.wide-popover .popover-body {
  max-height: 250px;
  overflow-y: auto;
  font-size: 0.85rem;
  line-height: 1.5;
}
.popover-text-content {
  white-space: pre-wrap;
  word-break: break-word;
}
</style>
