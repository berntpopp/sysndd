<!-- app/src/views/admin/components/UserBulkRoleModal.vue -->
<!-- Bulk role-assignment modal with role select, lifted from ManageUser.vue. -->
<template>
  <BModal
    v-model="proxyVisible"
    title="Assign Role"
    ok-variant="primary"
    ok-title="Assign Role"
    cancel-title="Cancel"
    :ok-disabled="!selectedRole"
    @ok.prevent="$emit('confirm')"
    @cancel="$emit('cancel')"
  >
    <p>Assign role to {{ usernames.length }} user(s):</p>
    <div class="border rounded p-2 mb-3 bg-light" style="max-height: 150px; overflow-y: auto">
      <div v-for="username in usernames" :key="username" class="small">
        {{ username }}
      </div>
    </div>
    <BFormGroup label="Select Role:" label-for="bulk-role-select">
      <BFormSelect
        id="bulk-role-select"
        :value="selectedRole"
        :options="[
          { value: '', text: 'Select a role...', disabled: true },
          { value: 'Curator', text: 'Curator' },
          { value: 'Reviewer', text: 'Reviewer' },
          { value: 'Administrator', text: 'Administrator' },
        ]"
        @change="emitRoleChange($event)"
      />
    </BFormGroup>
  </BModal>
</template>

<script lang="ts">
import { computed, defineComponent, type PropType } from 'vue';

export default defineComponent({
  name: 'UserBulkRoleModal',
  props: {
    visible: { type: Boolean, default: false },
    usernames: { type: Array as PropType<string[]>, default: () => [] },
    selectedRole: { type: String, default: '' },
  },
  emits: ['update:visible', 'update:selected-role', 'confirm', 'cancel'],
  setup(props, { emit }) {
    const proxyVisible = computed({
      get: () => props.visible,
      set: (v) => emit('update:visible', v),
    });
    function emitRoleChange(event: Event): void {
      const t = event.target as HTMLSelectElement;
      emit('update:selected-role', t.value);
    }
    return { proxyVisible, emitRoleChange };
  },
});
</script>
