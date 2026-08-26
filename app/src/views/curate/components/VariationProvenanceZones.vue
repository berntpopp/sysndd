<!-- views/curate/components/VariationProvenanceZones.vue -->
<!--
  #608 / #612 — the three-zone variation-ontology picker.

  Extracted VERBATIM from ReviewFormFields.vue so it can be mounted on every
  curation surface that prefills and resubmits variation terms, not just the
  Review page's edit modal. Three surfaces did that prefill without any
  deliberate-act affordance: ModifyEntity's inline and combined workflows, and
  ApproveReview's edit form. They were already protected server-side — the API
  reconciles regardless of what a client sends — so this is a UX change, not a
  correctness one. The value is that a curator sees "2 terms need confirmation"
  instead of two silently pre-checked boxes.

  Every `data-testid` is preserved character-for-character:
  ReviewFormFields.provenance.spec.ts asserts on them and passes UNCHANGED,
  which is the proof the extraction was faithful.

  Renders nothing when there is nothing to decide (`hasZones` false), so a
  surface whose entity has no machine-derived terms looks exactly as it did
  before #608.
-->
<template>
  <div v-if="zonesActive" class="vario-zones" data-testid="variation-provenance-zones">
    <section
      v-if="zoneConfirmed.length"
      class="vario-zones__zone"
      aria-labelledby="vario-zone-confirmed-heading"
      data-testid="variation-zone-confirmed"
    >
      <h6 id="vario-zone-confirmed-heading" class="vario-zones__heading">
        Confirmed
        <span class="vario-zones__count" data-testid="variation-zone-confirmed-count">
          {{ termCount(zoneConfirmed.length) }}
        </span>
      </h6>
      <ul class="vario-zones__chips">
        <li
          v-for="entry in zoneConfirmed"
          :key="entry.tag"
          data-testid="variation-confirmed-chip"
          :data-tag="entry.tag"
        >
          <span class="sysndd-chip sysndd-chip--neutral">
            <i class="bi bi-check2 me-1" aria-hidden="true" />
            {{ displayName(entry) }} ({{ entry.modifierLabel }})
          </span>
        </li>
      </ul>
    </section>

    <section
      v-if="zoneNeedsConfirmation.length"
      class="vario-zones__zone"
      aria-labelledby="vario-zone-needs-confirmation-heading"
      data-testid="variation-zone-needs-confirmation"
    >
      <h6 id="vario-zone-needs-confirmation-heading" class="vario-zones__heading">
        Needs confirmation
        <span class="vario-zones__count" data-testid="variation-zone-needs-confirmation-count">
          {{ termCount(zoneNeedsConfirmation.length) }}
        </span>
      </h6>
      <p class="vario-zones__hint">
        Machine-derived from the sources below. Saving leaves an unconfirmed term in place; only
        Confirm records that you agree with it.
      </p>
      <ul class="vario-zones__cards">
        <VariationProvenanceCard
          v-for="entry in zoneNeedsConfirmation"
          :key="entry.tag"
          :entry="entry"
          :display-name="displayName(entry)"
          primary-label="Confirm"
          secondary-label="Remove"
          primary-testid="variation-action-confirm"
          secondary-testid="variation-action-remove"
          :disabled="readonly"
          @primary="variationZones?.confirmTerm(entry.tag)"
          @secondary="variationZones?.removeTerm(entry.tag)"
        />
      </ul>
    </section>

    <section
      v-if="zoneSuggested.length"
      class="vario-zones__zone"
      aria-labelledby="vario-zone-suggested-heading"
      data-testid="variation-zone-suggested"
    >
      <h6 id="vario-zone-suggested-heading" class="vario-zones__heading">
        Suggested — not in the entity
        <span class="vario-zones__count" data-testid="variation-zone-suggested-count">
          {{ termCount(zoneSuggested.length) }}
        </span>
      </h6>
      <p class="vario-zones__hint">Candidate terms. Nothing is added until you accept it.</p>
      <ul class="vario-zones__cards">
        <VariationProvenanceCard
          v-for="entry in zoneSuggested"
          :key="entry.tag"
          :entry="entry"
          :display-name="displayName(entry)"
          primary-label="Accept"
          secondary-label="Dismiss"
          primary-testid="variation-action-accept"
          secondary-testid="variation-action-dismiss"
          :disabled="readonly"
          @primary="variationZones?.acceptSuggestion(entry.tag)"
          @secondary="variationZones?.dismissSuggestion(entry.tag)"
        />
      </ul>
    </section>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';

import VariationProvenanceCard from '@/views/curate/components/VariationProvenanceCard.vue';
import type {
  VariationProvenanceZonesApi,
  VariationZoneEntry,
} from '@/views/curate/composables/useVariationProvenanceZones';

const props = withDefaults(
  defineProps<{
    /** Zone state for THIS surface. `null` renders nothing. */
    variationZones?: VariationProvenanceZonesApi | null;
    readonly?: boolean;
    /**
     * Optional richer label resolver. The Review form passes one that also
     * consults its option-tree labels; every other surface uses the default,
     * which shows the server-supplied name or the bare CURIE and never a label
     * nobody supplied.
     */
    displayName?: ((entry: VariationZoneEntry) => string) | null;
  }>(),
  { variationZones: null, readonly: false, displayName: null }
);

// The zones API exposes refs, and a prop object's nested refs are NOT unwrapped,
// so each one is read through `.value` explicitly.
const zonesActive = computed(() => Boolean(props.variationZones?.hasZones.value));
const zoneConfirmed = computed(() => props.variationZones?.confirmed.value ?? []);
const zoneNeedsConfirmation = computed(() => props.variationZones?.needsConfirmation.value ?? []);
const zoneSuggested = computed(() => props.variationZones?.suggested.value ?? []);

/** Server-supplied term name when there is one; the CURIE is never invented. */
const displayName = (entry: VariationZoneEntry): string =>
  props.displayName ? props.displayName(entry) : entry.varioName || entry.varioId;

const termCount = (count: number): string => `${count} term${count === 1 ? '' : 's'}`;

const variationZones = computed(() => props.variationZones);
const readonly = computed(() => props.readonly);
</script>

<style scoped>
.vario-zones {
  display: grid;
  gap: 0.6rem;
  margin: 0.35rem 0 0.5rem;
  padding: 0.6rem;
  border: 1px solid var(--border-subtle, #d9e0ea);
  border-radius: var(--radius-md, 0.375rem);
  background: var(--neutral-50, #fafafa);
}

.vario-zones__zone {
  display: grid;
  gap: 0.35rem;
  min-width: 0;
}

.vario-zones__heading {
  display: flex;
  flex-wrap: wrap;
  align-items: baseline;
  justify-content: space-between;
  gap: 0.5rem;
  margin: 0;
  color: var(--neutral-900, #212121);
  font-size: 0.75rem;
  font-weight: 700;
  letter-spacing: 0.02em;
  text-transform: uppercase;
}

.vario-zones__count {
  color: var(--neutral-600, #757575);
  font-size: 0.75rem;
  font-weight: 600;
  text-transform: none;
  letter-spacing: normal;
}

.vario-zones__hint {
  margin: 0;
  color: var(--neutral-600, #757575);
  font-size: 0.75rem;
  line-height: 1.4;
}

.vario-zones__chips,
.vario-zones__cards {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem;
  margin: 0;
  padding: 0;
  list-style: none;
}
</style>
