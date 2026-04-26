<!-- app/src/views/curate/components/EntityRenameDeactivateModal.vue -->
<template>
  <BModal
    :id="mode === 'rename' ? 'renameModal' : 'deactivateModal'"
    v-model="proxyVisible"
    size="lg"
    centered
    ok-title="Submit"
    no-close-on-esc
    no-close-on-backdrop
    header-bg-variant="dark"
    header-text-variant="light"
    header-close-label="Close"
    @ok.prevent="$emit('submit')"
    @cancel="$emit('cancel')"
    @hide="$emit('cancel')"
  >
    <template #title>
      <div class="d-flex flex-column gap-2">
        <h4 class="mb-0">
          {{ mode === 'rename' ? 'Rename Entity Disease' : 'Deactivate Entity' }}
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

    <!-- Rename mode -->
    <template v-if="mode === 'rename'">
      <p class="my-3">Select a new disease name:</p>
      <AutocompleteInput
        v-model:display-value="ontologyDisplayProxy"
        :model-value="(ontologyInput as any)"
        :results="ontologySearchResults"
        :loading="ontologySearchLoading"
        label="Disease"
        input-id="ontology-select"
        placeholder="Search by disease name or ontology ID (e.g., OMIM:123456)..."
        item-key="id"
        item-label="label"
        item-secondary="id"
        @search="(q) => $emit('search-ontology', q)"
        @update:model-value="(id) => $emit('select-ontology', id)"
      />
      <small class="text-muted">Search for diseases by name or ontology identifier</small>
    </template>

    <!-- Deactivate mode -->
    <template v-else>
      <div>
        <p class="my-2">1. Are you sure that you want to deactivate this entity?</p>
        <BFormCheckbox
          id="deactivateSwitch"
          :model-value="deactivateCheck"
          switch
          size="md"
          @update:model-value="$emit('update:deactivate-check', $event)"
        >
          <strong>{{ deactivateCheck ? 'Yes' : 'No' }}</strong>
        </BFormCheckbox>
      </div>

      <div v-if="deactivateCheck">
        <p class="my-2">2. Was this entity replaced by another one?</p>
        <BFormCheckbox
          id="replaceSwitch"
          :model-value="replaceCheck"
          switch
          size="md"
          @update:model-value="$emit('update:replace-check', $event)"
        >
          <strong>{{ replaceCheck ? 'Yes' : 'No' }}</strong>
        </BFormCheckbox>
      </div>

      <div v-if="replaceCheck">
        <p class="my-2">3. Select the entity replacing the above one:</p>
        <AutocompleteInput
          v-model:display-value="replaceDisplayProxy"
          :model-value="(replaceEntityInput as any)"
          :results="replaceSearchResults"
          :loading="replaceSearchLoading"
          label="Replacement Entity"
          input-id="replace-entity-select"
          placeholder="Search by ID, gene symbol, or disease name..."
          item-key="entity_id"
          item-label="symbol"
          item-secondary="entity_id"
          item-description="disease_ontology_name"
          @search="(q) => $emit('search-replacement', q)"
          @update:model-value="(id) => $emit('select-replacement', id)"
        />
        <small class="text-muted">Search for the entity that replaces this one</small>
      </div>
    </template>
  </BModal>
</template>

<script lang="ts">
import { computed, defineComponent, type PropType } from 'vue';
import AutocompleteInput from '@/components/forms/AutocompleteInput.vue';
import EntityBadge from '@/components/ui/EntityBadge.vue';

export default defineComponent({
  name: 'EntityRenameDeactivateModal',
  components: { AutocompleteInput, EntityBadge },
  props: {
    visible: { type: Boolean, default: false },
    mode: { type: String as PropType<'rename' | 'deactivate'>, required: true },
    entity: { type: Object as PropType<Record<string, any> | null>, default: null },
    submitting: { type: String as PropType<string | null>, default: null },
    stoplightsStyle: { type: Object as PropType<Record<string, string>>, default: () => ({}) },
    // rename mode bindings
    ontologyDisplay: { type: String, default: '' },
    ontologyInput: { type: [String, null] as PropType<string | null>, default: null },
    ontologySearchResults: { type: Array as PropType<any[]>, default: () => [] },
    ontologySearchLoading: { type: Boolean, default: false },
    // deactivate mode bindings
    deactivateCheck: { type: Boolean, default: false },
    replaceCheck: { type: Boolean, default: false },
    replaceDisplay: { type: String, default: '' },
    replaceEntityInput: { type: [Number, null] as PropType<number | null>, default: null },
    replaceSearchResults: { type: Array as PropType<any[]>, default: () => [] },
    replaceSearchLoading: { type: Boolean, default: false },
  },
  emits: [
    'update:visible',
    'update:ontology-display',
    'update:replace-display',
    'update:deactivate-check',
    'update:replace-check',
    'search-ontology',
    'select-ontology',
    'search-replacement',
    'select-replacement',
    'submit',
    'cancel',
  ],
  setup(props, { emit }) {
    const proxyVisible = computed({
      get: () => props.visible,
      set: (v: boolean) => emit('update:visible', v),
    });
    const ontologyDisplayProxy = computed({
      get: () => props.ontologyDisplay,
      set: (v: string) => emit('update:ontology-display', v),
    });
    const replaceDisplayProxy = computed({
      get: () => props.replaceDisplay,
      set: (v: string) => emit('update:replace-display', v),
    });
    return { proxyVisible, ontologyDisplayProxy, replaceDisplayProxy };
  },
});
</script>
