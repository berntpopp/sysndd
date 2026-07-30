<!-- app/src/views/pages/components/VariationProvenanceDialog.vue -->
<!--
  #608 — evidence detail for ONE machine-derived variation-ontology assertion.

  Mounted by EntityEvidenceGrid only while a term is open (`v-if`), so the card
  costs nothing extra on page load and this component never exists on an entity
  whose terms are all curator-authored.

  HONESTY RULES (see variationProvenance.ts for the full note)
  -----------------------------------------------------------
  Only fields the payload actually contains are rendered. The Imported row shows
  the import DATE (`created_at`, #612), the batch, and the release — each part
  independently omitted when its value is null, so the row degrades to whatever
  the payload genuinely carries and disappears entirely when it carries none of
  them. A DATE, not a time: the column behind it is a MySQL `DATETIME` with no
  timezone. There are no HGVS / protein labels because the importer never
  recorded them. `summary` is the source's own stored wording, verbatim. An
  unrecorded strength reads "Not recorded" and draws NO stars.

  A11Y
  ----
  Labelled modal dialog: `role="dialog"`, `aria-modal="true"`,
  `aria-labelledby` on the title. Focus moves to the dialog on open, Tab is
  trapped inside it, Escape (and the scrim, and Close) emit `close`; the PARENT
  restores focus to the trigger it came from, because the parent owns the
  trigger. State is always in text, never glyph- or colour-only.
-->
<template>
  <!-- display:contents — this wrapper must not become a flex item of the chip
       panel that hosts it; both children are position:fixed. -->
  <div class="variation-provenance-host">
    <!-- Quiet scrim: dismiss affordance, not decoration. Not focusable. -->
    <div
      class="variation-provenance-scrim"
      data-testid="variation-provenance-scrim"
      @click="emit('close')"
    />
    <div
      ref="dialogEl"
      class="variation-provenance-dialog"
      data-testid="variation-provenance-dialog"
      role="dialog"
      aria-modal="true"
      :aria-labelledby="titleId"
      tabindex="-1"
      @keydown.esc.stop.prevent="emit('close')"
      @keydown.tab="onTabKey"
    >
      <header class="vp-head">
        <div>
          <h2 :id="titleId" class="vp-title" data-testid="variation-provenance-dialog-title">
            {{ target.varioName }}
          </h2>
          <p class="vp-subtitle">
            <span class="sysndd-chip sysndd-chip--neutral sysndd-chip--mono">{{
              target.varioId
            }}</span>
            <span class="vp-modifier">{{ target.modifierLabel }}</span>
          </p>
        </div>
        <button
          ref="closeEl"
          type="button"
          class="vp-close"
          data-testid="variation-provenance-dialog-close"
          aria-label="Close evidence details"
          @click="emit('close')"
        >
          <i class="bi bi-x-lg" aria-hidden="true" />
        </button>
      </header>

      <p class="vp-status" data-testid="variation-provenance-dialog-status">
        <span class="vp-label">Status</span>
        <span>{{ statusText }}</span>
      </p>

      <p
        v-if="evidence.loading.value"
        class="vp-muted"
        data-testid="variation-provenance-dialog-loading"
        role="status"
      >
        Loading evidence&hellip;
      </p>

      <!-- A fetch failure is an inline note inside the dialog; the card behind
           it keeps rendering its chips. -->
      <p
        v-else-if="evidence.error.value"
        class="vp-error"
        data-testid="variation-provenance-dialog-error"
      >
        Evidence details could not be loaded.
      </p>

      <p v-else-if="records.length === 0" class="vp-muted" data-testid="variation-provenance-empty">
        No evidence records are recorded for this term.
      </p>

      <template v-else>
        <section
          v-for="(record, index) in records"
          :key="`${record.sourceKey}-${record.batchId}-${index}`"
          class="vp-source"
          :data-testid="`variation-provenance-source-${index}`"
        >
          <p class="vp-row">
            <span class="vp-label">Source</span>
            <span>
              {{ sourceDisplayName(record.sourceKey) }}
              <span v-if="sourceTypeText(record.sourceType)" class="vp-muted-inline">
                ({{ sourceTypeText(record.sourceType) }})
              </span>
            </span>
          </p>

          <p
            v-if="importedLineParts(record).length > 0"
            class="vp-row"
            :data-testid="`variation-provenance-imported-${index}`"
          >
            <span class="vp-label">Imported</span>
            <span>{{ importedLineParts(record).join(' · ') }}</span>
          </p>

          <p class="vp-row" :data-testid="`variation-provenance-strength-${index}`">
            <span class="vp-label">Strength</span>
            <span>
              <!-- Stars are decorative reinforcement; the count is always in text.
                   An unrecorded strength draws no stars at all. -->
              <span
                v-if="strengthDisplay(record.strength).recorded"
                class="vp-stars"
                aria-hidden="true"
                >{{ starGlyphs(record.strength) }}</span
              >
              <span class="vp-strength-text">{{ strengthDisplay(record.strength).text }}</span>
            </span>
          </p>

          <p v-if="record.summary" class="vp-summary">{{ record.summary }}</p>

          <template v-if="record.records.length > 0">
            <p class="vp-section-heading">Supporting records</p>
            <ul class="vp-records" :data-testid="`variation-provenance-records-${index}`">
              <li
                v-for="(row, rowIndex) in record.records"
                :key="`${row.variationId}-${rowIndex}`"
                :data-testid="`variation-provenance-record-${index}-${rowIndex}`"
              >
                <a
                  v-if="row.url"
                  class="vp-record-id"
                  :href="row.url"
                  target="_blank"
                  rel="noopener"
                  >{{ row.variationId }}<i class="bi bi-box-arrow-up-right" aria-hidden="true"
                /></a>
                <span v-else-if="row.variationId" class="vp-record-id">{{ row.variationId }}</span>
                <span v-if="row.consequence" class="vp-record-meta">{{ row.consequence }}</span>
                <span v-if="row.classification" class="vp-record-meta">{{
                  row.classification
                }}</span>
              </li>
            </ul>
          </template>

          <p
            v-if="record.matched.length > 0"
            class="vp-matched"
            :data-testid="`variation-provenance-matched-${index}`"
          >
            Matched via {{ record.matched.join(', ') }}
          </p>
        </section>
      </template>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed, onMounted, ref, type Ref } from 'vue';
