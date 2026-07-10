<!-- components/ApprovalTableView.vue -->
<!--
  ApprovalTableView.vue (Phase E.E6 — `converge-approve-status`).

  Generic approval-table view. Consolidates the filter/pagination/cell-render/
  modal boilerplate that `ApproveStatus.vue` previously carried inline (1,432
  LoC) by delegating to the parameterised pieces shipped in E.E5:

    - Shell: `@/components/review/ReviewTable.vue` (filters + pagination +
      BTable + slot forwarding).
    - State: `@/composables/review/useApprovalTableData` (wired with
      `categoryField: 'category'`, `userField: 'status_user_name'`,
      `dateField: 'status_date'` so the filter semantics stay status-flavoured).
    - Field/legend definitions: `@/composables/approval/useStatusHelpers`.

  This component owns:
    - the status-specific cell renderers (category / problematic / comment /
      status_date / status_user_name),
    - the row action buttons,
    - the row-expansion card.

  Wave 2 Task 5 (#346) moved the four modals (Approve / Dismiss / EditStatus /
  ApproveAll) out to `@/components/review/StatusApprovalModals.vue` to bring
  this file under the 600-line ceiling. This component still owns the
  `showModal`/`hideModal` surface the parent calls — it now delegates to the
  child via a template ref instead of reaching into its own `$refs`.

  The parent (`ApproveStatus.vue`) owns:
    - the HTTP layer (`loadStatusTableData`, `loadStatusInfo`, etc.),
    - the `infoApproveStatus`/`handleStatusOk`/... orchestrators that the C3
      spec drives via `wrapper.vm.<method>()`.

  The parent reaches through this component via a template ref:
    `ref.value.showModal('approve-modal')` — so modal UI plumbing stays here
    (now one hop further, in `StatusApprovalModals.vue`) and domain logic
    stays in the parent.
