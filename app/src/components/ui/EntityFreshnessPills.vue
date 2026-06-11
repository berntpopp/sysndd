<!--
  EntityFreshnessPills
  --------------------
  Two metadata pills for the entity hero: when the entity was first entered
  (`entryDate`) and the most recent curation update (`lastUpdate`, derived in
  `ndd_entity_view` as GREATEST of entry/status/review dates — see migration
  026). Both accept a raw timestamp and render it date-only, so a reader can
  judge at a glance how current the curated record is.

  Rendered as two sibling root <span> nodes (no wrapper) so they sit as direct
  flex children of the hero's `.entity-metadata-row` alongside the other pills.
-->
<template>
  <span
    v-if="entry"
    class="entity-meta-pill entity-meta-date"
    data-testid="entity-entry-date"
    title="Date this entity was first entered into SysNDD"
  >
    <i class="bi bi-calendar-plus" aria-hidden="true" />
    <span>Entered {{ entry }}</span>
  </span>
  <span
    v-if="updated"
    class="entity-meta-pill entity-meta-date"
    data-testid="entity-last-update"
    title="Most recent curation update (status or review) for this entity"
  >
    <i class="bi bi-calendar-check" aria-hidden="true" />
    <span>Last updated {{ updated }}</span>
  </span>
</template>

<script setup lang="ts">
import { computed } from 'vue';

// Values come from a loosely-typed entity record map, so accept anything and
// coerce defensively.
const props = defineProps<{
  entryDate?: unknown;
  lastUpdate?: unknown;
}>();

// Trim a timestamp ("2014-03-04 00:00:00" / "2026-02-10T12:29:49") to its date
// part for a clean freshness signal.
const toDateOnly = (value: unknown): string => (value == null ? '' : String(value).slice(0, 10));
const entry = computed(() => toDateOnly(props.entryDate));
const updated = computed(() => toDateOnly(props.lastUpdate));
</script>

<style scoped>
.entity-meta-pill {
  display: inline-flex;
  align-items: center;
  gap: 0.3rem;
  box-sizing: border-box;
  height: 1.8rem;
  padding: 0.18rem 0.48rem;
  border: 1px solid #d5dbe3;
  border-radius: 999px;
  background: #f8fafc;
  font-size: 0.78rem;
  line-height: 1;
  white-space: nowrap;
}
.entity-meta-date {
  color: #5a6675;
  font-weight: 600;
}
.entity-meta-date .bi {
  color: #8a94a3;
}
</style>
