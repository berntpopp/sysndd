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
    - the row-expansion card,
    - the four modals (Approve / Dismiss / EditStatus / ApproveAll).

  The parent (`ApproveStatus.vue`) owns:
    - the HTTP layer (`loadStatusTableData`, `loadStatusInfo`, etc.),
    - the `infoApproveStatus`/`handleStatusOk`/... orchestrators that the C3
      spec drives via `wrapper.vm.<method>()`.

  The parent reaches through this component via a template ref:
    `ref.value.showModal('approve-modal')` — so modal UI plumbing stays here
    and domain logic stays in the parent.
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

    <!-- Approve status modal -->
    <BModal
      :id="approveModalId"
      :ref="approveModalId"
      centered
      ok-title="Approve"
      ok-variant="success"
      no-close-on-esc
      no-close-on-backdrop
      header-class="border-bottom-0 pb-0"
      footer-class="border-top-0 pt-0"
      header-close-label="Close"
      @ok="$emit('approve-ok')"
    >
      <template #title>
        <div class="d-flex align-items-center">
          <i class="bi bi-check-circle-fill me-2 text-success" />
          <span class="fw-semibold">Approve Status</span>
        </div>
      </template>

      <div class="text-center py-3">
        <div class="mb-3">
          <i class="bi bi-question-circle text-primary" style="font-size: 2.5rem" />
        </div>
        <p class="mb-2">
          You have finished checking this status for entity
          <BBadge variant="primary" class="mx-1">
            {{ approveTitle }}
          </BBadge>
        </p>
        <p class="text-muted small">Click <strong>Approve</strong> to confirm and submit.</p>
        <div v-if="approveHasDuplicates" class="alert alert-info small text-start mt-3 mb-0">
          <i class="bi bi-info-circle me-1" />
          Other pending statuses for this entity will be automatically dismissed.
        </div>
      </div>
    </BModal>

    <!-- Dismiss status modal -->
    <BModal
      :id="dismissModalId"
      :ref="dismissModalId"
      centered
      ok-title="Dismiss"
      ok-variant="danger"
      no-close-on-esc
      no-close-on-backdrop
      header-class="border-bottom-0 pb-0"
      footer-class="border-top-0 pt-0"
      header-close-label="Close"
      @ok="$emit('dismiss-ok')"
    >
      <template #title>
        <div class="d-flex align-items-center">
          <i class="bi bi-x-circle-fill me-2 text-danger" />
          <span class="fw-semibold">Dismiss Status</span>
        </div>
      </template>
      <div class="text-center py-3">
        <div class="mb-3">
          <i class="bi bi-x-circle text-danger" style="font-size: 2.5rem" />
        </div>
        <p class="mb-2">
          Dismiss this pending status for entity
          <BBadge variant="primary" class="mx-1">
            {{ dismissTitle }}
          </BBadge>
          ?
        </p>
        <p class="text-muted small">
          The status will be removed from the pending queue. This does not delete the record.
        </p>
      </div>
    </BModal>

    <!-- Edit status modal (status-specific EditStatusModal from E5) -->
    <EditStatusModal
      :ref="editModalId"
      :modal-id="editModalId"
      :loading="loadingEdit"
      :status-info="statusInfo"
      :entity-info="entityInfo"
      :status-options="statusOptions"
      :user-icon="userIcon"
      @ok="$emit('edit-ok')"
      @hide="$emit('edit-hide', $event)"
      @update:status-info="$emit('update:statusInfo', $event)"
    />

    <!-- Approve all modal -->
    <BModal
      :id="approveAllModalId"
      :ref="approveAllModalId"
      centered
      ok-title="Approve All"
      ok-variant="danger"
      no-close-on-esc
      no-close-on-backdrop
      header-class="border-bottom-0 pb-0"
      footer-class="border-top-0 pt-0"
      header-close-label="Close"
      @ok="$emit('approve-all-ok')"
    >
      <template #title>
        <div class="d-flex align-items-center">
          <i class="bi bi-exclamation-triangle-fill me-2 text-danger" />
          <span class="fw-semibold">Approve All Statuses</span>
        </div>
      </template>
      <div class="text-center py-3">
        <div class="mb-3">
          <i class="bi bi-exclamation-triangle text-danger" style="font-size: 2.5rem" />
        </div>
        <p class="mb-2">
          You are about to approve <strong>ALL</strong> {{ totalRows }} pending statuses.
        </p>
        <p class="text-muted small mb-3">
          This action cannot be undone. Please confirm by toggling the switch below.
        </p>
        <div class="d-flex justify-content-center">
          <BFormCheckbox
            id="approveAllSwitch"
            :model-value="approveAllSelected"
            switch
            size="lg"
            @update:model-value="$emit('update:approveAllSelected', Boolean($event))"
          >
            <strong>{{ approveAllSelected ? 'Yes, approve all' : 'No, cancel' }}</strong>
          </BFormCheckbox>
        </div>
      </div>
    </BModal>
  </div>
</template>

<script setup lang="ts">
import { computed, ref, watch, getCurrentInstance, type PropType } from 'vue';
import type { TableField } from '@/types/components';

import ReviewTable from '@/components/review/ReviewTable.vue';
import ApprovalMobileRows from '@/views/curate/components/ApprovalMobileRows.vue';
import EntityBadge from '@/components/ui/EntityBadge.vue';
import GeneBadge from '@/components/ui/GeneBadge.vue';
import DiseaseBadge from '@/components/ui/DiseaseBadge.vue';
import InheritanceBadge from '@/components/ui/InheritanceBadge.vue';
import CategoryIcon from '@/components/ui/CategoryIcon.vue';
import EditStatusModal, {
  type StatusInfoShape,
  type EntityInfoShape,
  type StatusOption,
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
// `$refs` directly — keeps the modal plumbing scoped to this component.
// ---------------------------------------------------------------------------
const instance = getCurrentInstance();
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

<style scoped src="./ApprovalTableView.css"></style>
<style src="./ApprovalTableView.global.css"></style>
