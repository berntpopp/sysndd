<template>
  <MobileTableList :items="items" label="Backups" empty-text="No backups found." :item-key="rowKey">
    <template #default="{ item }">
      <article class="mobile-record-row backup-mobile-row" role="listitem">
        <div class="mobile-record-row__topline">
          <div class="backup-mobile-row__identity">
            <span class="backup-mobile-row__filename">{{ displayValue(item.filename) }}</span>
            <span class="backup-mobile-row__created">{{ formatDate(displayValue(item.created_at)) }}</span>
          </div>
          <div class="backup-mobile-row__actions" aria-label="Backup actions">
            <button
              type="button"
              class="backup-mobile-row__action"
              :aria-label="`Download backup ${displayValue(item.filename)}`"
              @click="emitDownload(item)"
            >
              <i class="bi bi-download" aria-hidden="true" />
            </button>
            <button
              type="button"
              class="backup-mobile-row__action backup-mobile-row__action--restore"
              :aria-label="`Restore backup ${displayValue(item.filename)}`"
              @click="emitRestore(item)"
            >
              <i class="bi bi-arrow-counterclockwise" aria-hidden="true" />
            </button>
            <button
              type="button"
              class="backup-mobile-row__action backup-mobile-row__action--delete"
              :aria-label="`Delete backup ${displayValue(item.filename)}`"
              @click="emitDelete(item)"
            >
              <i class="bi bi-trash" aria-hidden="true" />
            </button>
          </div>
        </div>

        <div class="mobile-record-row__chips" aria-label="Backup metadata">
          <span v-if="getBackupType(displayValue(item.filename))" class="mobile-record-row__chip">
            <i class="bi bi-archive" aria-hidden="true" />
            <span>{{ getBackupType(displayValue(item.filename)) }}</span>
          </span>
          <span class="mobile-record-row__chip">
            <i class="bi bi-hdd" aria-hidden="true" />
            <span>{{ formatFileSize(Number(item.size_bytes) || 0) }}</span>
          </span>
          <span v-if="hasValue(item.table_count)" class="mobile-record-row__chip">
            <i class="bi bi-table" aria-hidden="true" />
            <span>{{ displayValue(item.table_count) }} tables</span>
          </span>
        </div>
      </article>
    </template>
  </MobileTableList>
</template>

<script setup lang="ts">
import MobileTableList from '@/components/table/MobileTableList.vue';
import {
  formatFileSize,
  formatDate,
  getBackupType,
} from '../composables/useBackupInventory';

interface Item extends Record<string, unknown> {
  filename: string;
  size_bytes: number;
  created_at: string;
  table_count: number | null;
}

defineProps<{
  items: Item[];
}>();

const emit = defineEmits<{
  (e: 'download', item: Item): void;
  (e: 'restore', item: Item): void;
  (e: 'delete', item: Item): void;
}>();

function hasValue(value: unknown): boolean {
  return value !== null && value !== undefined && value !== '';
}

function displayValue(value: unknown): string {
  return hasValue(value) ? String(value) : '';
}

function rowKey(item: Record<string, unknown>, index: number): string {
  return displayValue(item.filename) || `row-${index}`;
}

function emitDownload(item: Record<string, unknown>): void {
  emit('download', item as Item);
}

function emitRestore(item: Record<string, unknown>): void {
  emit('restore', item as Item);
}

function emitDelete(item: Record<string, unknown>): void {
  emit('delete', item as Item);
}
</script>

<style scoped>
.backup-mobile-row__identity {
  min-width: 0;
}

.backup-mobile-row__filename,
.backup-mobile-row__created {
  display: block;
  overflow-wrap: anywhere;
}

.backup-mobile-row__filename {
  color: #0f172a;
  font-family:
    'SFMono-Regular', Menlo, Monaco, Consolas, 'Liberation Mono', 'Courier New', monospace;
  font-size: 0.8125rem;
  font-weight: 700;
}

.backup-mobile-row__created {
  color: #64748b;
  font-size: 0.75rem;
}

.backup-mobile-row__actions {
  display: inline-flex;
  flex: 0 0 auto;
  gap: 0.25rem;
}

.backup-mobile-row__action {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 1.85rem;
  height: 1.85rem;
  border: 1px solid rgba(15, 23, 42, 0.14);
  border-radius: 0.375rem;
  background: #fff;
  color: #0d6efd;
}

.backup-mobile-row__action--restore {
  border-color: rgba(255, 193, 7, 0.45);
  color: #997404;
}

.backup-mobile-row__action--delete {
  border-color: rgba(220, 53, 69, 0.35);
  color: #dc3545;
}
</style>
