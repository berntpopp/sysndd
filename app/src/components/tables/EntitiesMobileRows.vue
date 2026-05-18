<template>
  <MobileTableList
    :items="items"
    label="Entities"
    empty-text="No entities found."
    :item-key="rowKey"
  >
    <template #default="{ item, index }">
      <article class="mobile-record-row" role="listitem">
        <div class="mobile-record-row__topline">
          <div class="mobile-record-row__chips">
            <EntityBadge
              v-if="hasValue(item.entity_id)"
              :entity-id="badgeId(item.entity_id)"
              :link-to="returnLink(`/Entities/${displayValue(item.entity_id)}`)"
              size="sm"
            />
            <span v-else class="mobile-record-row__fallback">Unknown entity</span>

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
            class="mobile-record-row__details-button"
            :aria-expanded="isExpanded(rowKey(item, index)) ? 'true' : 'false'"
            :aria-controls="`entities-mobile-row-details-${index}`"
            @click="toggleDetails(rowKey(item, index))"
          >
            {{ isExpanded(rowKey(item, index)) ? 'Hide' : 'Details' }}
          </button>
        </div>

        <div class="mobile-record-row__chips" aria-label="Entity summary">
          <DiseaseBadge
            v-if="hasValue(item.disease_ontology_name)"
            :name="displayValue(item.disease_ontology_name)"
            :ontology-id="displayValue(item.disease_ontology_id_version)"
            :link-to="diseaseLink(item)"
            :max-length="28"
            size="sm"
          />
          <InheritanceBadge
            v-if="hasValue(item.hpo_mode_of_inheritance_term_name)"
            :full-name="displayValue(item.hpo_mode_of_inheritance_term_name)"
            :hpo-term="displayValue(item.hpo_mode_of_inheritance_term)"
            size="sm"
          />
          <span
            v-if="isCategory(item.category)"
            class="mobile-record-row__chip"
            :aria-label="`Category: ${displayValue(item.category)}`"
            :title="`Category: ${displayValue(item.category)}`"
          >
            <CategoryIcon :category="displayValue(item.category)" size="sm" :show-title="false" />
            <span>{{ compactCategoryLabel(item.category) }}</span>
          </span>
          <span
            v-if="isNddStatus(item.ndd_phenotype_word)"
            class="mobile-record-row__chip"
            :aria-label="nddLabel(item.ndd_phenotype_word)"
            :title="nddLabel(item.ndd_phenotype_word)"
          >
            <NddIcon
              :status="displayValue(item.ndd_phenotype_word)"
              size="sm"
              :show-title="false"
            />
            <span>{{ compactNddLabel(item.ndd_phenotype_word) }}</span>
          </span>
        </div>

        <dl
          v-if="isExpanded(rowKey(item, index))"
          :id="`entities-mobile-row-details-${index}`"
          class="mobile-record-row__details"
        >
          <div v-if="hasValue(item.hgnc_id)" class="mobile-record-row__detail">
            <dt>HGNC</dt>
            <dd>{{ displayValue(item.hgnc_id) }}</dd>
          </div>
          <div v-if="hasValue(item.disease_ontology_id_version)" class="mobile-record-row__detail">
            <dt>Ontology ID</dt>
            <dd>{{ displayValue(item.disease_ontology_id_version) }}</dd>
          </div>
          <div v-if="hasValue(item.entry_date)" class="mobile-record-row__detail">
            <dt>Entry date</dt>
            <dd>{{ displayValue(item.entry_date) }}</dd>
          </div>
          <div v-if="hasValue(item.synopsis)" class="mobile-record-row__detail">
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
import { withReturnTo } from '@/utils/returnNavigation';

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
  return hasValue(item.hgnc_id) ? returnLink(`/Genes/${displayValue(item.hgnc_id)}`) : undefined;
}

function returnLink(path: string): string {
  return withReturnTo(path);
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

function compactCategoryLabel(value: unknown): string {
  const category = displayValue(value);
  return category === 'not applicable' ? 'n/a' : category;
}

function compactNddLabel(value: unknown): string {
  return displayValue(value) === 'Yes' ? 'NDD Yes' : 'NDD No';
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
