<template>
  <MobileTableList :items="items" label="Genes" empty-text="No genes found." :item-key="rowKey">
    <template #default="{ item, index }">
      <article class="mobile-record-row" role="listitem">
        <div class="mobile-record-row__topline">
          <div class="mobile-record-row__chips">
            <GeneBadge
              v-if="hasValue(item.symbol)"
              :symbol="displayValue(item.symbol)"
              :hgnc-id="displayValue(item.hgnc_id)"
              :link-to="geneLink(item)"
              size="sm"
            />
            <span v-else class="mobile-record-row__fallback">Unknown gene</span>
            <span class="mobile-record-row__chip">{{ entityCountLabel(item) }}</span>
          </div>

          <button
            type="button"
            class="mobile-record-row__details-button"
            :aria-expanded="isExpanded(rowKey(item, index)) ? 'true' : 'false'"
            :aria-controls="`genes-mobile-row-details-${index}`"
            @click="toggleDetails(rowKey(item, index))"
          >
            {{ isExpanded(rowKey(item, index)) ? 'Hide' : 'Details' }}
          </button>
        </div>

        <div class="mobile-record-row__chips" aria-label="Aggregated gene statuses">
          <span
            v-for="inheritance in uniqueInheritance(item)"
            :key="inheritance.name"
            data-testid="inheritance-status"
          >
            <InheritanceBadge
              :full-name="inheritance.name"
              :hpo-term="inheritance.term"
              size="sm"
            />
          </span>

          <span
            v-for="category in uniqueCategories(item)"
            :key="category"
            data-testid="category-status"
            class="mobile-record-row__chip"
            :title="`Category: ${category}`"
          >
            <CategoryIcon :category="category" size="sm" :show-title="false" />
            <span>{{ category }}</span>
          </span>

          <span
            v-for="status in uniqueNddStatuses(item)"
            :key="status"
            data-testid="ndd-status"
            class="mobile-record-row__chip"
            :title="nddLabel(status)"
          >
            <NddIcon :status="status" size="sm" :show-title="false" />
            <span>{{ nddLabel(status) }}</span>
          </span>
        </div>

        <div
          v-if="isExpanded(rowKey(item, index))"
          :id="`genes-mobile-row-details-${index}`"
          class="mobile-record-row__details genes-mobile-row__entities"
        >
          <dl
            v-for="(entity, entityIndex) in entities(item)"
            :key="entityKey(entity, entityIndex)"
            class="genes-mobile-row__entity"
          >
            <div class="mobile-record-row__detail mobile-record-row__detail--full">
              <dt>Entity</dt>
              <dd>
                <EntityBadge
                  v-if="hasValue(entity.entity_id)"
                  :entity-id="badgeId(entity.entity_id)"
                  :link-to="`/Entities/${displayValue(entity.entity_id)}`"
                  size="sm"
                />
                <span v-else>Unknown entity</span>
              </dd>
            </div>
            <div v-if="hasValue(entity.disease_ontology_name)" class="mobile-record-row__detail">
              <dt>Disease</dt>
              <dd>
                <DiseaseBadge
                  :name="displayValue(entity.disease_ontology_name)"
                  :ontology-id="displayValue(entity.disease_ontology_id_version)"
                  :link-to="diseaseLink(entity)"
                  :max-length="40"
                  size="sm"
                />
              </dd>
            </div>
            <div
              v-if="hasValue(entity.hpo_mode_of_inheritance_term_name)"
              class="mobile-record-row__detail"
            >
              <dt>Inheritance</dt>
              <dd>{{ displayValue(entity.hpo_mode_of_inheritance_term_name) }}</dd>
            </div>
            <div v-if="hasValue(entity.category)" class="mobile-record-row__detail">
              <dt>Category</dt>
              <dd>{{ displayValue(entity.category) }}</dd>
            </div>
            <div v-if="hasValue(entity.ndd_phenotype_word)" class="mobile-record-row__detail">
              <dt>NDD</dt>
              <dd>{{ nddLabel(entity.ndd_phenotype_word) }}</dd>
            </div>
          </dl>
        </div>
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

