<template>
  <BRow class="entity-ontology-grid">
    <BCol cols="12" class="mb-2">
      <SectionCard
        :loading="mappings.loading.value"
        :empty="!mappings.loading.value && !mappings.error.value && mappings.data.value === null"
        :error="mappings.error.value ? mappings.error.value.message : null"
        title="Linked disease ontologies"
        min-height="4rem"
      >
        <div class="entity-ontology-panel">
          <LinkedOntologies
            layout="card"
            :data="mappings.data.value"
            :loading="mappings.loading.value"
          />
        </div>
      </SectionCard>
    </BCol>
  </BRow>
</template>

<script setup lang="ts">
// "Linked disease ontologies" detail-page card. Extracted from EntityView.vue
// (which is over the 600-line ceiling) so the cohesive ontology unit owns its
// own hook, markup, and styles. Mirrors the page's one-card-per-unit pattern:
// the mapping hook fires on mount in parallel with the page's other hooks.
import { computed } from 'vue';
import SectionCard from '@/components/ui/SectionCard.vue';
import LinkedOntologies from '@/components/disease/LinkedOntologies.vue';
import { useEntityMappings } from '@/composables/useEntityMappings';

const props = defineProps<{ entityId: string | null }>();

// Re-wrap the (unwrapped) prop as a ref so the SWR hook re-fetches when the
// entity id changes.
const mappings = useEntityMappings(computed(() => props.entityId));
</script>

<style scoped>
.entity-ontology-grid {
  padding-top: 0.15rem;
}
.entity-ontology-panel {
  padding: 0.75rem;
}
</style>
