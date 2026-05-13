<!-- app/src/views/curate/components/EntitySearchPanel.vue -->
<template>
  <section class="entity-search-panel" aria-label="Entity search controls">
    <header class="entity-search-panel__header">
      <p class="entity-search-panel__description">
        Search by sysndd ID, gene symbol, or disease name.
      </p>
      <div class="entity-search-panel__states" aria-live="polite">
        <span v-if="loading" class="entity-search-panel__state">Searching</span>
        <span class="entity-search-panel__state" :class="{ 'is-selected': modelValue }">
          <template v-if="modelValue">Selected entity {{ modelValue }}</template>
          <template v-else>No entity selected</template>
        </span>
      </div>
    </header>

    <BRow class="g-2 align-items-end">
      <BCol class="my-1" cols="12">
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
      </BCol>
    </BRow>
  </section>
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

<style scoped>
.entity-search-panel {
  display: grid;
  gap: 0.75rem;
  min-width: 0;
  text-align: left;
}

.entity-search-panel :deep(.autocomplete-container),
.entity-search-panel :deep(.form-control) {
  min-width: 0;
  max-width: 100%;
}

.entity-search-panel__header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 0.75rem;
}

.entity-search-panel__description {
  margin: 0;
  color: #526070;
  font-size: 0.8125rem;
}

.entity-search-panel__states {
  display: inline-flex;
  flex: 0 0 auto;
  flex-wrap: wrap;
  justify-content: flex-end;
  gap: 0.35rem;
}

.entity-search-panel__state {
  display: inline-flex;
  align-items: center;
  min-height: 1.45rem;
  padding: 0.15rem 0.5rem;
  border: 1px solid #d7dee8;
  border-radius: 999px;
  background: #f8fafc;
  color: #526070;
  font-size: 0.75rem;
  font-weight: 700;
  line-height: 1.1;
  white-space: nowrap;
}

.entity-search-panel__state.is-selected {
  border-color: #b8d3f7;
  background: #eef6ff;
  color: #0b5cad;
}

@media (max-width: 575.98px) {
  .entity-search-panel__header {
    display: grid;
  }

  .entity-search-panel__states {
    justify-content: flex-start;
  }

  .entity-search-panel__state {
    width: fit-content;
  }
}
</style>
