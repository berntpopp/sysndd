<!-- app/src/views/admin/components/UserBulkActionToolbar.vue -->
<!-- Bulk action button group rendered in the card header when selectionCount > 0. -->
<template>
  <template v-if="selectionCount > 0">
    <BButton
      v-b-tooltip.hover
      size="sm"
      variant="success"
      class="me-1"
      title="Approve selected users"
      :disabled="busy"
      @click="$emit('approve')"
    >
      <i class="bi bi-check-circle" /> Approve
    </BButton>
    <BButton
      v-b-tooltip.hover
      size="sm"
      variant="primary"
      class="me-1"
      title="Assign role to selected users"
      :disabled="busy"
      @click="$emit('assign-role')"
    >
      <i class="bi bi-person-badge" /> Role
    </BButton>
    <BButton
      v-b-tooltip.hover
      size="sm"
      variant="danger"
      class="me-1"
      title="Delete selected users"
      :disabled="busy"
      @click="$emit('delete')"
    >
      <i class="bi bi-trash" /> Delete
    </BButton>
    <BButton
      v-b-tooltip.hover
      size="sm"
      variant="link"
      title="Clear selection"
      @click="$emit('clear')"
    >
      <i class="bi bi-x-lg" />
    </BButton>
  </template>
</template>

<script lang="ts">
import { defineComponent } from 'vue';

export default defineComponent({
  name: 'UserBulkActionToolbar',
  props: {
    selectionCount: { type: Number, required: true },
    busy: { type: Boolean, default: false },
  },
  emits: ['approve', 'assign-role', 'delete', 'clear'],
});
</script>
