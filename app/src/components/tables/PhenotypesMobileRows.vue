<template>
  <MobileTableList :items="items" label="Phenotype-associated entity records" :item-key="rowKey">
    <template #default="{ item, index }">
      <article class="mobile-record-row" role="listitem">
        <div class="mobile-record-row__topline">
          <EntityBadge
            v-if="getText(item, 'entity_id')"
            :entity-id="getText(item, 'entity_id')"
            :link-to="`/Entities/${getText(item, 'entity_id')}`"
            size="sm"
          />
          <GeneBadge
            v-if="getText(item, 'symbol')"
            :symbol="getText(item, 'symbol')"
            :hgnc-id="getText(item, 'hgnc_id')"
            :link-to="geneLink(item)"
            size="sm"
          />
          <button
            class="btn btn-sm btn-outline-secondary mobile-record-row__toggle"
            type="button"
            :aria-expanded="expandedKey === rowKey(item) ? 'true' : 'false'"
            :aria-controls="`phenotypes-mobile-row-details-${index}`"
            @click="toggleDetails(item)"
          >
            {{ expandedKey === rowKey(item) ? 'Hide' : 'Details' }}
          </button>
        </div>

        <div class="phenotype-mobile-row__summary">
          <DiseaseBadge
            v-if="getText(item, 'disease_ontology_name')"
            :name="getText(item, 'disease_ontology_name')"
            :ontology-id="getText(item, 'disease_ontology_id_version')"
            :link-to="diseaseLink(item)"
            :max-length="42"
            size="sm"
          />
          <InheritanceBadge
            v-if="getText(item, 'hpo_mode_of_inheritance_term_name')"
            :full-name="getText(item, 'hpo_mode_of_inheritance_term_name')"
            :hpo-term="getText(item, 'hpo_mode_of_inheritance_term')"
            size="sm"
          />
        </div>

        <div class="mobile-record-row__chips">
          <span
            v-if="getText(item, 'category')"
            class="mobile-record-row__chip"
            :aria-label="`Category: ${getText(item, 'category')}`"
          >
            <CategoryIcon :category="getText(item, 'category')" size="sm" :show-title="false" />
            <span class="visually-hidden">{{ getText(item, 'category') }}</span>
          </span>
          <span
            v-if="getText(item, 'ndd_phenotype_word')"
            class="mobile-record-row__chip"
            :aria-label="`NDD: ${getText(item, 'ndd_phenotype_word')}`"
          >
            <NddIcon :status="getText(item, 'ndd_phenotype_word')" size="sm" :show-title="false" />
            <span class="visually-hidden">{{ getText(item, 'ndd_phenotype_word') }}</span>
          </span>
          <span
            v-if="getText(item, 'modifier_phenotype_id')"
            class="mobile-record-row__chip"
            :aria-label="`Phenotype: ${getText(item, 'modifier_phenotype_id')}`"
            :title="getText(item, 'modifier_phenotype_id')"
          >
            {{ phenotypeSummary(item) }}
          </span>
        </div>

        <dl
          v-if="expandedKey === rowKey(item)"
          :id="`phenotypes-mobile-row-details-${index}`"
          class="mobile-record-row__details"
        >
          <dt>HGNC</dt>
          <dd>{{ getText(item, 'hgnc_id') || '-' }}</dd>
          <dt>Ontology</dt>
          <dd>{{ getText(item, 'disease_ontology_id_version') || '-' }}</dd>
          <dt>Entry date</dt>
          <dd>{{ getText(item, 'entry_date') || '-' }}</dd>
          <dt>Phenotype</dt>
          <dd>{{ getText(item, 'modifier_phenotype_id') || '-' }}</dd>
        </dl>
      </article>
    </template>
  </MobileTableList>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue';
import MobileTableList from '@/components/table/MobileTableList.vue';
import CategoryIcon from '@/components/ui/CategoryIcon.vue';
import DiseaseBadge from '@/components/ui/DiseaseBadge.vue';
import EntityBadge from '@/components/ui/EntityBadge.vue';
import GeneBadge from '@/components/ui/GeneBadge.vue';
import InheritanceBadge from '@/components/ui/InheritanceBadge.vue';
import NddIcon from '@/components/ui/NddIcon.vue';

type PhenotypeEntityRow = Record<string, unknown>;

const props = defineProps<{
  items: PhenotypeEntityRow[];
}>();

const expandedKey = ref<string | null>(null);

watch(
  () => props.items,
  (items) => {
    if (expandedKey.value && !items.some((item) => rowKey(item) === expandedKey.value)) {
      expandedKey.value = null;
    }
  }
);

function toggleDetails(item: PhenotypeEntityRow) {
  const key = rowKey(item);
  expandedKey.value = expandedKey.value === key ? null : key;
}

function rowKey(item: PhenotypeEntityRow): string {
  return (
    getText(item, 'entity_id') ||
    `${getText(item, 'symbol')}-${getText(item, 'modifier_phenotype_id')}`
  );
}

function geneLink(item: PhenotypeEntityRow): string | undefined {
  const hgncId = getText(item, 'hgnc_id');
  return hgncId ? `/Genes/${hgncId}` : undefined;
}

function diseaseLink(item: PhenotypeEntityRow): string | undefined {
  const ontologyId = getText(item, 'disease_ontology_id_version');
  return ontologyId ? `/Ontology/${ontologyId.replace(/_.+/g, '')}` : undefined;
}

function phenotypeSummary(item: PhenotypeEntityRow): string {
  const ids = getText(item, 'modifier_phenotype_id')
    .split(',')
    .map((id) => id.trim())
    .filter(Boolean);

  if (ids.length <= 2) {
    return ids.join(', ');
  }

  return `${ids.slice(0, 2).join(', ')} +${ids.length - 2}`;
}

function getText(item: PhenotypeEntityRow, key: string): string {
  const value = item[key];
  return typeof value === 'string' || typeof value === 'number' ? String(value) : '';
}
</script>

<style scoped>
.phenotype-mobile-row__summary {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem;
  margin-top: 0.5rem;
}
</style>