type Item = Record<string, unknown>;
type InheritanceStatus = {
  name: string;
  term: string;
};

const props = defineProps<{
  items: Item[];
}>();

const categories = new Set([
  'Definitive',
  'Moderate',
  'Limited',
  'Refuted',
  'not applicable',
  'not listed',
]);
const nddStatuses = new Set(['Yes', 'No']);
const expandedRows = ref<Set<string>>(new Set());

watch(
  () => props.items,
  (items) => {
    const currentKeys = new Set(items.map((item, index) => rowKey(item, index)));
    expandedRows.value = new Set([...expandedRows.value].filter((key) => currentKeys.has(key)));
  },
  { deep: false }
);

function hasValue(value: unknown): boolean {
  return value !== null && value !== undefined && value !== '';
}

function displayValue(value: unknown): string {
  return hasValue(value) ? String(value) : '';
}

function badgeId(value: unknown): string | number {
  return typeof value === 'number' ? value : displayValue(value);
}

function rowKey(item: Item, index: number): string {
  const stableValue = item.hgnc_id ?? item.symbol;
  return hasValue(stableValue) ? String(stableValue) : `row-${index}`;
}

function geneLink(item: Item): string | undefined {
  return hasValue(item.hgnc_id) ? `/Genes/${displayValue(item.hgnc_id)}` : undefined;
}

function diseaseLink(item: Item): string | undefined {
  if (!hasValue(item.disease_ontology_id_version)) {
    return undefined;
  }

  return `/Ontology/${displayValue(item.disease_ontology_id_version).replace(/_.+$/g, '')}`;
}

function entities(item: Item): Item[] {
  return Array.isArray(item.entities) ? (item.entities as Item[]) : [];
}

function entityKey(entity: Item, index: number): string {
  return hasValue(entity.entity_id) ? displayValue(entity.entity_id) : `entity-${index}`;
}

function entityCountLabel(item: Item): string {
  const count = Number(item.entities_count ?? entities(item).length);
  return `${Number.isFinite(count) ? count : 0} ${count === 1 ? 'entity' : 'entities'}`;
}

function uniqueInheritance(item: Item): InheritanceStatus[] {
  const statuses = new Map<string, InheritanceStatus>();

  for (const entity of entities(item)) {
    const name = displayValue(entity.hpo_mode_of_inheritance_term_name);
    if (!name || statuses.has(name)) {
      continue;
    }

    statuses.set(name, {
      name,
      term: displayValue(entity.hpo_mode_of_inheritance_term),
    });
  }

  return [...statuses.values()];
}

function uniqueCategories(item: Item): string[] {
  return uniqueValues(item, 'category').filter((category) => categories.has(category));
}

function uniqueNddStatuses(item: Item): string[] {
  return uniqueValues(item, 'ndd_phenotype_word').filter((status) => nddStatuses.has(status));
}

function uniqueValues(item: Item, key: string): string[] {
  return [
    ...new Set(
      entities(item)
        .map((entity) => displayValue(entity[key]))
        .filter(Boolean)
    ),
  ];
}

function nddLabel(value: unknown): string {
  return displayValue(value) === 'Yes' ? 'Associated with NDD' : 'Not associated with NDD';
}

function isExpanded(key: string): boolean {
  return expandedRows.value.has(key);
}

function toggleDetails(key: string): void {
  const nextExpandedRows = new Set(expandedRows.value);

  if (nextExpandedRows.has(key)) {
    nextExpandedRows.delete(key);
  } else {
    nextExpandedRows.add(key);
  }

  expandedRows.value = nextExpandedRows;
}
</script>

<style scoped>
.genes-mobile-row__entities {
  display: grid;
  gap: 0.75rem;
}

.genes-mobile-row__entity {
  display: grid;
  gap: 0.375rem;
  margin: 0;
  padding: 0.625rem;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 0.5rem;
  background: #f8fafc;
}
</style>
