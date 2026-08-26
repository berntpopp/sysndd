<!-- app/src/views/pages/components/VariationEvidenceRecordList.vue -->
<!--
  Renders one evidence row's supporting records (#612).

  Presentation only: no fetching, no normalization, one prop. The three shapes
  come from `variationEvidenceRecords.ts`, which dispatches on the source; this
  component only decides how each already-normalized shape looks.

  WHY THREE BRANCHES AND NOT ONE
  ------------------------------
  Before #612 there was one branch, and it understood only the ClinVar shape.
  The external-database batch showed `consequence` alone and the literature
  batch showed nothing at all — a curator opened the evidence dialog and read a
  summary line above an empty body.

  A `null` field is OMITTED, never rendered as a blank or a placeholder. The
  `negated` badge is the one thing that must be impossible to miss: a negated
  literature match is evidence AGAINST the term, which is why the importer
  scores it 1 instead of 3, and rendering it like a positive match would
  overstate the machine evidence.
-->
<template>
  <ul class="vp-records" :data-testid="listTestid ?? undefined">
    <li
      v-for="(row, rowIndex) in records"
      :key="rowIndex"
      class="vp-record"
      :data-testid="rowTestidPrefix ? `${rowTestidPrefix}-${rowIndex}` : undefined"
    >
      <!-- ClinVar: identifier, classification, review stars, consequence. -->
      <template v-if="row.kind === 'clinvar'">
        <a
          v-if="row.url && row.variationId"
          class="vp-record-id"
          :href="row.url"
          target="_blank"
          rel="noopener"
          >{{ row.variationId }}<i class="bi bi-box-arrow-up-right" aria-hidden="true"
        /></a>
        <span v-else-if="row.variationId" class="vp-record-id">{{ row.variationId }}</span>
        <span v-if="row.classification" class="vp-record-meta">{{ row.classification }}</span>
        <span v-if="row.consequence" class="vp-record-meta">{{ row.consequence }}</span>
        <span
          v-if="strengthDisplay(row.stars).recorded"
          class="vp-record-meta"
          data-testid="evidence-clinvar-stars"
          >{{ strengthDisplay(row.stars).text }} stars</span
        >
      </template>

      <!-- External database: a labelled field list, absent keys omitted. -->
      <dl v-else-if="row.kind === 'external'" class="vp-record-fields">
        <template v-for="field in row.fields" :key="field.key">
          <dt class="vp-record-field-label">{{ field.label }}</dt>
          <dd class="vp-record-field-value">{{ field.value }}</dd>
        </template>
      </dl>

      <!-- Literature: the matched text, whether it was negated, and its sentence. -->
      <template v-else-if="row.kind === 'literature'">
        <span v-if="row.matchedText" class="vp-record-id">&ldquo;{{ row.matchedText }}&rdquo;</span>
        <span
          v-if="row.negated === true"
          class="vp-record-negated"
          data-testid="evidence-negated-badge"
          >negated context</span
        >
        <p v-if="row.context" class="vp-record-context">{{ row.context }}</p>
        <p v-if="row.pattern" class="vp-record-pattern">
          <span class="vp-record-field-label">Matched by</span>
          <code>{{ row.pattern }}</code>
        </p>
      </template>

      <!-- Any source this build does not recognise: the pre-#612 shape. -->
      <template v-else>
        <a
          v-if="row.url && row.variationId"
          class="vp-record-id"
          :href="row.url"
          target="_blank"
          rel="noopener"
          >{{ row.variationId }}<i class="bi bi-box-arrow-up-right" aria-hidden="true"
        /></a>
        <span v-else-if="row.variationId" class="vp-record-id">{{ row.variationId }}</span>
        <span v-if="row.consequence" class="vp-record-meta">{{ row.consequence }}</span>
        <span v-if="row.classification" class="vp-record-meta">{{ row.classification }}</span>
      </template>
    </li>
  </ul>
</template>

<script setup lang="ts">
import { strengthDisplay } from './variationProvenance';
import type { NormalizedEvidenceRecord } from './variationEvidenceRecords';

withDefaults(
  defineProps<{
    records: NormalizedEvidenceRecord[];
    /** `data-testid` for the list element. */
    listTestid?: string | null;
    /** Row `data-testid`s become `${rowTestidPrefix}-${rowIndex}`. */
    rowTestidPrefix?: string | null;
  }>(),
  { listTestid: null, rowTestidPrefix: null }
);
</script>

<style scoped>
.vp-records {
  list-style: none;
  margin: 0 0 0.5rem;
  padding: 0;
  display: grid;
  gap: 0.4rem;
}

.vp-record {
  display: flex;
  flex-wrap: wrap;
  align-items: baseline;
  gap: 0.4rem;
  font-size: 0.85rem;
}

.vp-record-id {
  font-weight: 600;
}

.vp-record-meta {
  color: var(--bs-secondary-color, #6c757d);
}

.vp-record-negated {
  border: 1px solid var(--bs-warning-border-subtle, #ffe69c);
  background: var(--bs-warning-bg-subtle, #fff3cd);
  color: var(--bs-warning-text-emphasis, #664d03);
  border-radius: 0.75rem;
  padding: 0 0.5rem;
  font-size: 0.75rem;
  font-weight: 600;
}

.vp-record-fields {
  display: grid;
  grid-template-columns: auto minmax(0, 1fr);
  column-gap: 0.6rem;
  row-gap: 0.15rem;
  margin: 0;
  width: 100%;
}

.vp-record-field-label {
  color: var(--bs-secondary-color, #6c757d);
  font-weight: 600;
  margin: 0;
}

.vp-record-field-value {
  margin: 0;
}

.vp-record-context,
.vp-record-pattern {
  flex-basis: 100%;
  margin: 0;
  color: var(--bs-secondary-color, #6c757d);
}

.vp-record-pattern code {
  font-size: 0.78rem;
}
</style>
