<!-- app/src/views/curate/components/EntityInfoHeader.vue -->
<template>
  <div v-if="entity?.entity_id" class="entity-info-header">
    <section class="entity-info-header__summary" aria-label="Selected entity summary">
      <div class="entity-info-header__unit-grid">
        <div class="entity-info-header__unit entity-info-header__unit--gene">
          <span class="entity-info-header__label">Gene</span>
          <GeneBadge
            :symbol="entity.symbol || 'N/A'"
            :hgnc-id="entity.hgnc_id"
            :link-to="
              entity.hgnc_id
                ? `https://www.genenames.org/data/gene-symbol-report/#!/hgnc_id/${entity.hgnc_id}`
                : undefined
            "
            size="md"
          />
        </div>
        <div class="entity-info-header__unit entity-info-header__unit--inheritance">
          <span class="entity-info-header__label">Inheritance</span>
          <InheritanceBadge
            v-if="entity.hpo_mode_of_inheritance_term_name || entity.hpo_mode_of_inheritance_term"
            :full-name="
              entity.hpo_mode_of_inheritance_term_name || entity.hpo_mode_of_inheritance_term
            "
            :hpo-term="entity.hpo_mode_of_inheritance_term"
            size="sm"
          />
        </div>
        <div class="entity-info-header__unit entity-info-header__unit--disease">
          <span class="entity-info-header__label">Disease</span>
          <DiseaseBadge
            :name="entity.disease_ontology_name || 'N/A'"
            :ontology-id="entity.disease_ontology_id_version"
            :link-to="
              entity.disease_ontology_id_version
                ? `/Ontology/${entity.disease_ontology_id_version.replace(/_.+/g, '')}`
                : undefined
            "
            size="md"
            :max-length="0"
          />
        </div>
      </div>

      <div class="entity-info-header__metadata">
        <EntityBadge :entity-id="entity.entity_id" variant="primary" size="sm" />
        <span class="entity-info-header__meta-item">
          <span class="entity-info-header__classification-label">Classification</span>
          <CategoryIcon
            v-if="isKnownCategory(entity.category)"
            :category="entity.category"
            size="sm"
            :show-title="false"
          />
          <span>{{ entity.category || 'N/A' }}</span>
        </span>
        <span class="entity-info-header__meta-item">
          <i
            :class="`bi bi-${nddIcon[entity.ndd_phenotype_word] || 'question'} entity-info-header__status-icon`"
            aria-hidden="true"
          />
          <span>NDD {{ entity.ndd_phenotype_word || 'N/A' }}</span>
        </span>
      </div>
    </section>

    <IconLegend
      v-if="legendItems && legendItems.length"
      :legend-items="legendItems"
      title="Category & NDD Status Icons"
      class="my-2"
    />
  </div>
</template>

<script lang="ts">
import { defineComponent, type PropType } from 'vue';
import GeneBadge from '@/components/ui/GeneBadge.vue';
import DiseaseBadge from '@/components/ui/DiseaseBadge.vue';
import EntityBadge from '@/components/ui/EntityBadge.vue';
import CategoryIcon from '@/components/ui/CategoryIcon.vue';
import InheritanceBadge from '@/components/ui/InheritanceBadge.vue';
import IconLegend from '@/components/accessibility/IconLegend.vue';

export default defineComponent({
  name: 'EntityInfoHeader',
  components: { GeneBadge, DiseaseBadge, EntityBadge, CategoryIcon, InheritanceBadge, IconLegend },
  props: {
    entity: {
      type: Object as PropType<Record<string, any> | null>,
      default: null,
    },
    legendItems: {
      type: Array as PropType<Array<{ icon: string; color: string; label: string }>>,
      default: () => [],
    },
    stoplightsStyle: {
      type: Object as PropType<Record<string, string>>,
      default: () => ({}),
    },
    nddIconStyle: {
      type: Object as PropType<Record<string, string>>,
      default: () => ({}),
    },
    nddIcon: {
      type: Object as PropType<Record<string, string>>,
      default: () => ({}),
    },
  },
  methods: {
    isKnownCategory(value: string | undefined): boolean {
      return [
        'Definitive',
        'Moderate',
        'Limited',
        'Refuted',
        'not applicable',
        'not listed',
      ].includes(value || '');
    },
  },
});
</script>

<style scoped>
.entity-info-header {
  display: grid;
  gap: 0.75rem;
}

.entity-info-header__summary {
  display: grid;
  gap: 0.5rem;
  padding: 0.65rem 0.75rem;
  border-bottom: 1px solid #e6ebf2;
}

.entity-info-header__unit-grid {
  display: grid;
  grid-template-columns: minmax(10rem, 0.85fr) minmax(8rem, 0.55fr) minmax(16rem, 1.55fr);
  gap: 0.5rem;
}

.entity-info-header__unit {
  display: flex;
  min-width: 0;
  align-items: center;
  gap: 0.45rem;
  padding: 0.4rem 0.5rem;
  border: 1px solid #dbe2ea;
  border-radius: 0.45rem;
  background: #f8fafc;
}

.entity-info-header__unit--gene {
  border-left: 0.25rem solid #0f8f51;
}

.entity-info-header__unit--inheritance {
  border-left: 0.25rem solid #09a9c9;
}

.entity-info-header__unit--disease {
  border-left: 0.25rem solid #65717d;
}

.entity-info-header__label,
.entity-info-header__classification-label {
  color: #667085;
  font-size: 0.68rem;
  font-weight: 800;
  letter-spacing: 0.04em;
  text-transform: uppercase;
}

.entity-info-header__unit :deep(.disease-badge-link),
.entity-info-header__unit :deep(.disease-badge) {
  min-width: 0;
  max-width: 100%;
}

.entity-info-header__metadata {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.45rem;
}

.entity-info-header__meta-item {
  display: inline-flex;
  align-items: center;
  gap: 0.35rem;
  box-sizing: border-box;
  height: 1.55rem;
  padding: 0.12rem 0.48rem;
  border: 1px solid #d5dbe3;
  border-radius: 999px;
  background: #f8fafc;
  color: #344054;
  font-size: 0.78rem;
  font-weight: 650;
  line-height: 1;
  white-space: nowrap;
}

.entity-info-header__meta-item:first-of-type {
  border-color: #9fd7c4;
  background: #e8f8f1;
  color: #064e3b;
  font-weight: 800;
}

.entity-info-header__status-icon {
  color: #009e73;
  font-size: 1.1rem;
}

@media (max-width: 575.98px) {
  .entity-info-header__unit-grid {
    grid-template-columns: 1fr;
  }
}
</style>
