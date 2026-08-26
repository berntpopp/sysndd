<!-- views/curate/components/VariationSuggestionsTable.vue -->
<!--
  #612 Phase 6 — one page of the variation-ontology curation queue.

  Presentation only: every rule about WHICH action a row permits lives in
  `useVariationSuggestions.ts`, and the server re-derives it under a row lock
  before writing. This component asks `canConfirm` / `canDismiss` and renders
  what it is told.

  Why a row can show no action at all: an `active_unconfirmed` term the entity no
  longer serves, or a `suggested` term it does serve, can only be resolved by
  adding or removing it from a review — which is a review write. Those rows link
  out to the entity instead of offering an action that would be refused.
-->
<template>
  <div class="vsq-table-wrap">
    <table class="table vsq-table">
      <caption class="visually-hidden">
        Machine-derived variation-ontology assertions awaiting curator review
      </caption>
      <thead>
        <tr>
          <th scope="col" class="vsq-select-col">
            <span class="visually-hidden">Select</span>
          </th>
          <th scope="col">Gene</th>
          <th scope="col">Term</th>
          <th scope="col">Status</th>
          <th scope="col">Evidence</th>
          <th scope="col" class="text-end">Actions</th>
        </tr>
      </thead>
      <tbody>
        <tr v-if="rows.length === 0">
          <td colspan="6" class="vsq-empty" data-testid="variation-suggestions-empty">
            No assertions match these filters.
          </td>
        </tr>
        <tr
          v-for="row in rows"
          :key="rowKey(row)"
          :data-testid="`variation-suggestion-row-${rowKey(row)}`"
        >
          <td>
            <input
              type="checkbox"
              class="form-check-input"
              :checked="selected.includes(rowKey(row))"
              :aria-label="`Select ${row.vario_name || row.vario_id} for ${row.symbol}`"
              :data-testid="`variation-suggestion-select-${rowKey(row)}`"
              @change="$emit('toggle', row)"
            />
          </td>

          <td>
            <RouterLink :to="`/Entities/${row.entity_id}`" class="vsq-gene">
              {{ row.symbol || `Entity ${row.entity_id}` }}
            </RouterLink>
            <div v-if="row.disease_ontology_name" class="vsq-muted">
              {{ row.disease_ontology_name }}
            </div>
          </td>

          <td>
            <div class="vsq-term">{{ row.vario_name || row.vario_id }}</div>
            <div class="vsq-muted">
              {{ row.vario_id }} &middot; {{ modifierLabel(row.modifier_id) }}
            </div>
          </td>

          <td>
            <span
              class="vsq-badge"
              :class="row.state === 'suggested' ? 'vsq-badge--suggested' : 'vsq-badge--unconfirmed'"
            >
              {{ row.state === 'suggested' ? 'Suggested' : 'Needs confirmation' }}
            </span>
            <span
              v-if="row.served"
              class="vsq-badge vsq-badge--served"
              title="Currently shown on the public entity page"
              >Served</span
            >
            <span
              v-if="row.moved"
              class="vsq-badge vsq-badge--moved"
              :data-testid="`variation-suggestion-moved-${rowKey(row)}`"
              title="A curator review has since replaced the import that wrote this evidence"
              >Moved</span
            >
          </td>

          <td>
            <div class="vsq-strength">{{ strengthDisplay(row.max_strength).text }}</div>
            <ul class="vsq-evidence">
              <li v-for="(record, index) in row.evidence" :key="index">
                <span class="vsq-source">{{ sourceDisplayName(record.source_key) }}</span>
                <span v-if="record.summary" class="vsq-muted">{{ record.summary }}</span>
              </li>
            </ul>
          </td>

          <td class="text-end">
            <BButton
              v-if="canConfirm(row)"
              size="sm"
              variant="outline-success"
              :disabled="loading"
              :data-testid="`variation-suggestion-confirm-${rowKey(row)}`"
              @click="$emit('confirm', row)"
            >
              Confirm
            </BButton>
            <BButton
              v-else-if="canDismiss(row)"
              size="sm"
              variant="outline-secondary"
              :disabled="loading"
              :data-testid="`variation-suggestion-dismiss-${rowKey(row)}`"
              @click="$emit('dismiss', row)"
            >
              Dismiss
            </BButton>
            <RouterLink
              :to="`/Entities/${row.entity_id}`"
              class="btn btn-sm btn-outline-primary ms-2"
              :data-testid="`variation-suggestion-open-${rowKey(row)}`"
            >
              Open entity
            </RouterLink>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<script setup lang="ts">
import { RouterLink } from 'vue-router';

import useText from '@/composables/useText';
import {
  sourceDisplayName,
  strengthDisplay,
} from '@/views/pages/components/variationProvenance';
import type { VariationSuggestionRow } from '@/api/curate_variation';

defineProps<{
  rows: VariationSuggestionRow[];
  selected: string[];
  loading: boolean;
  rowKey: (row: VariationSuggestionRow) => string;
  canConfirm: (row: VariationSuggestionRow) => boolean;
  canDismiss: (row: VariationSuggestionRow) => boolean;
}>();

defineEmits<{
  (e: 'toggle', row: VariationSuggestionRow): void;
  (e: 'confirm', row: VariationSuggestionRow): void;
  (e: 'dismiss', row: VariationSuggestionRow): void;
}>();

const { modifier_text: modifierText } = useText();

/** `present` / `absent` — part of the assertion identity, never decoration. */
const modifierLabel = (modifierId: number): string =>
  modifierText?.[modifierId] ?? `modifier ${modifierId}`;
</script>

<style scoped>
.vsq-table-wrap {
  overflow-x: auto;
}

.vsq-table {
  margin-bottom: 0;
  font-size: 0.9rem;
}

.vsq-select-col {
  width: 2.5rem;
}

.vsq-empty {
  text-align: center;
  padding: 1.5rem 0;
  color: var(--bs-secondary-color, #6c757d);
}

.vsq-gene {
  font-weight: 600;
}

.vsq-term {
  font-weight: 600;
}

.vsq-muted {
  color: var(--bs-secondary-color, #6c757d);
  font-size: 0.82rem;
}

.vsq-strength {
  font-weight: 600;
  margin-bottom: 0.2rem;
}

.vsq-evidence {
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  gap: 0.15rem;
}

.vsq-source {
  font-weight: 600;
  margin-right: 0.35rem;
}

.vsq-badge {
  display: inline-block;
  border-radius: 0.75rem;
  padding: 0 0.5rem;
  font-size: 0.72rem;
  font-weight: 600;
  margin-right: 0.3rem;
  border: 1px solid transparent;
}

.vsq-badge--unconfirmed {
  background: var(--bs-warning-bg-subtle, #fff3cd);
  border-color: var(--bs-warning-border-subtle, #ffe69c);
  color: var(--bs-warning-text-emphasis, #664d03);
}

.vsq-badge--suggested {
  background: var(--bs-info-bg-subtle, #cff4fc);
  border-color: var(--bs-info-border-subtle, #9eeaf9);
  color: var(--bs-info-text-emphasis, #055160);
}

.vsq-badge--served {
  background: var(--bs-success-bg-subtle, #d1e7dd);
  border-color: var(--bs-success-border-subtle, #a3cfbb);
  color: var(--bs-success-text-emphasis, #0a3622);
}

.vsq-badge--moved {
  background: var(--bs-secondary-bg-subtle, #e2e3e5);
  border-color: var(--bs-secondary-border-subtle, #c4c8cb);
  color: var(--bs-secondary-text-emphasis, #2b2f32);
}
</style>
