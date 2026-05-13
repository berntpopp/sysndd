<template>
  <MobileTableList
    :items="items"
    label="Pending user applications"
    empty-text="No pending user applications."
    :item-key="rowKey"
  >
    <template #default="{ item }">
      <article class="mobile-record-row user-application-row" role="listitem">
        <div class="mobile-record-row__topline">
          <div>
            <div class="user-application-row__primary">{{ displayValue(item.user_name) }}</div>
            <div class="user-application-row__secondary">
              {{ fullName(item) }}
            </div>
          </div>
          <div class="user-application-row__actions" aria-label="Application actions">
            <button
              type="button"
              class="user-application-row__action"
              :aria-label="`Review user ${displayValue(item.user_name)}`"
              @click="$emit('review', item)"
            >
              <i class="bi bi-pencil" aria-hidden="true" />
            </button>
            <button
              type="button"
              class="user-application-row__action user-application-row__action--approve"
              :aria-label="`Approve user ${displayValue(item.user_name)}`"
              @click="$emit('approve', item)"
            >
              <i class="bi bi-check-lg" aria-hidden="true" />
            </button>
            <button
              type="button"
              class="user-application-row__action user-application-row__action--reject"
              :aria-label="`Reject user ${displayValue(item.user_name)}`"
              @click="$emit('reject', item)"
            >
              <i class="bi bi-x-lg" aria-hidden="true" />
            </button>
          </div>
        </div>

        <div class="user-application-row__secondary-line">
          <i class="bi bi-envelope" aria-hidden="true" />
          <span>{{ displayValue(item.email) }}</span>
        </div>

        <div class="mobile-record-row__chips" aria-label="Application metadata">
          <span v-if="hasValue(item.user_role)" class="mobile-record-row__chip">
            <i class="bi bi-shield-check" aria-hidden="true" />
            <span>{{ displayValue(item.user_role) }}</span>
          </span>
          <span class="mobile-record-row__chip">
            <i class="bi bi-person-plus" aria-hidden="true" />
            <span>Pending</span>
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

defineProps<{
  items: Item[];
}>();

defineEmits<{
  (e: 'review', item: Item): void;
  (e: 'approve', item: Item): void;
  (e: 'reject', item: Item): void;
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

function fullName(item: Item): string {
  return [item.first_name, item.family_name].filter(hasValue).map(String).join(' ') || 'No name';
}

function formatDate(value: unknown): string {
  return displayValue(value).substring(0, 10) || '—';
}
</script>

<style scoped>
.user-application-row__primary {
  color: #0f172a;
  font-size: 0.95rem;
  font-weight: 700;
  line-height: 1.2;
  overflow-wrap: anywhere;
}

.user-application-row__secondary,
.user-application-row__secondary-line {
  color: #64748b;
  font-size: 0.8125rem;
}

.user-application-row__secondary-line {
  display: flex;
  align-items: center;
  gap: 0.35rem;
  margin-top: 0.4rem;
  overflow-wrap: anywhere;
}

.user-application-row__actions {
  display: inline-flex;
  flex: 0 0 auto;
  gap: 0.25rem;
}

.user-application-row__action {
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

.user-application-row__action--approve {
  border-color: rgba(25, 135, 84, 0.45);
  color: #198754;
}

.user-application-row__action--reject {
  border-color: rgba(220, 53, 69, 0.35);
  color: #dc3545;
}
</style>