import {
  importedLineParts,
  provenanceStatusText,
  sourceDisplayName,
  sourceTypeText,
  strengthDisplay,
  STRENGTH_SCALE_MAX,
  type PublicProvenanceState,
} from './variationProvenance';
import { useVariationEvidence } from '@/composables/useVariationEvidence';

export interface VariationProvenanceDialogTarget {
  entityId: string | number;
  varioId: string;
  varioName: string;
  modifierId: string | number;
  modifierLabel: string;
  /** State from the compact read; the evidence route's own state wins once loaded. */
  state: PublicProvenanceState;
}

const props = defineProps<{ target: VariationProvenanceDialogTarget }>();
const emit = defineEmits<{ close: [] }>();

const dialogEl = ref<HTMLElement | null>(null) as Ref<HTMLElement | null>;
const closeEl = ref<HTMLElement | null>(null) as Ref<HTMLElement | null>;

const titleId = computed(
  () =>
    `variation-provenance-title-${props.target.varioId.replace(/[^A-Za-z0-9_-]/g, '-')}-${props.target.modifierId}`
);

// Lazy + cached. This component only exists while a term is open, so activating
// the resource here IS "fetch on first open"; a reopen hits the shared cache.
const evidenceTarget = computed(() => ({
  entityId: props.target.entityId,
  varioId: props.target.varioId,
  modifierId: props.target.modifierId,
}));
const evidence = useVariationEvidence(evidenceTarget);

