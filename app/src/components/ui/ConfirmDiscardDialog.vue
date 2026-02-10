<template>
  <BModal
    :id="modalId"
    ref="modal"
    centered
    size="sm"
    header-bg-variant="warning"
    header-text-variant="dark"
    no-close-on-backdrop
    no-close-on-esc
    :title="title"
    role="alertdialog"
    :aria-label="title"
  >
    <p class="mb-0">{{ message }}</p>
    <template #footer>
      <BButton variant="outline-secondary" size="sm" @click="keepEditing">
        <i class="bi bi-pencil-square" aria-hidden="true" />
        Keep editing
      </BButton>
      <BButton variant="danger" size="sm" @click="discard">
        <i class="bi bi-trash" aria-hidden="true" />
        Discard changes
      </BButton>
    </template>
  </BModal>
</template>

<script lang="ts">
import { defineComponent, ref } from 'vue';
import { BModal, BButton } from 'bootstrap-vue-next';

export default defineComponent({
  name: 'ConfirmDiscardDialog',
  components: { BModal, BButton },
  props: {
    modalId: {
      type: String,
      default: 'confirm-discard-dialog',
    },
    title: {
      type: String,
      default: 'Unsaved Changes',
    },
    message: {
      type: String,
      default:
        'You have unsaved changes that will be lost. Do you want to keep editing or discard your changes?',
    },
  },
  emits: ['discard', 'keep-editing'],
  setup(props, { emit, expose }) {
    const modal = ref<InstanceType<typeof BModal> | null>(null);

    const show = () => {
      modal.value?.show();
    };

    const hide = () => {
      modal.value?.hide();
    };

    const discard = () => {
      hide();
      emit('discard');
    };

    const keepEditing = () => {
      hide();
      emit('keep-editing');
    };

    expose({ show, hide });

    return { modal, discard, keepEditing };
  },
});
</script>
