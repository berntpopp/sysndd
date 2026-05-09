<template>
  <MobileTableList
    :items="items"
    label="Curation comparison genes"
    empty-text="No curation comparison genes found."
    item-key="symbol"
  >
    <template #default="{ item, index }">
      <article class="curation-mobile-row" role="listitem">
        <div class="curation-mobile-row__header">
          <h3 class="curation-mobile-row__symbol">
            <a
              v-if="geneHref(item)"
              class="curation-mobile-row__symbol-link"
              :href="geneHref(item)"
            >
              {{ displayValue(item.symbol) }}
            </a>
            <span v-else>{{ displayValue(item.symbol) }}</span>
          </h3>
          <button
            type="button"
            class="curation-mobile-row__details-button"
            :aria-expanded="isExpanded(rowKey(item, index)) ? 'true' : 'false'"
            :aria-controls="`curation-mobile-row-details-${index}`"
            @click="toggleDetails(rowKey(item, index))"
          >
            {{ isExpanded(rowKey(item, index)) ? 'Hide details' : 'Details' }}
          </button>
        </div>

        <div class="curation-mobile-row__sources" aria-label="Source presence">
          <span
            v-for="source in sources"
            :key="source.key"
            data-testid="source-chip"
            class="curation-mobile-row__source-chip"
            :class="{
              'curation-mobile-row__source-chip--present': isPresent(item[source.key]),
              'curation-mobile-row__source-chip--absent': !isPresent(item[source.key]),
            }"
            :aria-label="sourceTitle(source.label, item[source.key])"
            :data-state="isPresent(item[source.key]) ? 'present' : 'absent'"
            :title="sourceTitle(source.label, item[source.key])"
          >
            <span class="curation-mobile-row__source-state" aria-hidden="true">
              {{ isPresent(item[source.key]) ? '+' : '-' }}
            </span>
            <span>{{ source.short }}</span>
          </span>
        </div>

        <dl
          v-if="isExpanded(rowKey(item, index))"
          :id="`curation-mobile-row-details-${index}`"
          class="curation-mobile-row__details"
        >
          <div v-for="source in sources" :key="source.key" class="curation-mobile-row__detail">
            <dt>{{ source.label }}</dt>
            <dd>{{ sourceDisplayValue(item[source.key]) }}</dd>
          </div>
        </dl>
      </article>
    </template>
  </MobileTableList>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue';
import MobileTableList from '@/components/table/MobileTableList.vue';

type Item = Record<string, unknown>;

const props = defineProps<{
  items: Item[];
}>();

const sources = [
  { key: 'SysNDD', label: 'SysNDD', short: 'S' },
  { key: 'gene2phenotype', label: 'Gene2Phenotype', short: 'G2P' },
  { key: 'panelapp', label: 'PanelApp', short: 'PA' },
  { key: 'radboudumc_ID', label: 'Radboudumc', short: 'R' },
  { key: 'sfari', label: 'SFARI', short: 'SF' },
  { key: 'geisinger_DBD', label: 'Geisinger DBD', short: 'DBD' },
  { key: 'orphanet_id', label: 'Orphanet', short: 'OR' },
  { key: 'omim_ndd', label: 'OMIM NDD', short: 'OMIM' },
] as const;

const negativeMarkers = new Set(['', 'not listed', 'no', 'false', 'null', 'undefined']);
const expandedRows = ref<Set<string>>(new Set());

watch(
  () => props.items,
  (items) => {
    const currentKeys = new Set(items.map((item, index) => rowKey(item, index)));
    expandedRows.value = new Set([...expandedRows.value].filter((key) => currentKeys.has(key)));
  },
  { deep: false }
);

function isPresent(value: unknown): boolean {
  if (value === null || value === undefined || value === false) {
    return false;
  }

  if (typeof value === 'string') {
    return !negativeMarkers.has(value.trim().toLowerCase());
  }

  return true;
}

function displayValue(value: unknown): string {
  if (value === null || value === undefined || value === '') {
    return 'Unknown gene';
  }

  return String(value);
}

function geneHref(item: Item): string | undefined {
  const hgncId = item.hgnc_id;

  if (hgncId === null || hgncId === undefined || hgncId === '') {
    return undefined;
  }

  return `/Genes/${String(hgncId)}`;
}

function rowKey(item: Item, index: number): string {
  const stableValue = item.hgnc_id ?? item.symbol;

  if (stableValue === null || stableValue === undefined || stableValue === '') {
    return `row-${index}`;
  }

  return String(stableValue);
}

function sourceDisplayValue(value: unknown): string {
  return isPresent(value) ? String(value) : 'Not present';
}

function sourceTitle(label: string, value: unknown): string {
  return `${label}: ${sourceDisplayValue(value)}`;
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
.curation-mobile-row {
  padding: 0.875rem;
  border: 1px solid rgba(15, 23, 42, 0.1);
  border-radius: 0.5rem;
  background: #fff;
}

.curation-mobile-row__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
}

.curation-mobile-row__symbol {
  margin: 0;
  font-size: 1rem;
  font-weight: 700;
  line-height: 1.25;
}

.curation-mobile-row__symbol,
.curation-mobile-row__symbol-link {
  color: #0f172a;
}

.curation-mobile-row__symbol-link {
  text-decoration-thickness: 0.08em;
  text-underline-offset: 0.16em;
}

.curation-mobile-row__details-button {
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

.curation-mobile-row__details-button:hover,
.curation-mobile-row__details-button:focus {
  background: rgba(13, 110, 253, 0.08);
}

.curation-mobile-row__sources {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 0.375rem;
  margin-top: 0.75rem;
}

.curation-mobile-row__source-chip {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 0.2rem;
  min-height: 1.75rem;
  padding: 0.25rem;
  border-radius: 0.375rem;
  font-size: 0.7rem;
  font-weight: 700;
  line-height: 1;
}

.curation-mobile-row__source-state {
  font-size: 0.75rem;
  line-height: 1;
}

.curation-mobile-row__source-chip--present {
  border: 1px solid rgba(25, 135, 84, 0.35);
  background: rgba(25, 135, 84, 0.12);
  color: #0f5132;
}

.curation-mobile-row__source-chip--absent {
  border: 1px solid rgba(108, 117, 125, 0.25);
  background: #f8f9fa;
  color: #6c757d;
}

.curation-mobile-row__details {
  display: grid;
  gap: 0.375rem;
  margin: 0.875rem 0 0;
  padding-top: 0.75rem;
  border-top: 1px solid rgba(15, 23, 42, 0.08);
}

.curation-mobile-row__detail {
  display: grid;
  grid-template-columns: minmax(7rem, 0.9fr) minmax(0, 1.1fr);
  gap: 0.5rem;
  align-items: start;
}

.curation-mobile-row__detail dt {
  color: #475569;
  font-size: 0.75rem;
  font-weight: 700;
}

.curation-mobile-row__detail dd {
  min-width: 0;
  margin: 0;
  color: #0f172a;
  font-size: 0.8125rem;
  overflow-wrap: anywhere;
}
</style>
