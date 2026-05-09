<!-- app/src/views/curate/components/EntitySearchPanel.vue -->
<template>
  <BCard class="my-2" body-class="p-2" header-class="p-1" border-variant="dark">
    <template #header>
      <h6 class="mb-1 text-start font-weight-bold">1. Select an entity to modify</h6>
    </template>

    <BRow>
      <BCol class="my-1">
        <AutocompleteInput
          v-model:display-value="displayProxy"
          :model-value="modelValue as any"
          :results="searchResults"
          :loading="loading"
          label="Entity"
          input-id="entity-select"
          placeholder="Search by ID, gene symbol, or disease name..."
          item-key="entity_id"
          item-label="symbol"
          item-secondary="entity_id"
          item-description="disease_ontology_name"
          @search="(q) => $emit('search', q)"
          @update:model-value="(id) => $emit('update:model-value', id)"
        />
        <small class="text-muted">
          Search for entities by sysndd ID, gene symbol, or disease name
        </small>
      </BCol>
    </BRow>
  </BCard>
</template>

<script lang="ts">
import { computed, defineComponent, type PropType } from 'vue';
import AutocompleteInput from '@/components/forms/AutocompleteInput.vue';

export default defineComponent({
  name: 'EntitySearchPanel',
  components: { AutocompleteInput },
  props: {
    modelValue: {
      type: [Number, null] as PropType<number | null>,
      default: null,
    },
    displayValue: {
      type: String,
      default: '',
    },
    searchResults: {
      type: Array as PropType<any[]>,
      default: () => [],
    },
    loading: {
      type: Boolean,
      default: false,
    },
  },
  emits: ['update:model-value', 'update:display-value', 'search'],
  setup(props, { emit }) {
    const displayProxy = computed({
      get: () => props.displayValue,
      set: (v: string) => emit('update:display-value', v),
    });
    return { displayProxy };
  },
});
</script>