const records = computed(() => evidence.data.value?.records ?? []);

// The evidence route re-reads the assertion, so prefer its state once present;
// fall back to the state the compact read already gave us.
const statusText = computed(() =>
  provenanceStatusText(evidence.data.value?.state ?? props.target.state)
);

function starGlyphs(strength: number | null): string {
  const filled = strengthDisplay(strength).filled;
  return '★'.repeat(filled) + '☆'.repeat(STRENGTH_SCALE_MAX - filled);
}

// a11y: move focus into the dialog on open. The dialog container (not the close
// button) is focused so assistive tech announces the dialog's accessible name
// before its controls.
onMounted(() => {
  dialogEl.value?.focus();
});

const FOCUSABLE =
  'a[href], button:not([disabled]), input:not([disabled]), select:not([disabled]), textarea:not([disabled]), [tabindex]:not([tabindex="-1"])';

/** Keep Tab inside the dialog — required to honestly claim `aria-modal`. */
function onTabKey(event: KeyboardEvent): void {
  const root = dialogEl.value;
  if (!root) return;
  const focusable = Array.from(root.querySelectorAll<HTMLElement>(FOCUSABLE));
  if (focusable.length === 0) {
    event.preventDefault();
    root.focus();
    return;
  }
  const first = focusable[0];
  const last = focusable[focusable.length - 1];
  const active = document.activeElement;
  if (event.shiftKey && (active === first || active === root)) {
    event.preventDefault();
    last.focus();
  } else if (!event.shiftKey && active === last) {
    event.preventDefault();
    first.focus();
  }
}

defineExpose({ focusClose: () => closeEl.value?.focus() });
</script>

<style scoped>
/* Quiet, clinical, token-based. No gradients, no saturated alarm colours: an
   unconfirmed annotation is un-reviewed, not broken. */
