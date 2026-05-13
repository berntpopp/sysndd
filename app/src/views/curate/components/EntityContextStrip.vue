<template>
  <div class="entity-context-strip" aria-label="Selected entity context">
    <GeneBadge v-if="entity?.symbol" :symbol="entity.symbol" :hgnc-id="entity.hgnc_id" size="sm" />
    <DiseaseBadge
      v-if="entity?.disease_ontology_name"
      :name="entity.disease_ontology_name"
      :ontology-id="entity.disease_ontology_id_version"
      size="sm"
      :max-length="34"
    />
    <span v-if="inheritanceName" class="entity-context-strip__item" :title="inheritanceName">
      <InheritanceBadge
        :full-name="inheritanceName"
        :hpo-term="entity?.hpo_mode_of_inheritance_term"
        size="sm"
      />
      <span>{{ inheritanceName }}</span>
    </span>
    <span v-if="entity?.category" class="entity-context-strip__item">
      <CategoryIcon
        v-if="isKnownCategory(entity.category)"
        :category="entity.category"
        size="sm"
        :show-title="false"
      />
      <span>{{ entity.category }}</span>
    </span>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import CategoryIcon from '@/components/ui/CategoryIcon.vue';
import DiseaseBadge from '@/components/ui/DiseaseBadge.vue';
import GeneBadge from '@/components/ui/GeneBadge.vue';
import InheritanceBadge from '@/components/ui/InheritanceBadge.vue';

const props = defineProps<{
  entity: Record<string, any> | null;
}>();

const inheritanceName = computed(
  () =>
    props.entity?.hpo_mode_of_inheritance_term_name ||
    props.entity?.hpo_mode_of_inheritance_term ||
    ''
);

function isKnownCategory(value: string | undefined): boolean {
  return ['Definitive', 'Moderate', 'Limited', 'Refuted', 'not applicable', 'not listed'].includes(
    value || ''
  );
}
</script>

<style scoped>
.entity-context-strip {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.35rem;
  min-width: 0;
}

.entity-context-strip__item {
  display: inline-flex;
  min-width: 0;
  max-width: 20rem;
  align-items: center;
  gap: 0.3rem;
  color: inherit;
  font-size: 0.8125rem;
  line-height: 1.2;
}

.entity-context-strip__item > span:last-child {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

@media (max-width: 575.98px) {
  .entity-context-strip__item {
    max-width: 100%;
  }
}
</style>
