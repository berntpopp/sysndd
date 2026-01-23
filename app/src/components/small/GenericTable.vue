<!-- components/small/GenericTable.vue -->
<template>
  <BTable
    :items="items"
    :fields="fields"
    :busy="isBusy"
    :sort-by="localSortBy"
    stacked="md"
    head-variant="light"
    show-empty
    small
    fixed
    striped
    hover
    sort-icon-left
    no-local-sorting
    @update:sort-by="handleSortByUpdate"
  >
    <!-- Slot for custom filter fields -->
    <!-- Bootstrap-Vue-Next uses #thead-top instead of #top-row -->
    <template #thead-top>
      <tr v-if="$slots['filter-controls']">
        <slot name="filter-controls" />
      </tr>
    </template>

    <!-- Entity ID column -->
    <template #cell(entity_id)="data">
      <slot
        name="cell-entity_id"
        :row="data.item"
        :index="data.index"
      >
        {{ data.item.entity_id }}
      </slot>
    </template>

    <!-- Symbol column -->
    <template #cell(symbol)="data">
      <slot
        name="cell-symbol"
        :row="data.item"
        :index="data.index"
      >
        {{ data.item.symbol }}
      </slot>
    </template>

    <!-- Disease ontology name column -->
    <template #cell(disease_ontology_name)="data">
      <slot
        name="cell-disease_ontology_name"
        :row="data.item"
        :index="data.index"
      >
        {{ data.item.disease_ontology_name }}
      </slot>
    </template>

    <!-- HPO mode of inheritance column -->
    <template #cell(hpo_mode_of_inheritance_term_name)="data">
      <slot
        name="cell-hpo_mode_of_inheritance_term_name"
        :row="data.item"
        :index="data.index"
      >
        {{ data.item.hpo_mode_of_inheritance_term_name }}
      </slot>
    </template>

    <!-- Category column -->
    <template #cell(category)="data">
      <slot
        name="cell-category"
        :row="data.item"
        :index="data.index"
      >
        {{ data.item.category }}
      </slot>
    </template>

    <!-- NDD phenotype column -->
    <template #cell(ndd_phenotype_word)="data">
      <slot
        name="cell-ndd_phenotype_word"
        :row="data.item"
        :index="data.index"
      >
        {{ data.item.ndd_phenotype_word }}
      </slot>
    </template>

    <!-- Actions column -->
    <template #cell(actions)="data">
      <slot
        name="cell-actions"
        :row="data.item"
        :index="data.index"
      >
        {{ data.item.actions }}
      </slot>
    </template>

    <!-- Approved column -->
    <template #cell(approved)="data">
      <slot
        name="cell-approved"
        :row="data.item"
        :index="data.index"
      >
        {{ data.item.approved }}
      </slot>
    </template>

    <!-- Details column -->
    <template #cell(details)="row">
      <BButton
        class="btn-xs"
        variant="outline-primary"
        @click="row.toggleDetails"
      >
        {{ row.detailsShowing ? "Hide" : "Show" }}
      </BButton>
    </template>

    <!-- Row details -->
    <template #row-details="row">
      <BCard>
        <BTable
          :items="[row.item]"
          :fields="fieldDetails"
          stacked
          small
        />
      </BCard>
    </template>
  </BTable>
</template>

<script>
import { BTable, BButton, BCard } from 'bootstrap-vue-next';

export default {
  name: 'GenericTable',
  components: {
    BTable,
    BButton,
    BCard,
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
  },
  emits: ['update-sort', 'update:sort-by'],
  computed: {
    /**
     * Converts sortBy prop to Bootstrap-Vue-Next array format.
     * Handles both legacy string format and new array format.
     * @returns {Array} Array of { key, order } objects
     */
    localSortBy() {
      // If already an array, return as-is
      if (Array.isArray(this.sortBy)) {
        return this.sortBy;
      }
      // Convert string to array format for Bootstrap-Vue-Next
      if (typeof this.sortBy === 'string' && this.sortBy) {
        return [{
          key: this.sortBy,
          order: this.sortDesc ? 'desc' : 'asc',
        }];
      }
      // Default to empty array
      return [];
    },
  },
  methods: {
    handleSortByUpdate(newSortBy) {
      this.$emit('update:sort-by', newSortBy);
      if (newSortBy && newSortBy.length > 0) {
        const sortByStr = newSortBy[0].key;
        const sortDescBool = newSortBy[0].order === 'desc';
        this.$emit('update-sort', { sortBy: sortByStr, sortDesc: sortDescBool });
      }
    },
  },
};
</script>

<style scoped>
.btn-group-xs > .btn,
.btn-xs {
  padding: 0.25rem 0.4rem;
  font-size: 0.875rem;
  line-height: 0.5;
  border-radius: 0.2rem;
}
</style>