.variation-provenance-host {
  display: contents;
}
.variation-provenance-scrim {
  position: fixed;
  inset: 0;
  z-index: 1040;
  background: rgba(33, 33, 33, 0.28);
}
.variation-provenance-dialog {
  position: fixed;
  top: 50%;
  left: 50%;
  z-index: 1050;
  /* The entity evidence card centres its text, and this dialog is rendered from
     inside it, so every free-flowing paragraph here inherited `center` while the
     label/value rows only LOOKED aligned because they are grids. The result was
     four competing alignments in one panel: a right-aligned label column, its
     left-aligned values, centred summary/heading/matched-via prose, and record
     rows at a fourth x-position. Reading order in a data panel needs one left
     edge, so the dialog establishes its own alignment rather than inheriting the
     card's. */
  text-align: left;
  width: min(30rem, calc(100vw - 2rem));
  max-height: min(32rem, calc(100vh - 3rem));
  padding: var(--spacing-4, 1rem);
  overflow-y: auto;
  overflow-x: hidden;
  transform: translate(-50%, -50%);
  border: 1px solid var(--neutral-300, #e0e0e0);
  border-radius: var(--radius-lg, 0.5rem);
  background: var(--surface-raised, #fff);
  box-shadow: var(--shadow-lg, 0 10px 15px -3px rgba(13, 71, 161, 0.1));
  color: var(--neutral-900, #212121);
  font-size: var(--font-size-sm, 0.875rem);
  overflow-wrap: anywhere;
}
.variation-provenance-dialog:focus-visible {
  outline: 2px solid var(--medical-blue-700, #0d47a1);
  outline-offset: 2px;
}
.vp-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: var(--spacing-2, 0.5rem);
  margin-bottom: var(--spacing-2, 0.5rem);
  padding-bottom: var(--spacing-2, 0.5rem);
  border-bottom: 1px solid var(--neutral-200, #eeeeee);
}
.vp-title {
  margin: 0;
  font-size: var(--font-size-base, 1rem);
  font-weight: var(--font-weight-semibold, 600);
  line-height: 1.3;
}
.vp-subtitle {
  display: flex;
  align-items: center;
  gap: var(--spacing-2, 0.5rem);
  margin: 0.25rem 0 0;
}
.vp-modifier {
  color: var(--neutral-700, #616161);
  font-size: var(--font-size-xs, 0.75rem);
}
.vp-close {
  padding: 0.15rem 0.35rem;
  border: 1px solid var(--neutral-300, #e0e0e0);
  border-radius: var(--radius-md, 0.375rem);
  background: none;
  color: var(--neutral-700, #616161);
  line-height: 1;
}
.vp-close:hover,
.vp-close:focus-visible {
  background: var(--neutral-100, #f5f5f5);
  color: var(--neutral-900, #212121);
}
.vp-row,
.vp-status {
  display: flex;
  gap: var(--spacing-2, 0.5rem);
  margin: 0 0 0.2rem;
}
.vp-status {
  margin-bottom: var(--spacing-2, 0.5rem);
}
.vp-label {
  flex: 0 0 4.5rem;
  color: var(--neutral-700, #616161);
  font-size: var(--font-size-xs, 0.75rem);
  text-transform: uppercase;
  letter-spacing: 0.02em;
}
.vp-source + .vp-source {
  margin-top: var(--spacing-3, 0.75rem);
  padding-top: var(--spacing-3, 0.75rem);
  border-top: 1px dashed var(--neutral-300, #e0e0e0);
}
.vp-stars {
  margin-right: 0.35rem;
  color: var(--neutral-700, #616161);
  letter-spacing: 0.05em;
}
.vp-strength-text,
.vp-muted-inline {
  color: var(--neutral-700, #616161);
  font-size: var(--font-size-xs, 0.75rem);
}
.vp-summary {
  margin: 0.35rem 0 0;
  color: var(--neutral-800, #424242);
}
.vp-section-heading {
  margin: var(--spacing-2, 0.5rem) 0 0.15rem;
  color: var(--neutral-700, #616161);
  font-size: var(--font-size-xs, 0.75rem);
  font-weight: var(--font-weight-semibold, 600);
  text-transform: uppercase;
  letter-spacing: 0.02em;
}
.vp-records {
  margin: 0;
  padding-left: 1.1rem;
}
.vp-records li {
  display: flex;
  /* Baseline, not the default stretch. A record row mixes a monospace id with
     smaller prose, and at narrow widths the prose wraps to two lines, so the row
     grows: with `align-items: normal` every child stretched to the full row height
     and their text landed at different vertical positions — measured at 390px, all
     three children were 44px tall and the consequence text rendered ABOVE its own
     id. Sharing a baseline is what a reader expects of a text row and keeps the id
     and its description on one line together however the prose wraps. */
  align-items: baseline;
  flex-wrap: wrap;
  gap: 0.35rem;
  margin-bottom: 0.1rem;
}
.vp-record-id {
  font-family: var(--font-family-mono, ui-monospace, monospace);
  font-size: var(--font-size-xs, 0.75rem);
}
.vp-record-id i {
  margin-left: 0.2rem;
  font-size: 0.65rem;
}
.vp-record-meta {
  color: var(--neutral-700, #616161);
  font-size: var(--font-size-xs, 0.75rem);
}
.vp-matched,
.vp-muted {
  margin: var(--spacing-2, 0.5rem) 0 0;
  color: var(--neutral-700, #616161);
  font-size: var(--font-size-xs, 0.75rem);
}
/* Not --status-danger: a failed lookup is a missing detail, not an alarm about
   the annotation. Kept muted, with the message doing the work. */
.vp-error {
  margin: var(--spacing-2, 0.5rem) 0 0;
  color: var(--neutral-800, #424242);
  font-size: var(--font-size-xs, 0.75rem);
}
</style>
