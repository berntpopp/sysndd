<!-- components/ui/ConfirmActionModal.vue -->
<!--
  Generic confirmation modal in the app's modal language (replaces native
  window.confirm()). Yes/no semantics with a configurable title, message,
  confirm label, and variant. Visibility is two-way via v-model; the parent
  keeps it mounted (no v-if) so @hidden can own any reset. Emits `confirm`
  when the operator accepts and `cancel` when they decline.
-->
<template>
  <BModal
    :model-value="modelValue"
    :title="title"
    :header-bg-variant="headerBgVariant"
    :header-text-variant="headerTextVariant"
    centered
    role="alertdialog"
    :aria-label="title"
    @update:model-value="$emit('update:modelValue', $event)"
    @hidden="$emit('hidden')"
  >
    <div v-if="icon" class="text-center mb-3">
      <i :class="`bi ${icon} ${iconClass} fs-1`" aria-hidden="true" />
    </div>

    <!-- Default slot allows richer bodies; falls back to the message prop. -->
    <slot>
      <p class="mb-0 text-center">{{ message }}</p>
    </slot>

    <template #footer>
      <BButton variant="outline-secondary" :disabled="busy" @click="onCancel">
        {{ cancelLabel }}
      </BButton>
      <BButton :variant="confirmVariant" :disabled="busy" @click="$emit('confirm')">
        <BSpinner v-if="busy" small class="me-1" />
        {{ confirmLabel }}
      </BButton>
    </template>
  </BModal>
</template>

<script lang="ts">
import { defineComponent, type PropType } from 'vue';
import { BModal, BButton, BSpinner, type ButtonVariant, type ColorVariant } from 'bootstrap-vue-next';

export default defineComponent({
  name: 'ConfirmActionModal',
  components: { BModal, BButton, BSpinner },
  props: {
    /** Two-way modal visibility flag. */
    modelValue: { type: Boolean, default: false },
    /** Header title. */
    title: { type: String, default: 'Please confirm' },
    /** Body copy shown when the default slot is not provided. */
    message: { type: String, default: '' },
    /** Confirm-button label. */
    confirmLabel: { type: String, default: 'Confirm' },
    /** Cancel-button label. */
    cancelLabel: { type: String, default: 'Cancel' },
    /** Confirm-button Bootstrap variant (e.g. 'primary', 'warning', 'danger'). */
    confirmVariant: { type: String as PropType<ButtonVariant>, default: 'primary' },
    /** Header background variant. */
    headerBgVariant: { type: String as PropType<ColorVariant>, default: 'warning' },
    /** Header text variant. */
    headerTextVariant: { type: String as PropType<ColorVariant>, default: 'dark' },
    /** Optional Bootstrap-Icons class shown above the message (e.g. 'bi-exclamation-triangle-fill'). */
    icon: { type: String, default: '' },
    /** Icon colour class (e.g. 'text-warning', 'text-danger'). */
    iconClass: { type: String, default: 'text-warning' },
    /** Disables both buttons and shows a spinner on confirm while an action runs. */
    busy: { type: Boolean, default: false },
  },
  emits: ['update:modelValue', 'confirm', 'cancel', 'hidden'],
  methods: {
    onCancel() {
      this.$emit('cancel');
      this.$emit('update:modelValue', false);
    },
  },
});
</script>