-->
<template>
  <div>
    <ReviewTable
      title="Status Queue"
      total-rows-label="statuses"
      approve-all-title="Approve all pending statuses"
      approve-all-aria-label="Approve all statuses"
      :items="filteredItems"
      :fields="fields"
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
      :loading="loading"
      @approve-all="$emit('approve-all')"
      @refresh="$emit('refresh')"
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
        />
      </template>
      <template #cell(symbol)="data">
        <GeneBadge
          :symbol="data.item.symbol"
          :hgnc-id="data.item.hgnc_id"
          :link-to="'/Genes/' + data.item.hgnc_id"
        />
      </template>
      <template #cell(disease_ontology_name)="data">
        <DiseaseBadge
          :name="data.item.disease_ontology_name"
          :ontology-id="data.item.disease_ontology_id_version"
          :max-length="40"
          :link-to="
            '/Ontology/' + (data.item.disease_ontology_id_version || '').replace(/_.+/g, '')
          "
        />
      </template>
      <template #cell(hpo_mode_of_inheritance_term_name)="data">
        <InheritanceBadge
          :full-name="data.item.hpo_mode_of_inheritance_term_name"
          :hpo-term="data.item.hpo_mode_of_inheritance_term"
        />
      </template>
      <template #cell(category)="data">
        <CategoryIcon :category="data.item.category" size="sm" :show-title="true" />
      </template>
      <template #cell(problematic)="data">
        <span
          v-b-tooltip.hover.top
          :title="problematicText[data.item.problematic]"
          class="d-inline-flex align-items-center justify-content-center rounded-circle"
          :class="
            data.item.problematic
              ? 'bg-danger-subtle text-danger'
              : 'bg-success-subtle text-success'
          "
          style="width: 24px; height: 24px; font-size: 0.75rem"
        >
          <i
            :class="
              data.item.problematic ? 'bi bi-exclamation-triangle-fill' : 'bi bi-check-circle-fill'
            "
          />
        </span>
      </template>
      <template #cell(comment)="data">
        <div
          v-if="data.item.comment"
          :id="'comment-status-' + data.item.status_id"
          class="text-truncate-multiline small text-popover-trigger"
          style="max-width: 150px"
        >
          {{ data.item.comment }}
        </div>
        <BPopover
          v-if="data.item.comment"
          :target="'comment-status-' + data.item.status_id"
          triggers="hover focus"
          placement="top"
          custom-class="wide-popover"
        >
          <template #title>
            <i class="bi bi-chat-left-text me-1" />
            Comment
          </template>
          <div class="popover-text-content">{{ data.item.comment }}</div>
        </BPopover>
        <span v-else class="text-muted small">—</span>
      </template>
      <template #cell(status_date)="data">
        <div class="d-flex align-items-center gap-1">
          <span
            v-b-tooltip.hover.top
            :title="data.item.status_date"
            class="d-inline-flex align-items-center justify-content-center rounded-circle bg-secondary-subtle text-secondary"
            style="width: 24px; height: 24px; font-size: 0.75rem"
          >
            <i class="bi bi-calendar3" />
          </span>
          <span class="small text-muted">
            {{ (data.item.status_date || '').substring(0, 10) }}
          </span>
        </div>
      </template>
      <template #cell(status_user_name)="data">
        <div class="d-flex align-items-center gap-1">
          <span
            v-b-tooltip.hover.top
            :title="data.item.status_user_role"
            class="d-inline-flex align-items-center justify-content-center rounded-circle"
            :class="`bg-${userStyle[data.item.status_user_role]}-subtle text-${userStyle[data.item.status_user_role]}`"
            style="width: 24px; height: 24px; font-size: 0.75rem"
          >
            <i :class="'bi bi-' + userIcon[data.item.status_user_role]" />
          </span>
          <span class="small">{{ data.item.status_user_name }}</span>
        </div>
      </template>
      <template #cell(actions)="row">
        <BButton
          v-b-tooltip.hover.left
          size="sm"
          class="me-1 btn-xs"
          variant="outline-primary"
          title="Toggle details"
          :aria-label="`Toggle details for entity ${row.item.entity_id}`"
          @click="row.toggleExpansion"
        >
          <i :class="'bi bi-' + (row.expansionShowing ? 'eye-slash' : 'eye')" aria-hidden="true" />
        </BButton>
        <BButton
          v-b-tooltip.hover.left
          size="sm"
          class="me-1 btn-xs"
          variant="secondary"
          :title="row.item.review_change ? 'Edit status (review change pending)' : 'Edit status'"
          :aria-label="`Edit status for entity ${row.item.entity_id}${row.item.review_change ? ' (review change pending)' : ''}`"
          @click="$emit('edit-status', row.item)"
        >
          <span class="position-relative d-inline-block" style="font-size: 0.9em">
            <i class="bi bi-pen" aria-hidden="true" />
            <i
              v-if="row.item.review_change"
              class="bi bi-exclamation-triangle-fill position-absolute text-warning"
              style="top: -0.3em; right: -0.5em; font-size: 0.7em"
              aria-hidden="true"
            />
          </span>
        </BButton>
        <BButton
          v-b-tooltip.hover.right
          size="sm"
          class="me-1 btn-xs"
          variant="danger"
          title="Approve status"
          :aria-label="`Approve status for entity ${row.item.entity_id}`"
          @click="$emit('approve-status', row.item)"
        >
          <i class="bi bi-check2-circle" aria-hidden="true" />
        </BButton>
        <BButton
          v-b-tooltip.hover.right
          size="sm"
          class="me-1 btn-xs"
          variant="outline-danger"
          title="Dismiss status"
          :aria-label="`Dismiss status for entity ${row.item.entity_id}`"
          @click="$emit('dismiss-status', row.item)"
        >
          <i class="bi bi-x-circle" aria-hidden="true" />
        </BButton>
        <BButton
          v-if="row.item.duplicate === 'yes'"
          v-b-tooltip.hover.right
          variant="warning"
          title="Multiple pending statuses for this entity"
          :aria-label="`Warning: Multiple pending statuses for entity ${row.item.entity_id}`"
          size="sm"
          class="me-1 btn-xs"
        >
          <i class="bi bi-exclamation-triangle-fill" aria-hidden="true" />
        </BButton>
      </template>
      <template #row-expansion="row">
        <BCard class="mb-2 border-0 shadow-sm" body-class="p-3">
          <div class="row g-3">
            <div class="col-md-4">
              <h6 class="text-muted small text-uppercase fw-semibold mb-2">
                <i class="bi bi-info-circle me-1" />
                Status Details
              </h6>
              <div class="d-flex flex-column gap-2">
                <div class="d-flex align-items-center gap-2">
                  <span class="text-muted small" style="min-width: 80px">Status ID:</span>
                  <BBadge variant="secondary">{{ row.item.status_id }}</BBadge>
                </div>
                <div class="d-flex align-items-center gap-2">
                  <span class="text-muted small" style="min-width: 80px">Category:</span>
                  <BBadge
                    :variant="
                      (stoplightsStyle[row.item.category as string | number] as
                        | 'secondary'
                        | 'primary'
                        | 'success'
                        | 'warning'
                        | 'danger'
                        | 'info') || 'secondary'
                    "
                  >
                    {{ row.item.category }}
                  </BBadge>
                </div>
                <div class="d-flex align-items-center gap-2">
                  <span class="text-muted small" style="min-width: 80px">Problematic:</span>
                  <BBadge :variant="row.item.problematic ? 'danger' : 'success'">
                    {{ row.item.problematic ? 'Yes' : 'No' }}
                  </BBadge>
                </div>
                <div class="d-flex align-items-center gap-2">
                  <span class="text-muted small" style="min-width: 80px">Active:</span>
                  <BBadge :variant="row.item.is_active ? 'success' : 'secondary'">
                    {{ row.item.is_active ? 'Yes' : 'No' }}
                  </BBadge>
                </div>
              </div>
            </div>
            <div class="col-md-8">
              <h6 class="text-muted small text-uppercase fw-semibold mb-2">
                <i class="bi bi-chat-left-text me-1" />
                Comment
              </h6>
              <div
                v-if="row.item.comment"
                class="bg-light rounded p-2 small"
                style="max-height: 120px; overflow-y: auto"
              >
                {{ row.item.comment }}
              </div>
              <span v-else class="text-muted small fst-italic">No comment available</span>
            </div>
          </div>
        </BCard>
      </template>
      <template #mobile-rows="{ items }">
        <ApprovalMobileRows
          :items="items"
          user-field="status_user_name"
          role-field="status_user_role"
          date-field="status_date"
          @edit="$emit('edit-status', $event)"
          @approve="$emit('approve-status', $event)"
          @dismiss="$emit('dismiss-status', $event)"
        />
      </template>
    </ReviewTable>

    <StatusApprovalModals
      ref="modalsRef"
      :approve-title="approveTitle"
      :dismiss-title="dismissTitle"
      :approve-has-duplicates="approveHasDuplicates"
      :loading-edit="loadingEdit"
      :status-info="statusInfo"
      :entity-info="entityInfo"
      :status-options="statusOptions"
      :approve-all-selected="approveAllSelected"
      :total-rows="totalRows"
      :user-icon="userIcon"
      :approve-modal-id="approveModalId"
      :dismiss-modal-id="dismissModalId"
      :edit-modal-id="editModalId"
      :approve-all-modal-id="approveAllModalId"
      @approve-ok="$emit('approve-ok')"
      @dismiss-ok="$emit('dismiss-ok')"
      @edit-ok="$emit('edit-ok')"
      @edit-hide="$emit('edit-hide', $event)"
      @approve-all-ok="$emit('approve-all-ok')"
      @update:approve-all-selected="$emit('update:approveAllSelected', $event)"
      @update:status-info="$emit('update:statusInfo', $event)"
    />
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch, type PropType } from 'vue';
import type { TableField } from '@/types/components';

