<!-- components/small/GenericTableDetails.vue -->
<!--
  Fallback row-expansion detail card extracted from GenericTable.vue (issue #346).
  Renders the field-details label/value list, the long-narrative copy button, and
  owns the clipboard "Copied" state + reset-timer lifecycle. Consumers still reach
  this through GenericTable's `row-expansion` default; the `extra` slot carries
  GenericTable's `row-expansion-extra` content appended after the detail list.
-->
<template>
  <BCard class="generic-table-detail-card">
    <dl class="generic-table-detail">
      <div
        v-for="field in fieldDetails"
        :key="field.key"
        class="generic-table-detail__row"
        :class="{ 'generic-table-detail__row--long-text': isLongDetailField(field.key) }"
      >
        <dt class="generic-table-detail__label">
          {{ field.label || field.key }}
        </dt>
        <dd class="generic-table-detail__value">
          <span>{{ detailValue(row, field.key) }}</span>
          <BButton
            v-if="isCopyableDetailField(field.key, row)"
            size="sm"
            variant="outline-primary"
            class="generic-table-detail__copy-button"
            :aria-label="`Copy ${field.label || field.key}`"
            @click.stop="copyDetailValue(row, field.key)"
          >
            <i class="bi bi-clipboard" aria-hidden="true" />
            {{ copiedDetailKey === detailCopyKey(row, field.key) ? 'Copied' : 'Copy' }}
          </BButton>
        </dd>
      </div>
    </dl>
    <!-- Optional append slot: consumers can inject extra content after the detail list
         without replacing the full card (copy button and long-text class are preserved). -->
    <slot name="extra" :row="row" />
  </BCard>
</template>

<script>
import { BButton, BCard } from 'bootstrap-vue-next';

export default {
  name: 'GenericTableDetails',
  components: {
    BButton,
    BCard,
  },
  props: {
    row: {
      type: Object,
      default: () => ({}),
    },
    fieldDetails: {
      type: Array,
      default: () => [],
    },
  },
  data() {
    return {
      copiedDetailKey: null,
      copyResetTimer: null,
    };
  },
  beforeUnmount() {
    if (this.copyResetTimer) {
      window.clearTimeout(this.copyResetTimer);
      this.copyResetTimer = null;
    }
  },
  methods: {
    detailValue(row, key) {
      const value = row?.[key];
      return value === null || value === undefined || value === '' ? '—' : value;
    },
    isLongDetailField(key) {
      return /synopsis|abstract|comment|description|summary|note/i.test(String(key || ''));
    },
    isCopyableDetailField(key, row) {
      return this.isLongDetailField(key) && this.detailValue(row, key) !== '—';
    },
    detailCopyKey(row, key) {
      const rowKey = row?.entity_id ?? row?.id ?? row?.symbol ?? '';
      return `${rowKey}:${String(key || '')}`;
    },
    async copyDetailValue(row, key) {
      const value = this.detailValue(row, key);
      if (value === '—' || !navigator?.clipboard?.writeText) {
        return;
      }

      try {
        await navigator.clipboard.writeText(String(value));
        this.copiedDetailKey = this.detailCopyKey(row, key);
        if (this.copyResetTimer) {
          window.clearTimeout(this.copyResetTimer);
        }
        this.copyResetTimer = window.setTimeout(() => {
          this.copiedDetailKey = null;
          this.copyResetTimer = null;
        }, 1600);
      } catch {
        this.copiedDetailKey = null;
      }
    },
  },
};
</script>

<style scoped>
.generic-table-detail-card {
  margin: 0.5rem;
  border: 1px solid rgba(15, 23, 42, 0.1);
  border-radius: 0.5rem;
  box-shadow: none;
  text-align: left;
  white-space: normal;
}

:deep(.generic-table-detail-card .card-body) {
  white-space: normal;
}

.generic-table-detail {
  margin: 0;
  min-width: 0;
  white-space: normal;
}

.generic-table-detail__row {
  display: grid;
  grid-template-columns: minmax(10rem, max-content) minmax(0, 1fr);
  gap: 0.75rem;
  padding: 0.45rem 0;
  border-bottom: 1px solid rgba(15, 23, 42, 0.08);
  white-space: normal;
}

.generic-table-detail__row--long-text {
  grid-template-columns: 1fr;
  gap: 0.3rem;
  padding: 0.65rem 0;
}

.generic-table-detail__row:last-child {
  border-bottom: 0;
}

.generic-table-detail__label {
  margin: 0;
  color: #0f172a;
  font-weight: 700;
  text-align: left;
  white-space: nowrap;
}

.generic-table-detail__value {
  min-width: 0;
  margin: 0;
  color: #111827;
  text-align: left;
  overflow-wrap: anywhere;
  white-space: normal;
}

.generic-table-detail__row--long-text .generic-table-detail__value {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  gap: 0.5rem;
  align-items: start;
  padding: 0.65rem 0.75rem;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: 0.375rem;
  background: #f8fafc;
  line-height: 1.45;
}

.generic-table-detail__copy-button {
  display: inline-flex;
  align-items: center;
  gap: 0.25rem;
  min-height: 1.45rem;
  padding: 0.08rem 0.4rem;
  border-color: #0a58ca;
  color: #0a58ca;
  font-size: 0.72rem;
  line-height: 1;
  white-space: nowrap;
}

.generic-table-detail__copy-button:hover,
.generic-table-detail__copy-button:focus {
  border-color: #084298;
  background-color: #0a58ca;
  color: #fff;
}

@media (max-width: 575.98px) {
  .generic-table-detail__row {
    grid-template-columns: 1fr;
    gap: 0.15rem;
  }

  .generic-table-detail__label {
    white-space: normal;
  }

  .generic-table-detail__row--long-text .generic-table-detail__value {
    grid-template-columns: 1fr;
  }

  .generic-table-detail__copy-button {
    justify-self: start;
  }
}
</style>
