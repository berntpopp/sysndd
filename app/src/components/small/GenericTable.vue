<!-- components/small/GenericTable.vue -->
<template>
  <b-table
    :items="items"
    :fields="fields"
    :current-page="currentPage"
    :busy="isBusy"
    :sort-by="sortBy"
    :sort-desc="sortDesc"
    stacked="md"
    head-variant="light"
    show-empty
    small
    fixed
    striped
    hover
    sort-icon-left
    no-local-sorting
    no-local-pagination
    @sort-changed="handleSortChanged"
  >
    <!-- Slot for custom table header -->
    <slot
      name="table-header"
      :fields="fields"
    />
    <!-- Slot for custom table header -->

    <!-- Slot for custom filter fields -->
    <template v-slot:top-row>
      <slot name="filter-controls" />
    </template>
    <!-- Slot for custom filter fields -->

    <!-- Slot for custom footer -->
    <slot name="table-footer" />
    <!-- Slot for custom footer -->

    <!-- Dynamic Slot for custom column rendering -->
    <template
      v-for="field in fields"
      v-slot:[`cell(${field.key})`]="data"
    >
      <slot
        :name="'cell-' + field.key"
        :row="data.item"
        :index="data.index"
        :field="field"
      >
        <!-- Fallback default content if no slot is provided -->
        <div
          :key="field.key"
          :class="field.customStyle"
        >
          {{ data.item[field.key] }}
        </div>
      </slot>
    </template>
    <!-- Dynamic Slot for custom column rendering -->

    <!-- Custom slot for the 'details' button -->
    <template #cell(details)="row">
      <b-button
        class="btn-xs"
        variant="outline-primary"
        @click="row.toggleDetails"
      >
        {{ row.detailsShowing ? "Hide" : "Show" }}
      </b-button>
    </template>

    <template #row-details="row">
      <b-card>
        <b-table
          :items="[row.item]"
          :fields="fieldDetails"
          stacked
          small
        />
      </b-card>
    </template>
    <!-- Slot for row details -->
  </b-table>
</template>

<script>
export default {
  name: 'GenericTable',
  props: {
    items: {
      type: Array,
      default: null,
    },
    fields: {
      type: Array,
      default: null,
    },
    fieldDetails: {
      type: Array,
      default: null,
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
      type: String,
      default: null,
    },
    sortDesc: {
      type: Boolean,
      default: false,
    },
  },
  methods: {
    handleSortChanged({ sortBy, sortDesc }) {
      this.$emit('update-sort', { sortBy, sortDesc });
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
