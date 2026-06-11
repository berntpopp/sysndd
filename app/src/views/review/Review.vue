<!-- views/review/Review.vue -->
<template>
  <AuthenticatedPageShell
    title="Re-review"
    description="Review assigned entities, update curation status, and submit completed re-review work."
    :meta="`${totalRows} entities`"
    content-class="review-page"
  >
    <BSpinner v-if="loading" label="Loading..." class="float-center m-5" />
    <template v-else>
      <ReviewQueueTable
        :filtered-items="filteredItems"
        :fields="fields"
        :is-busy="isBusy"
        :total-rows="totalRows"
        :legend-items="legendItems"
        :user="user"
        :curator-mode="curator_mode"
        :empty-text="empty_table_text[curation_selected]"
        :filter="filter"
        :filter-on="filterOn"
        :category-filter="categoryFilter"
        :user-filter="userFilter"
        :sort-by="sortBy"
        :category-filter-options="categoryFilterOptions"
        :user-filter-options="userFilterOptions"
        :active-quick-filters="activeQuickFilters"
        :available-quick-filters="availableQuickFilters"
        :current-page="currentPage"
        :per-page="perPage"
        :page-options="pageOptions"
        :curation-selected="curation_selected"
        :user-icon="user_icon"
        :user-style="user_style"
        :ndd-icon-text="ndd_icon_text"
        :data-age-text="data_age_text"
        :data-age-style="data_age_style"
        :date-year-age="dateYearAge"
        @refresh="loadReReviewData"
        @new-batch="newBatchApplication"
        @add-quick-filter="addQuickFilter"
        @remove-quick-filter="removeQuickFilter"
        @info-review="infoReview"
        @info-status="infoStatus"
        @info-submit="infoSubmit"
        @info-approve="infoApprove"
        @info-refuse="infoRefuse"
        @filtered="onFiltered"
        @update:filter="filter = $event"
        @update:category-filter="categoryFilter = $event"
        @update:user-filter="userFilter = $event"
        @update:sort-by="handleSortByUpdate"
        @update:current-page="currentPage = $event"
        @update:per-page="perPage = $event"
        @update:curation-selected="curation_selected = $event"
      />

      <!--
        W6 of v11.1 finish-hardening — modals are extracted into focused
        presentational components under `./components/`. Each component
        owns its template + slot bindings only; data, mutations, and the
        BModal `$ref` show/hide handshake stay in the parent so the
        existing test surface against this view keeps working.
      -->
      <ReviewEditModal
        ref="reviewModalRef"
        :modal-descriptor="reviewModal"
        :form-data="reviewFormData"
        :review-info="review_info"
        :entity-info="entity_info"
        :phenotypes-options="phenotypes_options"
        :variation-options="variation_ontology_options"
        :loading="reviewFormLoading"
        :is-saving="reviewFormIsSaving"
        :user-icon="user_icon"
        @show="onReviewModalShow"
        @ok="submitReviewChange"
      />

      <StatusEditModal
        ref="statusModalRef"
        :modal-descriptor="statusModal"
        :form-data="statusFormData"
        :entity-info="entity_info"
        :status-options="status_options"
        :loading="statusFormLoading"
        :is-saving="statusFormIsSaving"
        :user-icon="user_icon"
        @show="onStatusModalShow"
        @ok="submitStatusChange"
      />

      <SubmitConfirmModal
        ref="submitModalRef"
        :modal-descriptor="submitModal"
        @ok="handleSubmitOk"
      />

      <RefuseConfirmModal
        ref="refuseModalRef"
        :modal-descriptor="refuseModal"
        :reason="refuse_reason"
        @ok="handleRefuseOk"
        @update:reason="refuse_reason = $event"
      />

      <ApproveDecisionModal
        ref="approveModalRef"
        :modal-descriptor="approveModal"
        :review-approved="review_approved"
        :status-approved="status_approved"
        @ok="handleApproveOk"
        @unsubmit="onApproveUnsubmit"
        @update:review-approved="review_approved = $event"
        @update:status-approved="status_approved = $event"
      />

      <!-- AriaLiveRegion for screen reader announcements -->
      <AriaLiveRegion :message="a11yMessage" :politeness="a11yPoliteness" />
    </template>
  </AuthenticatedPageShell>
