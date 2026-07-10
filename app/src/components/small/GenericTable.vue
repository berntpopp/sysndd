<!-- components/small/GenericTable.vue -->
<!--
  Thin wrapper around the desktop table (issue #346). GenericTable owns no markup
  of its own: it forwards every consumer prop, emit, and slot (cell-*, column-header,
  filter-controls, and a consumer `row-expansion` override) to GenericDesktopTable,
  and supplies the fallback row-expansion detail card via GenericTableDetails. The
  public API — props, emits, slot names, slot-prop names, and responsive behavior —
  is preserved byte-for-byte so every existing consumer keeps working unchanged.
  Mobile rows, pagination, and toolbar chrome remain the responsibility of consumers.

  Kept as an Options-API <script> (like the original) on purpose: it preserves the
  loose, untyped slot-prop surface every consumer relies on. Converting it to
  <script setup> makes vue-tsc infer strict slot types (row item -> unknown), which
  breaks consumers such as ReviewTable/ApproveReview that treat the row loosely.
-->
<template>
  <GenericDesktopTable
    :items="items"
    :fields="fields"
    :is-busy="isBusy"
    :sort-by="sortBy"
    :sort-desc="sortDesc"
    :stacked-mode="stackedMode"
    :fixed-layout="fixedLayout"
    @update-sort="$emit('update-sort', $event)"
    @update:sort-by="$emit('update:sort-by', $event)"
  >
    <!-- Forward every consumer slot (cell-*, column-header, filter-controls, and a
         consumer-supplied row-expansion override) to the desktop child. row-expansion
         and row-expansion-extra are handled below so the fallback detail card wins
         when the consumer does not override them. -->
    <template v-for="name in forwardedSlotNames()" :key="name" #[name]="slotProps">
      <slot :name="name" v-bind="slotProps || {}" />
    </template>

    <!-- Row expansion - allows custom slot override, else falls back to the shared
         detail card. The raw BTable scope is forwarded by GenericDesktopTable, so
         `scope.item` / `scope.toggleExpansion` map to the original slot props. -->
    <template #row-expansion="scope">
      <slot name="row-expansion" :row="scope.item" :toggle="scope.toggleExpansion">
        <GenericTableDetails :row="scope.item" :field-details="fieldDetails">
          <template #extra>
            <slot name="row-expansion-extra" :row="scope.item" />
          </template>
        </GenericTableDetails>
      </slot>
    </template>
  </GenericDesktopTable>
</template>

<script>
import GenericDesktopTable from './GenericDesktopTable.vue';
import GenericTableDetails from './GenericTableDetails.vue';

export default {
  name: 'GenericTable',
  components: {
    GenericDesktopTable,
    GenericTableDetails,
  },
  props: {
    items: {
      type: Array,
      default: () => [],
    },
    fields: {
      type: Array,
      default: () => [],
    },
    fieldDetails: {
      type: Array,
      default: () => [],
    },
    currentPage: {
      type: Number,
      default: null,
    },
    isBusy: {
      type: Boolean,
      default: false,
    },
    sortBy: {
      // Accept both string (legacy) and array (Bootstrap-Vue-Next) formats
      type: [String, Array],
      default: () => [],
    },
    sortDesc: {
      type: Boolean,
      default: false,
    },
    stackedMode: {
      type: [String, Boolean],
      default: 'md',
    },
    fixedLayout: {
      type: Boolean,
      default: true,
    },
  },
  emits: ['update-sort', 'update:sort-by', 'head-clicked', 'sorted'],
  methods: {
    /**
     * Consumer slot names to forward to the desktop child, minus the row-expansion
     * pair which the wrapper renders itself (so the fallback detail card is used when
     * a consumer does not override it). Called per render so a conditionally-provided
     * slot (e.g. `filter-controls` behind a `v-if`) forwards reactively.
     */
    forwardedSlotNames() {
      return Object.keys(this.$slots).filter(
        (name) => name !== 'row-expansion' && name !== 'row-expansion-extra'
      );
    },
  },
};
</script>
