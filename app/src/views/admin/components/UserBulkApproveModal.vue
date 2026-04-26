<!-- app/src/views/admin/components/UserBulkApproveModal.vue -->
<!-- Bulk-approve confirmation modal lifted from ManageUser.vue. -->
<template>
  <BModal
    v-model="proxyVisible"
    title="Approve Users"
    ok-variant="success"
    ok-title="Approve"
    cancel-title="Cancel"
    @ok.prevent="$emit('confirm')"
    @cancel="$emit('cancel')"
  >
    <p>You are about to approve {{ usernames.length }} user(s):</p>
    <div class="border rounded p-2 mb-3 bg-light" style="max-height: 200px; overflow-y: auto">
      <div v-for="username in usernames" :key="username" class="small">
        {{ username }}
      </div>
    </div>
    <p class="text-muted small">This action will grant these users access to the system.</p>
  </BModal>
</template>

<script lang="ts">
import { computed, defineComponent, type PropType } from 'vue';

export default defineComponent({
  name: 'UserBulkApproveModal',
  props: {
    visible: { type: Boolean, default: false },
    usernames: { type: Array as PropType<string[]>, default: () => [] },
  },
  emits: ['update:visible', 'confirm', 'cancel'],
  setup(props, { emit }) {
    const proxyVisible = computed({
      get: () => props.visible,
      set: (v) => emit('update:visible', v),
    });
    return { proxyVisible };
  },
});
</script>