</template>

<script>
import { computed, ref, watch } from 'vue';
import { useToast, useColorAndSymbols, useText, useAriaLive } from '@/composables';
import { useAuth } from '@/composables/useAuth';
import useStatusForm from '@/views/curate/composables/useStatusForm';
import useReviewForm from '@/views/curate/composables/useReviewForm';
import useReviewData from './composables/useReviewData';
import useReviewFilters from './composables/useReviewFilters';
import useReviewModals from './composables/useReviewModals';
import useReviewActions from './composables/useReviewActions';
import AriaLiveRegion from '@/components/accessibility/AriaLiveRegion.vue';
import AuthenticatedPageShell from '@/components/layout/AuthenticatedPageShell.vue';

// W6 presentational components.
import ReviewQueueTable from './components/ReviewQueueTable.vue';
import ReviewEditModal from './components/ReviewEditModal.vue';
import StatusEditModal from './components/StatusEditModal.vue';
import SubmitConfirmModal from './components/SubmitConfirmModal.vue';
import RefuseConfirmModal from './components/RefuseConfirmModal.vue';
import ApproveDecisionModal from './components/ApproveDecisionModal.vue';

// Import the utilities file
import Utils from '@/assets/js/utils';

// W6 of v11.1 finish-hardening — orchestration shell.
//
// Every data-loading, filter, modal, and mutation concern lives in a
// dedicated composable under `./composables/`. This file's `setup()`
// instantiates the four composables, wires them together, and exposes
// their public APIs to the Options-API template via the spread return.
// Methods retained on the component are either thin glue (e.g. modal
// `$refs.show()`, `loadReReviewData` orchestration that calls into both
// the data composable AND the filter pagination reset) or pure
// formatting helpers (`truncate`, `dateYearAge`).

const TABLE_FIELDS = Object.freeze([
  { key: 'entity_id', label: 'Entity', sortable: true, sortDirection: 'desc', class: 'text-start' },
  {
    key: 'symbol',
    label: 'Gene',
    sortable: true,
    filterable: true,
    sortDirection: 'desc',
    class: 'text-start',
  },
  {
    key: 'disease_ontology_name',
    label: 'Disease',
    sortable: true,
    class: 'text-start',
    sortByFormatted: true,
    filterByFormatted: true,
  },
  {
    key: 'hpo_mode_of_inheritance_term_name',
    label: 'Inheritance',
    sortable: true,
    class: 'text-start',
    sortByFormatted: true,
    filterByFormatted: true,
  },
  { key: 'category', label: 'Category', sortable: true, class: 'text-center' },
  { key: 'ndd_phenotype_word', label: 'NDD', sortable: true, class: 'text-center' },
  {
    key: 'review_date',
    label: 'Review date',
    sortable: true,
    filterable: true,
    class: 'text-start',
  },
  { key: 'review_user_name', label: 'User', sortable: true, filterable: true, class: 'text-start' },
  { key: 'actions', label: 'Actions', class: 'text-center' },
]);

const LEGEND_ITEMS = Object.freeze([
  { icon: 'bi bi-stoplights-fill', color: '#4caf50', label: 'Definitive' },
  { icon: 'bi bi-stoplights-fill', color: '#2196f3', label: 'Moderate' },
  { icon: 'bi bi-stoplights-fill', color: '#ff9800', label: 'Limited' },
  { icon: 'bi bi-stoplights-fill', color: '#f44336', label: 'Refuted' },
  { icon: 'bi bi-check-circle-fill', color: '#198754', label: 'Re-review approved' },
  { icon: 'bi bi-hourglass-split', color: '#ffc107', label: 'Pending re-review' },
]);

