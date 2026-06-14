<!-- src/components/analyses/PubtatorAnnotatedText.vue -->
<!--
  Shared renderer for PubTator `text_hl` annotated text.

  Both PubtatorNDDTable and PubtatorNDDGenes render the annotated-text block
  (entity-highlighted segments + a color legend) identically. This component
  is the single source of truth for that markup, the AA-compliant entity
  colors, and the legend.

  Parsing goes through `parsePubtatorTextMemoized` so the same `text_hl` string
  is parsed once and reused across the preview/length-check/full-render call
  sites in the parent components.
-->
<template>
  <div v-if="text" class="annotated-text-section" :class="sectionClass">
    <div v-if="showLabel" class="annotated-text-label text-muted small mb-1">
      <i class="bi bi-highlighter me-1" />Annotated Text:
    </div>
    <div class="annotated-text">
      <span
        v-for="(segment, idx) in segments"
        :key="idx"
        :class="getSegmentClass(segment)"
        :title="getSegmentTooltip(segment)"
        >{{ segment.text }}</span
      >
    </div>
    <div v-if="showLegend" class="pubtator-legend d-flex flex-wrap gap-2 small mt-2">
      <span><span class="pubtator-gene px-1">Gene</span></span>
      <span><span class="pubtator-disease px-1">Disease</span></span>
      <span><span class="pubtator-variant px-1">Variant</span></span>
      <span><span class="pubtator-species px-1">Species</span></span>
      <span><span class="pubtator-chemical px-1">Chemical</span></span>
      <span><span class="pubtator-match px-1">Match</span></span>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import {
  parsePubtatorTextMemoized,
  getSegmentClass,
  getSegmentTooltip,
} from '@/composables/usePubtatorParser';

const props = withDefaults(
  defineProps<{
    /** Raw PubTator `text_hl` string. */
    text?: string | null;
    /** Show the "Annotated Text:" label header. */
    showLabel?: boolean;
    /** Show the color legend below the text. */
    showLegend?: boolean;
    /** Optional extra class on the wrapper (e.g. spacing utilities). */
    sectionClass?: string;
  }>(),
  {
    text: null,
    showLabel: true,
    showLegend: true,
    sectionClass: '',
  }
);

// Parse once (memoized) and reuse the segment array reactively.
const segments = computed(() => parsePubtatorTextMemoized(props.text));
</script>

<style scoped>
/* PubTator entity annotation highlights — AA-compliant (≥ 4.5:1).
   Class names are fixed by getSegmentClass() in usePubtatorParser.ts.
   Colors mapped to global sysndd-annotation-- equivalents from _chips.scss. */

/* Gene: --medical-blue-700 (#0d47a1) on --medical-blue-50 (#e3f2fd) ≈ 7.1:1 ✓ AAA */
.pubtator-gene {
  background-color: var(--medical-blue-50, #e3f2fd);
  color: var(--medical-blue-700, #0d47a1);
  border-radius: 2px;
  padding: 0 2px;
  cursor: help;
}

/* Disease: #bf360c on #ffe0b2 ≈ 4.6:1 ✓ AA */
.pubtator-disease {
  background-color: #ffe0b2;
  color: #bf360c;
  border-radius: 2px;
  padding: 0 2px;
  cursor: help;
}

/* Variant: #880e4f on #f8bbd9 ≈ 5.4:1 ✓ AA */
.pubtator-variant {
  background-color: #f8bbd9;
  color: #880e4f;
  border-radius: 2px;
  padding: 0 2px;
  cursor: help;
}

/* Species: #1b5e20 on #c8e6c9 ≈ 5.5:1 ✓ AA */
.pubtator-species {
  background-color: #c8e6c9;
  color: #1b5e20;
  border-radius: 2px;
  padding: 0 2px;
  cursor: help;
}

/* Chemical: #4a148c on #e1bee7 ≈ 5.6:1 ✓ AA */
.pubtator-chemical {
  background-color: #e1bee7;
  color: #4a148c;
  border-radius: 2px;
  padding: 0 2px;
  cursor: help;
}

/* Match: #bf360c on #fff59d ≈ 5.2:1 ✓ AA */
.pubtator-match {
  background-color: #fff59d;
  color: #bf360c;
  font-weight: 600;
  border-radius: 2px;
  padding: 0 2px;
}

.annotated-text-section {
  border-top: 1px solid var(--neutral-300, #e0e0e0);
  padding-top: 0.75rem;
}

.annotated-text-label {
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.05em;
}

.annotated-text {
  text-align: left;
  line-height: 1.8;
  white-space: pre-wrap;
  word-wrap: break-word;
}

.pubtator-legend {
  color: var(--neutral-600, #757575);
}
</style>
