<template>
  <MobileTableList :items="items" label="Panel gene records" :item-key="rowKey">
    <template #default="{ item, index }">
      <article class="mobile-record-row" role="listitem">
        <div class="mobile-record-row__topline">
          <GeneBadge
            v-if="getText(item, 'symbol')"
            :symbol="getText(item, 'symbol')"
            :hgnc-id="getText(item, 'hgnc_id')"
            :link-to="geneLink(item)"
            size="sm"
          />
          <span v-if="getText(item, 'category')" class="mobile-record-row__chip">
            {{ getText(item, 'category') }}
          </span>
          <button
            class="btn btn-sm btn-outline-secondary mobile-record-row__toggle"
            type="button"
            :aria-expanded="expandedKey === rowKey(item) ? 'true' : 'false'"
            :aria-controls="detailsId(index)"
            @click="toggleDetails(item)"
          >
            {{ expandedKey === rowKey(item) ? 'Hide' : 'Details' }}
          </button>
        </div>

        <div class="mobile-record-row__chips">
          <span v-if="getText(item, 'inheritance')" class="mobile-record-row__chip">
            {{ getText(item, 'inheritance') }}
          </span>
          <span v-if="getText(item, 'hgnc_id')" class="mobile-record-row__chip">
            {{ getText(item, 'hgnc_id') }}
          </span>
          <span v-if="getText(item, 'entrez_id')" class="mobile-record-row__chip">
            Entrez {{ getText(item, 'entrez_id') }}
          </span>
        </div>

        <dl
          v-if="expandedKey === rowKey(item)"
          :id="detailsId(index)"
          class="mobile-record-row__details"
        >
          <template v-for="fieldKey in selectedFieldKeys" :key="fieldKey">
            <dt>{{ fieldLabel(fieldKey) }}</dt>
            <dd>{{ getText(item, fieldKey) || '-' }}</dd>
          </template>
        </dl>
      </article>
    </template>
  </MobileTableList>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue';
import MobileTableList from '@/components/table/MobileTableList.vue';
import GeneBadge from '@/components/ui/GeneBadge.vue';

type PanelRow = Record<string, unknown>;

const props = defineProps<{
  items: PanelRow[];
  selectedFieldKeys: string[];
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

function toggleDetails(item: PanelRow) {
  const key = rowKey(item);
  expandedKey.value = expandedKey.value === key ? null : key;
}

function rowKey(item: PanelRow): string {
  return getText(item, 'hgnc_id') || getText(item, 'symbol');
}

function detailsId(index: number): string {
  return `panels-mobile-row-details-${index}`;
}

function geneLink(item: PanelRow): string | undefined {
  const hgncId = getText(item, 'hgnc_id');
  const symbol = getText(item, 'symbol');
  return hgncId ? `/Genes/${hgncId}` : symbol ? `/Genes/${symbol}` : undefined;
}

function fieldLabel(key: string): string {
  return key.replace(/_/g, ' ').replace(/\b\w/g, (letter) => letter.toUpperCase());
}

function getText(item: PanelRow, key: string): string {
  const value = item[key];
  return typeof value === 'string' || typeof value === 'number' ? String(value) : '';
}
</script>
