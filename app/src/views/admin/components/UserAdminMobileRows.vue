<template>
  <MobileTableList :items="items" label="Users" empty-text="No users found." :item-key="rowKey">
    <template #default="{ item }">
      <article class="mobile-record-row user-admin-row" role="listitem">
        <div class="mobile-record-row__topline">
          <label class="user-admin-row__identity">
            <input
              type="checkbox"
              class="form-check-input"
              :checked="isSelected(item.user_id)"
              :aria-label="`Select user ${displayValue(item.user_name)}`"
              @change="$emit('toggle-select', Number(item.user_id))"
            />
            <span>
              <span class="user-admin-row__primary">{{ displayValue(item.user_name) }}</span>
              <span class="user-admin-row__secondary">{{ displayValue(item.email) }}</span>
            </span>
          </label>
          <div class="user-admin-row__actions" aria-label="User actions">
            <button
              type="button"
              class="user-admin-row__action"
              :aria-label="`Edit user ${displayValue(item.user_name)}`"
              @click="$emit('edit', item)"
            >
              <i class="bi bi-pen" aria-hidden="true" />
            </button>
            <button
              type="button"
              class="user-admin-row__action user-admin-row__action--delete"
              :aria-label="`Delete user ${displayValue(item.user_name)}`"
              @click="$emit('delete', item)"
            >
              <i class="bi bi-x" aria-hidden="true" />
            </button>
          </div>
        </div>

        <div class="mobile-record-row__chips" aria-label="User metadata">
          <span v-if="hasValue(item.user_role)" class="mobile-record-row__chip">
            <i class="bi bi-shield-check" aria-hidden="true" />
            <span>{{ displayValue(item.user_role) }}</span>
          </span>
          <span class="mobile-record-row__chip">
            <i
              :class="approved(item.approved) ? 'bi bi-check-circle-fill' : 'bi bi-clock-fill'"
              aria-hidden="true"
            />
            <span>{{ approved(item.approved) ? 'Approved' : 'Pending' }}</span>
          </span>
          <span v-if="hasValue(item.abbreviation)" class="mobile-record-row__chip">
            <i class="bi bi-person-vcard" aria-hidden="true" />
            <span>{{ displayValue(item.abbreviation) }}</span>
          </span>
          <span v-if="hasValue(item.created_at)" class="mobile-record-row__chip">
            <i class="bi bi-calendar3" aria-hidden="true" />
            <span>{{ formatDate(item.created_at) }}</span>
          </span>
        </div>
      </article>
    </template>
  </MobileTableList>
</template>

<script setup lang="ts">
import MobileTableList from '@/components/table/MobileTableList.vue';

type Item = any;

const props = defineProps<{
  items: Item[];
  selectedIds: Array<number | string>;
}>();

defineEmits<{
  (e: 'toggle-select', userId: number): void;
  (e: 'edit', item: Item): void;
  (e: 'delete', item: Item): void;
}>();

function hasValue(value: unknown): boolean {
  return value !== null && value !== undefined && value !== '';
}

function displayValue(value: unknown): string {
  return hasValue(value) ? String(value) : '';
}

function rowKey(item: Item, index: number): string {
  return displayValue(item.user_id || item.user_name) || `row-${index}`;
}

function isSelected(value: unknown): boolean {
  return props.selectedIds.map(String).includes(displayValue(value));
}

function approved(value: unknown): boolean {
  return value === true || value === 1 || value === '1';
}

function formatDate(value: unknown): string {
  return displayValue(value).substring(0, 10) || '—';
}
</script>

<style scoped>
.user-admin-row__identity {
  display: inline-flex;
  align-items: flex-start;
  gap: 0.5rem;
  min-width: 0;
  margin: 0;
}

.user-admin-row__primary,
.user-admin-row__secondary {
  display: block;
  overflow-wrap: anywhere;
}

.user-admin-row__primary {
  color: #0f172a;
  font-size: 0.95rem;
  font-weight: 700;
  line-height: 1.2;
}

.user-admin-row__secondary {
  color: #64748b;
  font-size: 0.8125rem;
}

.user-admin-row__actions {
  display: inline-flex;
  flex: 0 0 auto;
  gap: 0.25rem;
}

.user-admin-row__action {
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

.user-admin-row__action--delete {
  border-color: rgba(220, 53, 69, 0.35);
  color: #dc3545;
}
</style>
