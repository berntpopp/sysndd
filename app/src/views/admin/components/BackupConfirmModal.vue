<!-- views/admin/components/BackupConfirmModal.vue -->
<template>
  <BModal
    :model-value="modelValue"
    :title="title"
    centered
    header-bg-variant="danger"
    header-text-variant="light"
    @update:model-value="$emit('update:modelValue', $event)"
    @hidden="$emit('update:confirmText', '')"
  >
    <div class="backup-danger-panel" :class="dangerPanelClass">
      <i class="bi bi-exclamation-triangle-fill backup-danger-panel__icon" />
      <div>
        <h3 class="backup-danger-panel__title">{{ panelTitle }}</h3>
        <p class="backup-danger-panel__copy">{{ panelCopy }}</p>
      </div>
    </div>
    <dl v-if="backup" class="backup-confirm-details">
      <div>
        <dt>Backup</dt>
        <dd>
          <code>{{ backup.filename }}</code>
        </dd>
      </div>
      <div>
        <dt>Size</dt>
        <dd>{{ formatFileSize(backup.size_bytes) }}</dd>
      </div>
      <div>
        <dt>Created</dt>
        <dd>{{ formatDate(backup.created_at) }}</dd>
      </div>
    </dl>
    <label class="form-label fw-bold" :for="inputId">
      Type <code>{{ confirmWord }}</code> to confirm
    </label>
    <BFormInput
      :id="inputId"
      :model-value="confirmText"
      :placeholder="confirmWord"
      autocomplete="off"
      @update:model-value="$emit('update:confirmText', String($event ?? ''))"
    />
    <template #footer>
      <div class="backup-confirm-footer">
        <BButton variant="outline-secondary" @click="$emit('update:modelValue', false)">
          Cancel
        </BButton>
        <BButton variant="danger" :disabled="confirmText !== confirmWord" @click="$emit('confirm')">
          {{ confirmLabel }}
        </BButton>
      </div>
    </template>
  </BModal>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { BackupItem } from '../composables/useBackupInventory';
import {
  formatFileSize,
  formatDate,
} from '../composables/useBackupInventory';

const props = withDefaults(
  defineProps<{
    /** Two-way modal visibility flag. */
    modelValue: boolean;
    /** Two-way confirmation-input value. */
    confirmText: string;
    /** The backup whose details are shown in the modal. */
    backup: BackupItem | null;
    /** Modal header title. */
    title: string;
    /** Heading inside the danger panel. */
    panelTitle: string;
    /** Body copy inside the danger panel. */
    panelCopy: string;
    /** Word the operator must type to enable the action button. */
    confirmWord: string;
    /** Action-button label. */
    confirmLabel: string;
    /** Variant tweak: 'delete' tints the danger panel amber to match legacy styling. */
    variant?: 'restore' | 'delete';
  }>(),
  {
    variant: 'restore',
  }
);

defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (e: 'update:confirmText', value: string): void;
  (e: 'confirm'): void;
}>();

const dangerPanelClass = computed(() =>
  props.variant === 'delete' ? 'backup-danger-panel--delete' : ''
);

const inputId = computed(() =>
  props.variant === 'delete' ? 'delete-confirm-input' : 'restore-confirm-input'
);
</script>

<style scoped>
.backup-danger-panel {
  display: grid;
  grid-template-columns: auto 1fr;
  gap: 0.75rem;
  margin-bottom: 1rem;
  padding: 0.875rem;
  border: 1px solid rgba(220, 53, 69, 0.28);
  border-radius: 0.5rem;
  background: rgba(220, 53, 69, 0.08);
}

.backup-danger-panel--delete {
  background: rgba(255, 193, 7, 0.12);
}

.backup-danger-panel__icon {
  color: #dc3545;
  font-size: 1.35rem;
  line-height: 1;
}

.backup-danger-panel__title {
  margin: 0;
  color: #842029;
  font-size: 0.95rem;
  font-weight: 800;
}

.backup-danger-panel__copy {
  margin: 0.25rem 0 0;
  color: #495057;
  font-size: 0.875rem;
}

.backup-confirm-details {
  display: grid;
  gap: 0.5rem;
  margin: 0 0 1rem;
}

.backup-confirm-details div {
  display: grid;
  grid-template-columns: 5rem minmax(0, 1fr);
  gap: 0.75rem;
}

.backup-confirm-details dt {
  color: #64748b;
  font-size: 0.8125rem;
  font-weight: 700;
}

.backup-confirm-details dd {
  min-width: 0;
  margin: 0;
  overflow-wrap: anywhere;
}

.backup-confirm-footer {
  display: flex;
  justify-content: flex-end;
  gap: 0.5rem;
  width: 100%;
}
</style>
