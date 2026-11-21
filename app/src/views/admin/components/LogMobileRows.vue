<template>
  <MobileTableList :items="items" label="Logs" empty-text="No logs found." :item-key="rowKey">
    <template #default="{ item }">
      <article class="mobile-record-row log-mobile-row" role="listitem">
        <div class="mobile-record-row__topline">
          <div class="mobile-record-row__chips">
            <span class="mobile-record-row__chip">#{{ displayValue(item.id) }}</span>
            <span class="mobile-record-row__chip">
              <i class="bi bi-arrow-left-right" aria-hidden="true" />
              <span>{{ displayValue(item.request_method) }}</span>
            </span>
            <span class="mobile-record-row__chip">
              <i class="bi bi-reception-4" aria-hidden="true" />
              <span>{{ displayValue(item.status) }}</span>
            </span>
          </div>
          <button
            type="button"
            class="log-mobile-row__action"
            :aria-label="`View log ${displayValue(item.id)} details`"
            @click="$emit('view', item)"
          >
            <i class="bi bi-eye" aria-hidden="true" />
          </button>
        </div>

        <div class="log-mobile-row__path">
          {{ displayValue(item.path) }}{{ displayValue(item.query) }}
        </div>

        <div class="mobile-record-row__chips" aria-label="Log metadata">
          <span v-if="hasValue(item.duration)" class="mobile-record-row__chip">
            <i class="bi bi-stopwatch" aria-hidden="true" />
            <span>{{ formatDuration(item.duration) }}</span>
          </span>
          <span v-if="hasValue(item.address)" class="mobile-record-row__chip">
            <i class="bi bi-pc-display" aria-hidden="true" />
            <span>{{ displayValue(item.address) }}</span>
          </span>
          <span v-if="hasValue(item.timestamp)" class="mobile-record-row__chip">
            <i class="bi bi-clock" aria-hidden="true" />
            <span>{{ formatRelativeTime(item.timestamp) }}</span>
          </span>
        </div>
      </article>
    </template>
  </MobileTableList>
</template>

<script setup lang="ts">
import MobileTableList from '@/components/table/MobileTableList.vue';
import { formatLogDuration, formatRelativeLogTime } from '@/components/tables/logTableFormatters';

type Item = Record<string, unknown>;

defineProps<{
  items: Item[];
}>();

defineEmits<{
  (e: 'view', item: Item): void;
}>();

function hasValue(value: unknown): boolean {
  return value !== null && value !== undefined && value !== '';
}

function displayValue(value: unknown): string {
  return hasValue(value) ? String(value) : '';
}

function rowKey(item: Item, index: number): string {
  return displayValue(item.id) || `row-${index}`;
}

// Row values arrive untyped from the API (seconds and naive UTC strings).
const formatDuration = (value: unknown) => formatLogDuration(value as string | number | null);
const formatRelativeTime = (value: unknown) => formatRelativeLogTime(value as string | null);
</script>

<style scoped>
.log-mobile-row__path {
  margin-top: 0.45rem;
  color: #0f172a;
  font-family:
    'SFMono-Regular', Menlo, Monaco, Consolas, 'Liberation Mono', 'Courier New', monospace;
  font-size: 0.8125rem;
  font-weight: 700;
  overflow-wrap: anywhere;
}

.log-mobile-row__action {
  display: inline-flex;
  flex: 0 0 auto;
  align-items: center;
  justify-content: center;
  width: 1.85rem;
  height: 1.85rem;
  border: 1px solid rgba(13, 110, 253, 0.35);
  border-radius: 0.375rem;
  background: #fff;
  color: #0d6efd;
}
</style>
