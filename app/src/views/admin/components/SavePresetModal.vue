<!-- views/admin/components/SavePresetModal.vue -->
<!--
  Names and saves the current user-table filter as a quick-filter preset.
  Replaces a native window.prompt() with the app's modal language. Visibility
  is two-way via v-model:visible (matching the sibling user modals); the
  component owns its input state and emits `confirm` with the trimmed name.
  Kept mounted by the parent so @hidden can reset the field on every close.
-->
<template>
  <BModal
    :model-value="visible"
    title="Save filter preset"
    centered
    @update:model-value="$emit('update:visible', $event)"
    @hidden="onHidden"
  >
    <label class="form-label fw-semibold" :for="inputId">Preset name</label>
    <BFormInput
      :id="inputId"
      v-model="name"
      placeholder="e.g. Pending curators"
      autocomplete="off"
      :state="name.trim() ? true : null"
      @keyup.enter="onConfirm"
    />
    <p class="text-muted small mt-2 mb-0">Saves the currently active filters under this name.</p>
    <template #footer>
      <BButton variant="outline-secondary" @click="onCancel">Cancel</BButton>
      <BButton variant="primary" :disabled="!name.trim()" @click="onConfirm">Save preset</BButton>
    </template>
  </BModal>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import { BModal, BButton, BFormInput } from 'bootstrap-vue-next';

defineProps<{
  /** Two-way modal visibility flag (v-model:visible). */
  visible: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:visible', value: boolean): void;
  (e: 'confirm', name: string): void;
  (e: 'cancel'): void;
}>();

const inputId = 'save-preset-name-input';
const name = ref('');

function onConfirm(): void {
  const trimmed = name.value.trim();
  if (!trimmed) return;
  emit('confirm', trimmed);
  emit('update:visible', false);
}

function onCancel(): void {
  emit('cancel');
  emit('update:visible', false);
}

function onHidden(): void {
  name.value = '';
}
</script>
