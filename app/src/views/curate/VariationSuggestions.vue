<!-- views/curate/VariationSuggestions.vue -->
<!--
  #612 Phase 6 — the cross-entity variation-ontology curation queue.

  WHAT THIS PAGE IS FOR
  ---------------------
  The February 2026 backfill wrote 8,083 machine-derived variation-ontology
  assertions, ~1,981 of them resting on 1-star ClinVar evidence alone. Every one
  is served on a public entity page today; none has been read by a curator. Per
  entity that backlog is invisible. This page makes it a worklist.

  THE TWO ACTIONS ARE NOT SYMMETRIC — see useVariationSuggestions.ts for why.
  In short: rejecting a term the entity still SERVES would drop it out of the
  public read's provenance filter and make it render as curator-authored, which
  is the fabrication this whole feature exists to prevent. So Confirm is offered
  only for served terms and Dismiss only for unserved ones; anything else links
  out to the entity, where adding or removing a term is a review write.

  A shell: state, filters and actions live in the composable; rows render in
  VariationSuggestionsTable.vue. All HTTP goes through @/api/curate_variation.
-->
<template>
  <AuthenticatedPageShell
    title="Variation suggestions"
    content-class="authenticated-route-content"
    full-width
  >
    <BContainer fluid>
      <p class="vsq-intro">
        Machine-derived variation-ontology annotations that no curator has confirmed. Confirming
        one records that a curator read its evidence and agrees; it does not change what the
        entity publishes. Terms that need adding or removing are edited on the entity itself.
      </p>

      <TableShell
        title="Unconfirmed annotations"
        :description="tableDescription"
        :meta="metaText"
        :loading="queue.loading.value"
      >
        <template #actions>
          <div class="vsq-bulk">
            <span v-if="queue.selected.value.length > 0" class="vsq-bulk__count">
              {{ queue.selected.value.length }} selected
            </span>
            <BButton
              v-if="queue.selectionKind.value === 'confirm'"
              size="sm"
              variant="success"
              :disabled="queue.loading.value"
              data-testid="variation-suggestions-bulk-confirm"
              @click="onBulk('confirm')"
            >
              Confirm selected
            </BButton>
            <BButton
              v-else-if="queue.selectionKind.value === 'dismiss'"
              size="sm"
              variant="secondary"
              :disabled="queue.loading.value"
              data-testid="variation-suggestions-bulk-dismiss"
              @click="onBulk('dismiss')"
            >
              Dismiss selected
            </BButton>
            <span
              v-else-if="queue.selectionKind.value === 'mixed'"
              class="vsq-bulk__hint"
              data-testid="variation-suggestions-bulk-mixed"
            >
              Selected rows need different actions — select one kind at a time.
            </span>
          </div>
        </template>

        <div class="vsq-filters">
          <BFormInput
            v-model="queue.filters.value.q"
            size="sm"
            class="vsq-filters__search"
            placeholder="Gene symbol or entity id"
            aria-label="Search by gene symbol or entity id"
            data-testid="variation-suggestions-search"
            @keyup.enter="queue.applyFilters()"
          />
          <BFormSelect
            v-model="queue.filters.value.state"
            size="sm"
            :options="stateOptions"
            aria-label="Filter by state"
            data-testid="variation-suggestions-state"
            @change="queue.applyFilters()"
          />
          <BFormSelect
            v-model="queue.filters.value.max_strength"
            size="sm"
            :options="strengthOptions"
            aria-label="Filter by evidence strength"
            @change="queue.applyFilters()"
          />
          <BFormSelect
            v-model="queue.sort.value"
            size="sm"
            :options="sortOptions"
            aria-label="Sort order"
            @change="queue.applyFilters()"
          />
          <BFormCheckbox
            v-model="queue.filters.value.moved"
            switch
            data-testid="variation-suggestions-moved"
            @change="queue.applyFilters()"
          >
            Superseded imports only
          </BFormCheckbox>
          <BButton size="sm" variant="outline-secondary" @click="queue.resetFilters()">
            Reset
          </BButton>
        </div>

        <VariationSuggestionsTable
          :rows="queue.rows.value"
          :selected="queue.selected.value"
          :loading="queue.loading.value"
          :row-key="queue.rowKey"
          :can-confirm="queue.canConfirm"
          :can-dismiss="queue.canDismiss"
          @toggle="queue.toggleRow"
          @confirm="(row) => onRow(row, 'confirm')"
          @dismiss="(row) => onRow(row, 'dismiss')"
        />

        <template #footer>
          <div class="vsq-pager">
            <BButton
              size="sm"
              variant="outline-secondary"
              :disabled="queue.page.value <= 1 || queue.loading.value"
              @click="queue.goToPage(queue.page.value - 1)"
            >
              Previous
            </BButton>
            <span class="vsq-pager__label">
              Page {{ queue.page.value }} of {{ queue.totalPages.value }}
            </span>
            <BButton
              size="sm"
              variant="outline-secondary"
              :disabled="queue.page.value >= queue.totalPages.value || queue.loading.value"
              @click="queue.goToPage(queue.page.value + 1)"
            >
              Next
            </BButton>
          </div>
        </template>
      </TableShell>
    </BContainer>
  </AuthenticatedPageShell>
