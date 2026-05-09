<template>
  <MobileTableList
    :items="items"
    label="Entities"
    empty-text="No entities found."
    :item-key="rowKey"
  >
    <template #default="{ item, index }">
      <article class="entities-mobile-row" role="listitem">
        <div class="entities-mobile-row__header">
          <div class="entities-mobile-row__primary">
            <EntityBadge
              v-if="hasValue(item.entity_id)"
              :entity-id="badgeId(item.entity_id)"
              :link-to="`/Entities/${displayValue(item.entity_id)}`"
              size="sm"
            />
            <span v-else class="entities-mobile-row__fallback">Unknown entity</span>

            <GeneBadge
              v-if="hasValue(item.symbol)"
              :symbol="displayValue(item.symbol)"
              :hgnc-id="displayValue(item.hgnc_id)"
              :link-to="geneLink(item)"
              size="sm"
            />
          </div>

          <button
            type="button"
            class="entities-mobile-row__details-button"
            :aria-expanded="isExpanded(rowKey(item, index)) ? 'true' : 'false'"
            :aria-controls="`entities-mobile-row-details-${index}`"
            @click="toggleDetails(rowKey(item, index))"
          >
            {{ isExpanded(rowKey(item, index)) ? 'Hide' : 'Details' }}
          </button>
        </div>

        <div class="entities-mobile-row__secondary">
          <DiseaseBadge
            v-if="hasValue(item.disease_ontology_name)"
            :name="displayValue(item.disease_ontology_name)"
            :ontology-id="displayValue(item.disease_ontology_id_version)"
            :link-to="diseaseLink(item)"
            :max-length="40"
            size="sm"
          />
          <InheritanceBadge
            v-if="hasValue(item.hpo_mode_of_inheritance_term_name)"
            :full-name="displayValue(item.hpo_mode_of_inheritance_term_name)"
            :hpo-term="displayValue(item.hpo_mode_of_inheritance_term)"
            size="sm"
          />
        </div>

        <div class="entities-mobile-row__statuses" aria-label="Entity statuses">
          <span
            v-if="isCategory(item.category)"
            class="entities-mobile-row__status"
            :title="`Category: ${displayValue(item.category)}`"
          >
            <CategoryIcon :category="displayValue(item.category)" size="sm" :show-title="false" />
            <span>{{ displayValue(item.category) }}</span>
          </span>
          <span
            v-if="isNddStatus(item.ndd_phenotype_word)"
            class="entities-mobile-row__status"
            :title="nddLabel(item.ndd_phenotype_word)"
          >
            <NddIcon
              :status="displayValue(item.ndd_phenotype_word)"
              size="sm"
              :show-title="false"
            />
            <span>{{ nddLabel(item.ndd_phenotype_word) }}</span>
          </span>
        </div>

        <dl
          v-if="isExpanded(rowKey(item, index))"
          :id="`entities-mobile-row-details-${index}`"
          class="entities-mobile-row__details"
        >
          <div v-if="hasValue(item.hgnc_id)" class="entities-mobile-row__detail">
            <dt>HGNC</dt>
            <dd>{{ displayValue(item.hgnc_id) }}</dd>
          </div>
          <div
            v-if="hasValue(item.disease_ontology_id_version)"
            class="entities-mobile-row__detail"
          >
            <dt>Ontology ID</dt>
            <dd>{{ displayValue(item.disease_ontology_id_version) }}</dd>
          </div>
          <div v-if="hasValue(item.entry_date)" class="entities-mobile-row__detail">
            <dt>Entry date</dt>
            <dd>{{ displayValue(item.entry_date) }}</dd>
          </div>
          <div v-if="hasValue(item.synopsis)" class="entities-mobile-row__detail">
            <dt>Synopsis</dt>
            <dd>{{ displayValue(item.synopsis) }}</dd>
          </div>
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

type Item = Record<string, unknown>;

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
  const stableValue = item.entity_id ?? item.hgnc_id ?? item.symbol;
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

function isCategory(value: unknown): boolean {
  return categories.has(displayValue(value));
}

function isNddStatus(value: unknown): boolean {
  return nddStatuses.has(displayValue(value));
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
.entities-mobile-row {
  padding: 0.875rem;
  border: 1px solid rgba(15, 23, 42, 0.1);
  border-radius: 0.5rem;
  background: #fff;
}

.entities-mobile-row__header,
.entities-mobile-row__primary,
.entities-mobile-row__secondary,
.entities-mobile-row__statuses,
.entities-mobile-row__status {
  display: flex;
  align-items: center;
}

.entities-mobile-row__header {
  justify-content: space-between;
  gap: 0.75rem;
}

.entities-mobile-row__primary,
.entities-mobile-row__secondary,
.entities-mobile-row__statuses {
  flex-wrap: wrap;
  gap: 0.375rem;
  min-width: 0;
}

.entities-mobile-row__secondary,
.entities-mobile-row__statuses {
  margin-top: 0.625rem;
}

.entities-mobile-row__status {
  gap: 0.25rem;
  min-height: 1.75rem;
  padding: 0.2rem 0.45rem;
  border: 1px solid rgba(15, 23, 42, 0.12);
  border-radius: 999px;
  background: #f8fafc;
  color: #0f172a;
  font-size: 0.75rem;
  font-weight: 700;
  line-height: 1.2;
}

.entities-mobile-row__details-button {
  flex: 0 0 auto;
  min-height: 2rem;
  padding: 0.25rem 0.625rem;
  border: 1px solid #0d6efd;
  border-radius: 0.375rem;
  background: #fff;
  color: #0d6efd;
  font-size: 0.8125rem;
  font-weight: 600;
  line-height: 1.2;
}

.entities-mobile-row__details-button:hover,
.entities-mobile-row__details-button:focus {
  background: rgba(13, 110, 253, 0.08);
}

.entities-mobile-row__fallback {
  color: #475569;
  font-size: 0.875rem;
  font-weight: 700;
}

.entities-mobile-row__details {
  display: grid;
  gap: 0.375rem;
  margin: 0.875rem 0 0;
  padding-top: 0.75rem;
  border-top: 1px solid rgba(15, 23, 42, 0.08);
}

.entities-mobile-row__detail {
  display: grid;
  grid-template-columns: minmax(6.5rem, 0.8fr) minmax(0, 1.2fr);
  gap: 0.5rem;
  align-items: start;
}

.entities-mobile-row__detail dt {
  color: #475569;
  font-size: 0.75rem;
  font-weight: 700;
}

.entities-mobile-row__detail dd {
  min-width: 0;
  margin: 0;
  color: #0f172a;
  font-size: 0.8125rem;
  overflow-wrap: anywhere;
}
</style>