import ReviewTable from '@/components/review/ReviewTable.vue';
import ApprovalMobileRows from '@/views/curate/components/ApprovalMobileRows.vue';
import EntityBadge from '@/components/ui/EntityBadge.vue';
import GeneBadge from '@/components/ui/GeneBadge.vue';
import DiseaseBadge from '@/components/ui/DiseaseBadge.vue';
import InheritanceBadge from '@/components/ui/InheritanceBadge.vue';
import CategoryIcon from '@/components/ui/CategoryIcon.vue';
import StatusApprovalModals from '@/components/review/StatusApprovalModals.vue';
import type {
  StatusInfoShape,
  EntityInfoShape,
  StatusOption,
} from '@/components/review/EditStatusModal.vue';

import useApprovalTableData from '@/composables/review/useApprovalTableData';
import {
  statusTableFields,
  statusLegendItems,
  problematicText,
} from '@/composables/approval/useStatusHelpers';

export interface StatusRowLike extends Record<string, unknown> {
  status_id?: number;
  entity_id?: number;
  status_date?: string;
  status_user_name?: string;
  status_user_role?: string;
  category?: string | number;
}

const props = defineProps({
  /** Pending-status rows (owner-supplied). */
  items: { type: Array as PropType<StatusRowLike[]>, required: true },
  /** Loading flag for the main spinner. */
  loading: { type: Boolean, default: false },
  /** Busy flag for the BTable body. */
  busy: { type: Boolean, default: false },
  /** Approve-modal label (e.g. `sysndd:501`). */
  approveTitle: { type: String, default: '' },
  /** Dismiss-modal label. */
  dismissTitle: { type: String, default: '' },
  /** Whether the approving entity has duplicate pending statuses. */
  approveHasDuplicates: { type: Boolean, default: false },
  /** EditStatus loading flag. */
  loadingEdit: { type: Boolean, default: false },
  /** EditStatus body data. */
  statusInfo: {
    type: Object as PropType<StatusInfoShape>,
    required: true,
  },
  /** EditStatus entity-header data. */
  entityInfo: {
    type: Object as PropType<EntityInfoShape>,
    required: true,
  },
  /** Category dropdown options for EditStatus. */
  statusOptions: {
    type: Array as PropType<StatusOption[]>,
    default: () => [],
  },
  /** "Approve all" confirmation switch. */
  approveAllSelected: { type: Boolean, default: false },
  /** Color-and-symbols maps (injected from parent). */
  userIcon: {
    type: Object as PropType<Record<string, string>>,
    default: () => ({}),
  },
  userStyle: {
    type: Object as PropType<Record<string, string>>,
    default: () => ({}),
  },
  stoplightsStyle: {
    type: Object as PropType<Record<string | number, string>>,
    default: () => ({}),
  },
  /** Modal IDs — parent passes so `wrapper.vm.approveModal.id` round-trips. */
  approveModalId: { type: String, default: 'approve-modal' },
  dismissModalId: { type: String, default: 'dismiss-modal' },
  editModalId: { type: String, default: 'status-modal' },
  approveAllModalId: { type: String, default: 'approveAllModal' },
});

