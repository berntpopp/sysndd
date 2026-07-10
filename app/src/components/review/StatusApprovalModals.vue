<!-- components/review/StatusApprovalModals.vue -->
<!--
  StatusApprovalModals.vue (Wave 2 Task 5, #346).

  Owns the four status-approval modals (Approve / Dismiss / EditStatus /
  ApproveAll) that `ApprovalTableView.vue` (689 LoC) previously inlined
  alongside its table/cell/row plumbing. `ApprovalTableView.vue` forwards its
  own status-approval props/emits through unchanged — so the public contract
  between it and `ApproveStatus.vue` never moves — and reaches this
  component's `showModal`/`hideModal` via a template ref, mirroring the
  bridge `EditStatusModal.vue` already uses for its own inner `BModal`.
-->
<template>
  <div>
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
import { getCurrentInstance, type PropType } from 'vue';
import EditStatusModal, {
  type StatusInfoShape,
  type EntityInfoShape,
  type StatusOption,
} from '@/components/review/EditStatusModal.vue';

defineProps({
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
  /** Total pending-status row count, echoed in the ApproveAll copy. */
  totalRows: { type: Number, default: 0 },
  /** Color-and-symbols map (injected from the grandparent view). */
  userIcon: {
    type: Object as PropType<Record<string, string>>,
    default: () => ({}),
  },
  /** Modal IDs — parent passes so `wrapper.vm.approveModal.id` round-trips. */
  approveModalId: { type: String, default: 'approve-modal' },
  dismissModalId: { type: String, default: 'dismiss-modal' },
  editModalId: { type: String, default: 'status-modal' },
  approveAllModalId: { type: String, default: 'approveAllModal' },
});

defineEmits<{
  (e: 'approve-ok'): void;
  (e: 'dismiss-ok'): void;
  (e: 'edit-ok'): void;
  (e: 'edit-hide', event: unknown): void;
  (e: 'approve-all-ok'): void;
  (e: 'update:approveAllSelected', value: boolean): void;
  (e: 'update:statusInfo', value: StatusInfoShape): void;
}>();

// ---------------------------------------------------------------------------
// Modal-ref helpers exposed to the parent (`ApprovalTableView.vue`), which
// forwards its own `showModal`/`hideModal` here instead of reaching into
// `$refs` itself — keeps the modal DOM plumbing scoped to this component.
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

defineExpose({ showModal, hideModal });
</script>