const EMPTY_USER = Object.freeze({
  user_id: [],
  user_name: [],
  email: [],
  user_role: [],
  user_created: [],
  abbreviation: [],
  orcid: [],
  exp: [],
});

export default {
  name: 'ReviewView',
  components: {
    AuthenticatedPageShell,
    AriaLiveRegion,
    ReviewQueueTable,
    ReviewEditModal,
    StatusEditModal,
    SubmitConfirmModal,
    RefuseConfirmModal,
    ApproveDecisionModal,
  },
  setup() {
    const { makeToast } = useToast();
    const colorAndSymbols = useColorAndSymbols();
    const text = useText();
    const { message: a11yMessage, politeness: a11yPoliteness, announce } = useAriaLive();

    const onComposableError = (e) => {
      makeToast(e, 'Error', 'danger');
    };

    // W6 composables: data + filters + modals + actions.
    const data = useReviewData({ onError: onComposableError });
    const filters = useReviewFilters(data.items);
    const modals = useReviewModals();
    const actions = useReviewActions({ onError: onComposableError });

    // Pre-existing curate-form composables (re-used unchanged).
    const statusForm = useStatusForm();
    const {
      formData: statusFormData,
      loading: statusFormLoading,
      isSaving: statusFormIsSaving,
    } = statusForm;
    const reviewForm = useReviewForm();
    const {
      formData: reviewFormData,
      loading: reviewFormLoading,
      isSaving: reviewFormIsSaving,
    } = reviewForm;

    // Pagination + curator-mode local state. These are not owned by any
    // composable: pagination is BTable-specific and the curator-mode flag
    // is hydrated from `useAuth()` in mounted().
    const currentPage = ref(1);
    const perPage = ref(25);
    const pageOptions = [10, 25, 50, 100];
    const curation_selected = ref(false);
    const curator_mode = ref(0);
    const user = ref({ ...EMPTY_USER });

    // Re-fetch the table when the curator-mode toggle flips. This watch
    // intentionally lives in `setup()` (not `watch:`) so it composes
    // cleanly with the `useReviewData` reactive surface.
    watch(curation_selected, (next) => {
      void data.loadReReviewData(next);
    });

    // Reset to page 1 whenever the filter result set changes shape — this
    // replaces the prior `watch.filteredItems` + `onFiltered` interplay.
    watch(filters.filteredItems, () => {
      currentPage.value = 1;
    });

    return {
      // i18n + design tokens
      makeToast,
      ...colorAndSymbols,
      ...text,

      // a11y
      a11yMessage,
      a11yPoliteness,
      announce,

      // form composables (re-exposed for template)
      statusForm,
      statusFormData,
      statusFormLoading,
      statusFormIsSaving,
      reviewForm,
      reviewFormData,
      reviewFormLoading,
      reviewFormIsSaving,

      // useReviewData state
      items: data.items,
      isBusy: data.isBusy,
      loading: data.loading,
      // v11.1 finish-hardening fix #3: `filters.filteredItems` is a
      // ComputedRef<T[]> (see useReviewFilters.ts). Wrapping it with
      // `toRef(filteredItems, 'length')` returned a ref *into the ComputedRef
      // wrapper itself* — auto-unwrap then handed BTable the underlying
      // array, not its length. BTable's `total-rows` prop is typed as Number,
      // so the array reached the prop validator and produced a runtime warning
      // ("Invalid prop: type check failed for prop 'totalRows'"). Use a
      // computed() that explicitly reads `.value.length` so the template
      // receives the numeric count BV3's BTable expects.
      totalRows: computed(() => filters.filteredItems.value?.length ?? 0),
      phenotypes_options: data.phenotypes_options,
      variation_ontology_options: data.variation_ontology_options,
      status_options: data.status_options,
      entity_info: data.entity_info,
      review_info: data.review_info,
      status_info: data.status_info,
      loading_status_modal: data.loading_status_modal,
      reviewData: data,

      // useReviewFilters state
      filter: filters.filter,
      filterOn: filters.filterOn,
      sortBy: filters.sortBy,
      categoryFilter: filters.categoryFilter,
      userFilter: filters.userFilter,
      quickFilters: filters.quickFilters,
      activeQuickFilters: filters.activeQuickFilters,
      availableQuickFilters: filters.availableQuickFilters,
      categoryFilterOptions: filters.categoryFilterOptions,
      userFilterOptions: filters.userFilterOptions,
      filteredItems: filters.filteredItems,
      addQuickFilter: filters.addQuickFilter,
      removeQuickFilter: filters.removeQuickFilter,

      // useReviewModals state
      reviewModal: modals.reviewModal,
      statusModal: modals.statusModal,
      submitModal: modals.submitModal,
      approveModal: modals.approveModal,
      refuseModal: modals.refuseModal,
      entity: modals.entity,
      review_approved: modals.review_approved,
      status_approved: modals.status_approved,
      refuse_reason: modals.refuse_reason,
      reviewModals: modals,

      // useReviewActions handle (used by the on*/handle* methods)
      reviewActions: actions,

      // Local view state
      currentPage,
      perPage,
      pageOptions,
      curation_selected,
      curator_mode,
      user,

      // Static config
      fields: TABLE_FIELDS,
      legendItems: LEGEND_ITEMS,
    };
  },
  mounted() {
    // v11.0 closeout F2c: session hydration via useAuth() preserves the
    // both-or-neither persistence invariant. If there is no session, keep
    // the default `EMPTY_USER` shape and `curator_mode = 0`.
    const auth = useAuth();
    const sessionUser = auth.user.value;
    if (sessionUser) {
      this.user = sessionUser;
      this.curator_mode =
        this.user.user_role[0] === 'Administrator' || this.user.user_role[0] === 'Curator';
    }
    void this.loadReReviewData();
    void this.reviewData.loadPhenotypesList();
    void this.reviewData.loadVariationOntologyList();
    void this.reviewData.loadStatusList();
  },
  methods: {
    // ---- Modal triggers (template @click handlers) -------------------------

    async infoReview(item) {
      this.reviewModals.setReviewTarget(item);
      await this.reviewData.getEntity(item.entity_id);

      // Clear any existing draft and load fresh data from server
      this.reviewForm.clearDraft();
      await this.reviewForm.loadReviewData(item.review_id, item.re_review_review_saved);

      // Load review metadata for the modal footer display
      await this.reviewData.loadReviewInfo(item.review_id, item.re_review_review_saved);

      this.$refs.reviewModalRef?.show();
    },
    async infoStatus(item) {
      this.reviewModals.setStatusTarget(item);
      await this.reviewData.getEntity(item.entity_id);

      // Clear any existing draft and load fresh data from server
      this.statusForm.clearDraft();
      await this.statusForm.loadStatusData(item.status_id, item.re_review_status_saved);

      this.$refs.statusModalRef?.show();
    },
    infoSubmit(item) {
      this.reviewModals.openSubmit(item);
      this.$refs.submitModalRef?.show();
    },
    infoApprove(item) {
      this.reviewModals.openApprove(item);
      this.$refs.approveModalRef?.show();
    },
    infoRefuse(item) {
      this.reviewModals.openRefuse(item);
      this.$refs.refuseModalRef?.show();
    },

    // ---- Wizard form submissions (BModal @ok wiring) -----------------------

    async submitStatusChange() {
      try {
        const isUpdate = this.statusFormData.status_id != null;
        await this.statusForm.submitForm(isUpdate, true);
        this.makeToast('Status submitted successfully', 'Success', 'success');
        this.announce('Status submitted successfully');
        this.statusForm.resetForm();
        await this.loadReReviewData();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
        this.announce('Failed to submit status', 'assertive');
      }
    },
    async submitReviewChange() {
      try {
        const isUpdate = this.review_info.review_id != null;
        await this.reviewForm.submitForm(isUpdate, true);
        this.makeToast('Review submitted successfully', 'Success', 'success');
        this.announce('Review submitted successfully');
        this.reviewForm.resetForm();
        await this.loadReReviewData();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
        this.announce('Failed to submit review', 'assertive');
      }
    },

    // ---- Re-review mutations (BModal @ok handlers) -------------------------

    async loadReReviewData() {
      await this.reviewData.loadReReviewData(this.curation_selected);
    },
    async handleSubmitOk() {
      await this.reviewActions.submitReReviewEntity(this.entity[0].re_review_entity_id);
      await this.loadReReviewData();
    },
    async handleApproveOk() {
      await this.reviewActions.approveEntity(this.entity[0].re_review_entity_id, {
        status_ok: this.status_approved,
        review_ok: this.review_approved,
      });
      this.reviewModals.resetApproveModal();
      await this.loadReReviewData();
    },
    async handleRefuseOk() {
      const ok = await this.reviewActions.refuseEntity(
        this.entity[0].re_review_entity_id,
        this.refuse_reason
      );
      if (ok) {
        this.makeToast('Re-review refused and flagged for specialist', 'Success', 'success');
        this.announce('Re-review refused and flagged for specialist');
        this.reviewModals.resetRefuseModal();
        await this.loadReReviewData();
      } else {
        this.announce('Failed to refuse re-review', 'assertive');
      }
    },
    async handleUnsetSubmission() {
      await this.reviewActions.unsubmitEntity(this.entity[0].re_review_entity_id);
      this.reviewModals.resetApproveModal();
      await this.loadReReviewData();
    },
    async newBatchApplication() {
      try {
        await this.reviewActions.applyForBatch();
        this.makeToast('Application send.', 'Success', 'success');
        this.announce('Batch application sent successfully');
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
        this.announce('Failed to send batch application', 'assertive');
      }
    },

    // ---- BTable + BModal glue ---------------------------------------------

    handleSortByUpdate(newSortBy) {
      this.sortBy = newSortBy;
    },
    onFiltered(filteredItems) {
      // BTable emits this when its internal filter prop drops rows. The
      // composable already drives `totalRows` from `filteredItems.length`,
      // so we only reset pagination here.
      void filteredItems;
      this.currentPage = 1;
    },
    onReviewModalShow() {
      // Data is loaded by infoReview() before show() is called.
    },
    onStatusModalShow() {
      // Data is loaded by infoStatus() before show() is called.
    },
    onApproveUnsubmit() {
      // The Unsubmit button inside ApproveDecisionModal fires this. We
      // run the mutation AND close the modal, matching the legacy
      // composed-call shape `(handleUnsetSubmission(), hideModal(id))`.
      void this.handleUnsetSubmission();
      this.$refs.approveModalRef?.hide();
    },
    hideModal(id) {
      // Backwards-compatible imperative hide-by-id used by tests + a few
      // remaining ad-hoc callers in the template. Looks up the matching
      // sub-component ref by descriptor id.
      const refMap = {
        [this.reviewModal.id]: this.$refs.reviewModalRef,
        [this.statusModal.id]: this.$refs.statusModalRef,
        [this.submitModal.id]: this.$refs.submitModalRef,
        [this.refuseModal.id]: this.$refs.refuseModalRef,
        [this.approveModal.id]: this.$refs.approveModalRef,
      };
      refMap[id]?.hide();
    },

    // ---- Pure helpers ------------------------------------------------------

    truncate(str, n) {
      return Utils.truncate(str, n);
    },
    dateYearAge(date, rounding) {
      return (
        Math.round((Date.now() - Date.parse(date)) / 1000 / 60 / 60 / 24 / 365 / rounding) *
        rounding
      );
    },
  },
};
</script>

<style scoped>
.btn-group-xs > .btn,
.btn-xs {
  padding: 0.25rem 0.4rem;
  font-size: 0.875rem;
  line-height: 0.5;
  border-radius: 0.2rem;
}
.badge-container .badge {
  width: 170px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}
</style>
