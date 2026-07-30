<!-- views/curate/components/VariationProvenanceCard.vue -->
<!--
  #608 — one machine-derived variation-ontology assertion awaiting a curator
  decision (a "needs confirmation" or "suggested" zone entry).

  Presentational only: no API calls, no store, no zone logic. The parent owns
  partitioning and the actions; this component renders the term, its modifier,
  the stored evidence, and two real buttons.

  Design notes (documentation/10-visual-design-guide.md):
   - An unconfirmed annotation is UN-REVIEWED, not broken, so the card never uses
     `--status-danger` / `--status-warning` tones. Alarming styling across
     thousands of entities would train curators to ignore it. State is carried by
     weight, a small glyph, and a dotted underline; saturated colour is reserved
     for the action button.
   - Evidence is inline rather than behind a popover because in the curation flow
     the evidence IS the decision.
   - `summary` is rendered verbatim. Nothing is synthesised, and no protein/cDNA
     label (e.g. `p.Thr215Pro`) is ever shown or inferred — none is stored, and
     inventing one is exactly the fabrication this feature exists to prevent.
   - An absent field is omitted rather than rendered as a placeholder; a `null`
     strength means NOT RECORDED and must never render as zero stars.
-->
<template>
  <li class="vario-prov-card" data-testid="variation-card" :data-tag="entry.tag">
    <div class="vario-prov-card__head">
      <i class="bi vario-prov-card__glyph" :class="glyphClass" aria-hidden="true" />
      <span class="vario-prov-card__term">{{ displayName }}</span>
      <span class="sysndd-chip sysndd-chip--neutral">{{ entry.modifierLabel }}</span>
      <span class="sysndd-chip sysndd-chip--neutral sysndd-chip--mono">{{ entry.varioId }}</span>
    </div>

    <ul v-if="entry.evidence.length" class="vario-prov-card__evidence">
      <li
        v-for="(evidence, index) in entry.evidence"
        :key="`${evidence.source_key}-${index}`"
        class="vario-prov-card__evidence-item"
      >
        <span class="vario-prov-card__source">{{ evidence.source_key }}</span>
        <template v-if="evidence.strength !== null">
          <span class="vario-prov-card__sep" aria-hidden="true">·</span>
          <span class="vario-prov-card__stars" aria-hidden="true">{{
            starGlyph(evidence.strength)
          }}</span>
          <span class="visually-hidden">
            evidence strength {{ evidence.strength }} of {{ MAX_STRENGTH }},
          </span>
        </template>
        <template v-if="evidence.summary">
          <span class="vario-prov-card__sep" aria-hidden="true">·</span>
          <span class="vario-prov-card__summary">{{ evidence.summary }}</span>
        </template>
      </li>
    </ul>

    <div class="vario-prov-card__actions">
      <button
        type="button"
        class="btn btn-sm btn-primary"
        :data-testid="primaryTestid"
        :disabled="disabled"
        :aria-label="`${primaryLabel} ${accessibleTerm}`"
        @click="$emit('primary')"
      >
        {{ primaryLabel }}
      </button>
      <button
        type="button"
        class="btn btn-sm btn-outline-secondary"
        :data-testid="secondaryTestid"
        :disabled="disabled"
        :aria-label="`${secondaryLabel} ${accessibleTerm}`"
        @click="$emit('secondary')"
      >
        {{ secondaryLabel }}
      </button>
    </div>
  </li>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { VariationZoneEntry } from '@/views/curate/composables/useVariationProvenanceZones';

/** Evidence strength is a 0-4 comparability score (see the API contract). */
const MAX_STRENGTH = 4;

interface Props {
  entry: VariationZoneEntry;
  /** Parent-resolved display name (server name, tree label, or the CURIE). */
  displayName: string;
  primaryLabel: string;
  secondaryLabel: string;
  primaryTestid: string;
  secondaryTestid: string;
  disabled?: boolean;
}

const props = withDefaults(defineProps<Props>(), { disabled: false });

defineEmits<{
  (e: 'primary'): void;
  (e: 'secondary'): void;
}>();

/**
 * Accessible names name the TERM they act on, so a screen-reader user never
 * hears four identical "Confirm" buttons. The modifier is part of the name
 * because `present` and `absent` are different assertions.
 */
const accessibleTerm = computed(() => `${props.displayName}, ${props.entry.modifierLabel}`);

const glyphClass = computed(() =>
  props.entry.zone === 'suggested' ? 'bi-plus-circle' : 'bi-lightning-charge'
);

function starGlyph(strength: number): string {
  const filled = Math.max(0, Math.min(MAX_STRENGTH, Math.round(strength)));
  return '★'.repeat(filled) + '☆'.repeat(MAX_STRENGTH - filled);
}
</script>

<style scoped>
.vario-prov-card {
  display: grid;
  gap: 0.35rem;
  padding: 0.5rem 0.6rem;
  border: 1px solid var(--border-subtle, #d9e0ea);
  border-radius: var(--radius-md, 0.375rem);
  background: #fff;
  list-style: none;
}

.vario-prov-card__head {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.4rem;
  min-width: 0;
}

.vario-prov-card__glyph {
  flex: 0 0 auto;
  color: var(--neutral-600, #757575);
  font-size: 0.8125rem;
}

/* State is carried by weight + a dotted underline, never by an alarming hue. */
.vario-prov-card__term {
  min-width: 0;
  overflow-wrap: anywhere;
  color: var(--neutral-900, #212121);
  font-size: 0.875rem;
  font-weight: 600;
  text-decoration: underline dotted var(--neutral-600, #757575);
  text-underline-offset: 0.2em;
}

.vario-prov-card__evidence {
  display: grid;
  gap: 0.15rem;
  margin: 0;
  padding: 0;
  list-style: none;
}

.vario-prov-card__evidence-item {
  color: var(--neutral-600, #757575);
  font-size: 0.75rem;
  line-height: 1.4;
  overflow-wrap: anywhere;
}

.vario-prov-card__source {
  font-weight: 600;
}

.vario-prov-card__sep {
  padding: 0 0.25rem;
}

.vario-prov-card__stars {
  letter-spacing: 0.05em;
}

.vario-prov-card__actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.35rem;
}
</style>
