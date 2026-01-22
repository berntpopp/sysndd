<!-- components/small/GenericTable.vue -->
<template>
  <BTable
    :items="items"
    :fields="fields"
    :current-page="currentPage"
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
    no-local-pagination
    @update:sort-by="handleSortByUpdate"
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
      <BButton
        class="btn-xs"
        variant="outline-primary"
        @click="row.toggleDetails"
      >
        {{ row.detailsShowing ? "Hide" : "Show" }}
      </BButton>
    </template>

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
    <!-- Slot for row details -->
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
    /**
     * Bootstrap-Vue-Next uses array-based sortBy:
     * [{ key: 'column_name', order: 'asc' | 'desc' }]
     *
     * For backward compatibility, also accepts legacy string sortBy prop.
     */
    sortBy: {
      type: Array,
      default: () => [],
    },
    /**
     * Legacy prop for backward compatibility with existing components.
     * If provided, will be converted to array format internally.
     */
    sortDesc: {
      type: Boolean,
      default: false,
    },
  },
  emits: ['update-sort', 'update:sort-by'],
  computed: {
    /**
     * Local sortBy that syncs with the parent's sortBy prop.
     */
    localSortBy() {
      return this.sortBy;
    },
  },
  methods: {
    /**
     * Handle sort-by updates from BTable.
     * Emits both Bootstrap-Vue-Next and legacy formats for backward compatibility.
     * @param {Array} newSortBy - New sort configuration
     */
    handleSortByUpdate(newSortBy) {
      // Emit in Bootstrap-Vue-Next format
      this.$emit('update:sort-by', newSortBy);

      // Also emit in legacy format for backward compatibility with handleSortUpdate
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