const emit = defineEmits<{
  (e: 'approve-status', item: StatusRowLike): void;
  (e: 'dismiss-status', item: StatusRowLike): void;
  (e: 'edit-status', item: StatusRowLike): void;
  (e: 'approve-all'): void;
  (e: 'approve-ok'): void;
  (e: 'dismiss-ok'): void;
  (e: 'edit-ok'): void;
  (e: 'edit-hide', event: unknown): void;
  (e: 'approve-all-ok'): void;
  (e: 'refresh'): void;
  (e: 'update:approveAllSelected', value: boolean): void;
  (e: 'update:statusInfo', value: StatusInfoShape): void;
  (e: 'items-synced', items: StatusRowLike[]): void;
}>();

// ---------------------------------------------------------------------------
// Table-state composable (E5) — parameterised for status rows.
// ---------------------------------------------------------------------------
const {
  items: tableItems,
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
} = useApprovalTableData<StatusRowLike>({
  categoryField: 'category',
  userField: 'status_user_name',
  dateField: 'status_date',
  initialSortBy: [{ key: 'status_user_name', order: 'asc' }],
  initialPerPage: 100,
});

const filterText = ref<string | null>(null);
const fields = statusTableFields as unknown as TableField[];
const legendItems = statusLegendItems;

// Sync parent-provided items into the composable's items ref.  The
// `filteredItems` watch below keeps `totalRows` in sync (filteredItems
// depends on items + filters, so an items-only write here would be a
// double-write that Copilot's follow-up review flagged as dead surface).
watch(
  () => props.items,
  (next) => {
    tableItems.value = next ?? [];
    emit('items-synced', next ?? []);
  },
  { immediate: true }
);
// Mirror the busy flag.
watch(
  () => props.busy,
  (next) => {
    isBusy.value = next;
  },
  { immediate: true }
);
// Keep totalRows in sync with the filtered projection so pagination updates
// when category/user/date filters fire.
watch(filteredItems, (list) => {
  totalRows.value = list.length;
});

const onFiltered = (filteredList: unknown[]): void => {
  totalRows.value = filteredList.length;
  currentPage.value = 1;
};

// ---------------------------------------------------------------------------
// Modal-ref helpers exposed to the parent.
// `ApproveStatus.vue` calls `ref.value.showModal(id)` instead of poking into
// `$refs` directly. Wave 2 Task 5 (#346) moved the actual modals to
// `StatusApprovalModals.vue`, so this component now forwards through a
// template ref to that child instead of resolving `$refs` itself.
// ---------------------------------------------------------------------------
const modalsRef = ref<{
  showModal: (id: string) => void;
  hideModal: (id: string) => void;
} | null>(null);
const showModal = (id: string): void => {
  modalsRef.value?.showModal(id);
};
const hideModal = (id: string): void => {
  modalsRef.value?.hideModal(id);
};

// ---------------------------------------------------------------------------
// Exposed surface — parent reaches these via a template ref.
// ---------------------------------------------------------------------------
defineExpose({
  showModal,
  hideModal,
  // Table state (read-only access for parent-side integration tests).
  totalRows: computed(() => totalRows.value),
  currentPage: computed(() => currentPage.value),
  perPage: computed(() => perPage.value),
  sortBy: computed(() => sortBy.value),
  filteredItems: computed(() => filteredItems.value),
});
</script>

<style scoped>
.btn-group-xs > .btn,
.btn-xs {
  padding: 0.25rem 0.4rem;
  font-size: 0.875rem;
  line-height: 0.5;
  border-radius: 0.2rem;
}

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
