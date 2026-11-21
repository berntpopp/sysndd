<!--
  Undo a deactivation (#711). Deactivated entities are hidden from the entity
  search, so the curator enters the SysNDD entity ID directly. The API refuses
  (409) when an active entity already covers the association and the reason is
  shown inline.
-->
<template>
  <section class="mt-3" aria-labelledby="reactivate-entity-heading">
    <h2 id="reactivate-entity-heading" class="h6 mb-2">Reactivate a deactivated entity</h2>
    <form class="d-flex flex-wrap align-items-end gap-2" @submit.prevent="askConfirm">
      <div>
        <label for="reactivate-entity-id" class="form-label small mb-1">Entity ID (sysndd:)</label>
        <BFormInput
          id="reactivate-entity-id"
          v-model="entityIdInput"
          type="number"
          min="1"
          class="form-control-sm"
          placeholder="e.g. 123"
        />
      </div>
      <BButton type="submit" size="sm" variant="outline-success" :disabled="!entityId || busy">
        <i class="bi bi-arrow-counterclockwise" aria-hidden="true" />
        Reactivate entity
      </BButton>
    </form>
    <BAlert
      v-if="result"
      :model-value="true"
      :variant="result.variant"
      class="mt-2 mb-0"
      :role="result.variant === 'danger' ? 'alert' : 'status'"
    >
      {{ result.text }}
    </BAlert>

    <ConfirmActionModal
      v-model="confirmOpen"
      title="Reactivate entity?"
      :message="`Entity sysndd:${entityId} will become active again with its existing reviews and statuses. Its replacement link is cleared.`"
      confirm-label="Reactivate"
      confirm-variant="success"
      :busy="busy"
      @confirm="reactivate"
    />
  </section>
</template>

<script setup lang="ts">
import { computed, ref } from 'vue';
import { BAlert, BButton, BFormInput } from 'bootstrap-vue-next';
import ConfirmActionModal from '@/components/ui/ConfirmActionModal.vue';
import { reactivateEntity } from '@/api/entity';
import { extractApiErrorMessage } from '@/utils/api-errors';

const entityIdInput = ref<string | number>('');
const confirmOpen = ref(false);
const busy = ref(false);
const result = ref<{ variant: 'success' | 'danger'; text: string } | null>(null);

const entityId = computed(() => {
  const id = Number(entityIdInput.value);
  return Number.isInteger(id) && id > 0 ? id : null;
});

function askConfirm(): void {
  if (!entityId.value) return;
  result.value = null;
  confirmOpen.value = true;
}

async function reactivate(): Promise<void> {
  const id = entityId.value;
  if (!id) return;
  busy.value = true;
  try {
    await reactivateEntity(id);
    result.value = { variant: 'success', text: `Entity sysndd:${id} has been reactivated.` };
    entityIdInput.value = '';
  } catch (e) {
    result.value = {
      variant: 'danger',
      text: extractApiErrorMessage(e, 'Failed to reactivate entity'),
    };
  } finally {
    busy.value = false;
    confirmOpen.value = false;
  }
}
</script>
