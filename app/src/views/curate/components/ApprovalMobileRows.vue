<template>
  <MobileTableList
    :items="items"
    label="Pending approvals"
    empty-text="No pending approvals found."
    :item-key="rowKey"
  >
    <template #default="{ item, index }">
      <article class="mobile-record-row approval-mobile-row" role="listitem">
        <div class="mobile-record-row__topline">
          <div class="mobile-record-row__chips">
            <EntityBadge
              v-if="hasValue(item.entity_id)"
              :entity-id="badgeId(item.entity_id)"
              :link-to="`/Entities/${displayValue(item.entity_id)}`"
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
          <div class="approval-mobile-row__actions" aria-label="Approval actions">
            <button
              type="button"
              class="approval-mobile-row__action"
              :aria-label="`${isExpanded(rowKey(item, index)) ? 'Hide details' : 'Show details'} for entity ${displayValue(item.entity_id)}`"
              :aria-expanded="isExpanded(rowKey(item, index)) ? 'true' : 'false'"
              :aria-controls="`approval-mobile-row-details-${index}`"
              @click="toggleDetails(rowKey(item, index))"
            >
              <i class="bi bi-eye" aria-hidden="true" />
            </button>
            <button
              type="button"
              class="approval-mobile-row__action"
              :aria-label="`Edit entity ${displayValue(item.entity_id)}`"
              @click="$emit('edit', item)"
            >
              <i class="bi bi-pen" aria-hidden="true" />
            </button>
            <button
              v-if="showStatusEdit"
              type="button"
              class="approval-mobile-row__action"
              :aria-label="`Edit status for entity ${displayValue(item.entity_id)}`"
              @click="$emit('edit-status', item)"
            >
              <i class="bi bi-stoplights" aria-hidden="true" />
            </button>
            <button
              type="button"
              class="approval-mobile-row__action approval-mobile-row__action--approve"
              :aria-label="`Approve entity ${displayValue(item.entity_id)}`"
              @click="$emit('approve', item)"
            >
              <i class="bi bi-check2-circle" aria-hidden="true" />
            </button>
            <button
              type="button"
              class="approval-mobile-row__action approval-mobile-row__action--dismiss"
              :aria-label="`Dismiss entity ${displayValue(item.entity_id)}`"
              @click="$emit('dismiss', item)"
            >
              <i class="bi bi-x-circle" aria-hidden="true" />
            </button>
          </div>
        </div>

        <div class="approval-mobile-row__secondary">
          <DiseaseBadge
            v-if="hasValue(item.disease_ontology_name)"
            :name="displayValue(item.disease_ontology_name)"
            :ontology-id="displayValue(item.disease_ontology_id_version)"
            :link-to="diseaseLink(item)"
            :max-length="30"
            size="sm"
          />
          <InheritanceBadge
            v-if="hasValue(item.hpo_mode_of_inheritance_term_name)"
            :full-name="displayValue(item.hpo_mode_of_inheritance_term_name)"
            :hpo-term="displayValue(item.hpo_mode_of_inheritance_term)"
            size="sm"
          />
        </div>

        <div class="mobile-record-row__chips" aria-label="Approval metadata">
          <span v-if="hasValue(item.category)" class="mobile-record-row__chip">
            <CategoryIcon :category="displayValue(item.category)" size="sm" :show-title="false" />
            <span>{{ displayValue(item.category) }}</span>
          </span>
          <span v-if="hasValue(item[roleField])" class="mobile-record-row__chip">
            <i class="bi bi-shield-check" aria-hidden="true" />
            <span>{{ displayValue(item[roleField]) }}</span>
          </span>
          <span v-if="hasValue(item[userField])" class="mobile-record-row__chip">
            <i class="bi bi-person" aria-hidden="true" />
            <span>{{ displayValue(item[userField]) }}</span>
          </span>
          <span v-if="hasValue(item[dateField])" class="mobile-record-row__chip">
            <i class="bi bi-calendar3" aria-hidden="true" />
            <span>{{ formatDate(item[dateField]) }}</span>
          </span>
        </div>

        <dl
          v-if="isExpanded(rowKey(item, index))"
          :id="`approval-mobile-row-details-${index}`"
          class="mobile-record-row__details"
        >
          <div v-if="hasValue(item.comment)" class="mobile-record-row__detail">
            <dt>Comment</dt>
            <dd>{{ displayValue(item.comment) }}</dd>
          </div>
          <div v-if="hasValue(item.synopsis)" class="mobile-record-row__detail">
            <dt>Synopsis</dt>
            <dd>{{ displayValue(item.synopsis) }}</dd>
          </div>
          <div v-if="hasValue(item.status_id)" class="mobile-record-row__detail">
            <dt>Status ID</dt>
            <dd>{{ displayValue(item.status_id) }}</dd>
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

type Item = any;

const props = withDefaults(
  defineProps<{
    items: Item[];
    userField?: string;
    roleField?: string;
    dateField?: string;
    showStatusEdit?: boolean;
  }>(),
  {
    userField: 'review_user_name',
    roleField: 'review_user_role',
    dateField: 'review_date',
    showStatusEdit: false,
  }
);

defineEmits<{
  (e: 'edit', item: Item): void;
  (e: 'edit-status', item: Item): void;
  (e: 'approve', item: Item): void;
  (e: 'dismiss', item: Item): void;
}>();

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
  const stableValue = item.status_id ?? item.review_id ?? item.entity_id ?? item.symbol;
  return hasValue(stableValue) ? String(stableValue) : `row-${index}`;
}

function geneLink(item: Item): string | undefined {
  return hasValue(item.hgnc_id) ? `/Genes/${displayValue(item.hgnc_id)}` : undefined;
}

function diseaseLink(item: Item): string | undefined {
  if (!hasValue(item.disease_ontology_id_version)) return undefined;
  return `/Ontology/${displayValue(item.disease_ontology_id_version).replace(/_.+$/g, '')}`;
}

function formatDate(value: unknown): string {
  return displayValue(value).substring(0, 10) || '—';
}

function isExpanded(key: string): boolean {
  return expandedRows.value.has(key);
}

function toggleDetails(key: string): void {
  const next = new Set(expandedRows.value);
  if (next.has(key)) next.delete(key);
  else next.add(key);
  expandedRows.value = next;
}
</script>

<style scoped>
.approval-mobile-row__secondary {
  display: flex;
  flex-wrap: wrap;
  gap: 0.375rem;
  margin-top: 0.4rem;
}

.approval-mobile-row__actions {
  display: inline-flex;
  flex: 0 0 auto;
  gap: 0.25rem;
}

.approval-mobile-row__action {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 1.85rem;
  height: 1.85rem;
  border: 1px solid rgba(15, 23, 42, 0.14);
  border-radius: 0.375rem;
  background: #fff;
  color: #334155;
}

.approval-mobile-row__action--approve {
  border-color: rgba(25, 135, 84, 0.45);
  color: #198754;
}

.approval-mobile-row__action--dismiss {
  border-color: rgba(220, 53, 69, 0.35);
  color: #dc3545;
}
</style>
