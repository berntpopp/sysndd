<!-- app/src/views/curate/components/EntityInfoHeader.vue -->
<template>
  <div v-if="entity?.entity_id" class="entity-info-header">
    <!-- Entity Preview Card -->
    <BCard class="my-2" body-class="p-3" header-class="p-2" border-variant="info">
      <template #header>
        <h6 class="mb-0 text-start font-weight-bold d-flex align-items-center">
          <i class="bi bi-info-circle me-2" aria-hidden="true" />
          Selected Entity
          <EntityBadge
            :entity-id="entity.entity_id"
            variant="primary"
            size="md"
            class="ms-2"
          />
        </h6>
      </template>

      <BRow class="g-3">
        <BCol md="6">
          <!-- Gene with badge and HGNC link -->
          <div class="mb-2">
            <strong class="text-muted small d-block mb-1">Gene:</strong>
            <GeneBadge
              :symbol="entity.symbol || 'N/A'"
              :hgnc-id="entity.hgnc_id"
              :link-to="
                entity.hgnc_id
                  ? `https://www.genenames.org/data/gene-symbol-report/#!/hgnc_id/${entity.hgnc_id}`
                  : null
              "
              size="md"
            />
          </div>

          <!-- Disease with badge and ontology link -->
          <div class="mb-2">
            <strong class="text-muted small d-block mb-1">Disease:</strong>
            <DiseaseBadge
              :name="entity.disease_ontology_name || 'N/A'"
              :ontology-id="entity.disease_ontology_id_version"
              :link-to="
                entity.disease_ontology_id_version
                  ? `/Ontology/${entity.disease_ontology_id_version.replace(/_.+/g, '')}`
                  : null
              "
              size="md"
              :max-length="40"
            />
          </div>
        </BCol>

        <BCol md="6">
          <!-- Inheritance with icon -->
          <div class="mb-2">
            <strong class="text-muted small d-block mb-1">Inheritance:</strong>
            <BBadge variant="info" class="d-inline-flex align-items-center">
              <i class="bi bi-diagram-3 me-1" aria-hidden="true" />
              {{
                entity.hpo_mode_of_inheritance_term_name ||
                entity.hpo_mode_of_inheritance_term ||
                'N/A'
              }}
            </BBadge>
          </div>

          <!-- Category with stoplight style -->
          <div class="mb-2">
            <strong class="text-muted small d-block mb-1">Category:</strong>
            <BBadge
              :variant="(stoplightsStyle[entity.category] || 'secondary') as any"
              class="d-inline-flex align-items-center"
            >
              <i class="bi bi-stoplights me-1" aria-hidden="true" />
              {{ entity.category || 'N/A' }}
            </BBadge>
          </div>

          <!-- NDD Status with icon -->
          <div class="mb-2">
            <strong class="text-muted small d-block mb-1">NDD Status:</strong>
            <BBadge
              :variant="(nddIconStyle[entity.ndd_phenotype_word] || 'secondary') as any"
              class="d-inline-flex align-items-center"
            >
              <i
                :class="`bi bi-${nddIcon[entity.ndd_phenotype_word] || 'question'} me-1`"
                aria-hidden="true"
              />
              {{ entity.ndd_phenotype_word || 'N/A' }}
            </BBadge>
          </div>
        </BCol>
      </BRow>
    </BCard>

    <!-- Icon Legend -->
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
import IconLegend from '@/components/accessibility/IconLegend.vue';

export default defineComponent({
  name: 'EntityInfoHeader',
  components: { GeneBadge, DiseaseBadge, EntityBadge, IconLegend },
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
});
</script>
