<!-- app/src/views/curate/components/StatusModifyModal.vue -->
<template>
  <BModal
    id="modifyStatusModal"
    v-model="proxyVisible"
    size="lg"
    centered
    ok-title="Submit"
    no-close-on-esc
    no-close-on-backdrop
    header-bg-variant="dark"
    header-text-variant="light"
    header-close-label="Close"
    :busy="loading || submitting === 'status'"
    @ok.prevent="$emit('submit')"
    @hide="onHide"
  >
    <template #title>
      <div class="d-flex flex-column gap-2">
        <h4 class="mb-0">
          Modify Status
          <EntityBadge
            v-if="entity?.entity_id"
            :entity-id="entity.entity_id"
            variant="primary"
            size="md"
            class="ms-2"
          />
        </h4>
        <div class="d-flex flex-wrap gap-2 small">
          <span class="d-flex align-items-center">
            <i class="bi bi-file-earmark-medical me-1" />
            <strong>{{ entity?.symbol || 'N/A' }}</strong>
          </span>
          <span class="text-muted">|</span>
          <span
            class="d-flex align-items-center text-truncate"
            style="max-width: 200px"
            :title="entity?.disease_ontology_name"
          >
            <i class="bi bi-clipboard2-pulse me-1" />
            {{ entity?.disease_ontology_name || 'N/A' }}
          </span>
          <span class="text-muted">|</span>
          <span class="d-flex align-items-center">
            <i class="bi bi-diagram-3 me-1" />
            {{
              entity?.hpo_mode_of_inheritance_term_name ||
              entity?.hpo_mode_of_inheritance_term ||
              'N/A'
            }}
          </span>
          <span class="text-muted">|</span>
          <BBadge
            :variant="(stoplightsStyle[entity?.category] || 'secondary') as any"
            class="d-inline-flex align-items-center"
          >
            <i class="bi bi-stoplights me-1" />
            {{ entity?.category || 'N/A' }}
          </BBadge>
        </div>
      </div>
    </template>

    <BOverlay :show="loading" rounded="sm">
      <BForm @submit.stop.prevent="$emit('submit')">
        <!-- Status dropdown with loading state -->
        <BSpinner v-if="statusOptionsLoading" small label="Loading..." />
        <BFormSelect
          v-else-if="statusOptions && statusOptions.length > 0"
          id="status-select"
          :model-value="formData.category_id"
          :options="normalizedStatusOptions"
          size="sm"
          @update:model-value="$emit('update:form-data', { ...formData, category_id: $event })"
        >
          <template #first>
            <BFormSelectOption :value="null">Select status...</BFormSelectOption>
          </template>
        </BFormSelect>
        <BAlert v-else-if="statusOptions !== null" variant="warning" class="mb-0">
          No status options available
        </BAlert>

        <BFormCheckbox
          id="removeSwitch"
          :model-value="formData.problematic"
          switch
          size="md"
          @update:model-value="$emit('update:form-data', { ...formData, problematic: $event })"
        >
          Suggest removal
        </BFormCheckbox>

        <label class="mr-sm-2 font-weight-bold" for="status-textarea-comment">Comment</label>
        <BFormTextarea
          id="status-textarea-comment"
          :model-value="formData.comment"
          rows="2"
          size="sm"
          placeholder="Why should this entity's status be changed."
          @update:model-value="$emit('update:form-data', { ...formData, comment: $event })"
        />
      </BForm>
    </BOverlay>
  </BModal>
</template>

<script lang="ts">
import { computed, defineComponent, type PropType } from 'vue';
import EntityBadge from '@/components/ui/EntityBadge.vue';
import type { StatusFormData } from '../composables/useStatusForm';

export default defineComponent({
  name: 'StatusModifyModal',
  components: { EntityBadge },
  props: {
    visible: { type: Boolean, default: false },
    loading: { type: Boolean, default: false },
    submitting: { type: String as PropType<string | null>, default: null },
    entity: { type: Object as PropType<Record<string, any> | null>, default: null },
    statusOptions: { type: Array as PropType<any[] | null>, default: null },
    statusOptionsLoading: { type: Boolean, default: false },
    formData: {
      type: Object as PropType<StatusFormData>,
      required: true,
    },
    hasChanges: { type: Boolean, default: false },
    stoplightsStyle: { type: Object as PropType<Record<string, string>>, default: () => ({}) },
  },
  emits: ['update:visible', 'update:form-data', 'submit', 'discard-request'],
  setup(props, { emit }) {
    const proxyVisible = computed({
      get: () => props.visible,
      set: (v: boolean) => emit('update:visible', v),
    });

    const normalizedStatusOptions = computed(() => {
      if (!props.statusOptions || !Array.isArray(props.statusOptions)) return [];
      return props.statusOptions.map((opt: any) => ({ value: opt.id, text: opt.label }));
    });

    function onHide(event: any): void {
      if (props.hasChanges && props.submitting !== 'status') {
        event?.preventDefault?.();
        emit('discard-request', 'status');
      }
    }

    return { proxyVisible, normalizedStatusOptions, onHide };
  },
});
</script>