</template>

<script setup lang="ts">
import { computed, onMounted } from 'vue';

import AuthenticatedPageShell from '@/components/layout/AuthenticatedPageShell.vue';
import TableShell from '@/components/table/TableShell.vue';
import VariationSuggestionsTable from './components/VariationSuggestionsTable.vue';
import useVariationSuggestions from './composables/useVariationSuggestions';
import useToast from '@/composables/useToast';
import type { VariationSuggestionRow } from '@/api/curate_variation';

const toast = useToast();

const queue = useVariationSuggestions({
  onError: (message) => toast.makeToast(message, 'Variation suggestions', 'danger'),
});

const stateOptions = [
  { value: null, text: 'Any state' },
  { value: 'active_unconfirmed', text: 'Needs confirmation' },
  { value: 'suggested', text: 'Suggested' },
];

const strengthOptions = [
  { value: null, text: 'Any strength' },
  ...[0, 1, 2, 3, 4].map((value) => ({ value, text: `${value} of 4` })),
];

const sortOptions = [
  { value: 'strength_desc', text: 'Strongest evidence first' },
  { value: 'strength_asc', text: 'Weakest evidence first' },
  { value: 'entity_asc', text: 'By entity' },
];

const tableDescription = computed(() =>
  queue.filters.value.moved
    ? 'Annotations whose importing review has since been replaced by a curator review.'
    : 'Machine-derived annotations awaiting an explicit curator decision.'
);

const metaText = computed(() => `${queue.total.value} assertions`);

/**
 * Report the outcome VERBATIM, including every skip.
 *
 * The server re-derives state and served membership under a row lock, so a row
 * that looked actionable a moment ago can legitimately be refused. Saying "10 of
 * 12 applied — skipped: 2 not served" is the honest answer; a bare success toast
 * would teach curators that the count on screen is decorative.
 */
async function onBulk(action: 'confirm' | 'dismiss'): Promise<void> {
  const result = await queue.confirmDismiss(action);
  if (result) toast.makeToast(queue.describeResult(result), 'Variation suggestions', 'info');
}

async function onRow(row: VariationSuggestionRow, action: 'confirm' | 'dismiss'): Promise<void> {
  const result = await queue.applyRow(row, action);
  if (result) toast.makeToast(queue.describeResult(result), 'Variation suggestions', 'info');
}

onMounted(() => {
  queue.load();
});
</script>

<style scoped>
.vsq-intro {
  max-width: 68ch;
  margin-bottom: 1rem;
}

.vsq-filters {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem 1rem;
  border-bottom: 1px solid var(--border-subtle, #dee2e6);
}

.vsq-filters__search {
  max-width: 18rem;
}

.vsq-bulk {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.vsq-bulk__count {
  font-size: 0.85rem;
  color: var(--bs-secondary-color, #6c757d);
}

.vsq-bulk__hint {
  font-size: 0.85rem;
  color: var(--bs-warning-text-emphasis, #664d03);
}

.vsq-pager {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.75rem;
  padding: 0.6rem 0;
}

.vsq-pager__label {
  font-size: 0.85rem;
}
</style>
