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

    <!-- ID column (generic) -->
    <template #cell(id)="data">
      <slot
        name="cell-id"
        :row="data.item"
        :index="data.index"
      >
        {{ data.item.id }}
      </slot>
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

    <!-- Log-related columns -->
    <template #cell(agent)="data">
      <slot
        name="cell-agent"
        :row="data.item"
        :index="data.index"
      >
        {{ data.item.agent }}
      </slot>
    </template>

    <template #cell(status)="data">
      <slot
        name="cell-status"
        :row="data.item"
        :index="data.index"
      >
        {{ data.item.status }}
      </slot>
    </template>

    <template #cell(request_method)="data">
      <slot
        name="cell-request_method"
        :row="data.item"
        :index="data.index"
      >
        {{ data.item.request_method }}
      </slot>
    </template>

    <template #cell(query)="data">
      <slot
        name="cell-query"
        :row="data.item"
        :index="data.index"
      >
        {{ data.item.query }}
      </slot>
    </template>

    <template #cell(timestamp)="data">
      <slot
        name="cell-timestamp"
        :row="data.item"
        :index="data.index"
      >
        {{ data.item.timestamp }}
      </slot>
    </template>

    <template #cell(modified)="data">
      <slot
        name="cell-modified"
        :row="data.item"
        :index="data.index"
      >
        {{ data.item.modified }}
      </slot>
    </template>

    <template #cell(path)="data">
      <slot
        name="cell-path"
        :row="data.item"
        :index="data.index"
      >
        {{ data.item.path }}
      </slot>
    </template>

    <template #cell(host)="data">
      <slot
        name="cell-host"
        :row="data.item"
        :index="data.index"
      >
        {{ data.item.host }}
      </slot>
    </template>

    <template #cell(address)="data">
      <slot
        name="cell-address"
        :row="data.item"
        :index="data.index"
      >
        {{ data.item.address }}
      </slot>
    </template>

    <template #cell(duration)="data">
      <slot
        name="cell-duration"
        :row="data.item"
        :index="data.index"
      >
        {{ data.item.duration }}
      </slot>
    </template>

    <template #cell(file)="data">
      <slot
        name="cell-file"
        :row="data.item"
        :index="data.index"
      >
        {{ data.item.file }}
      </slot>
    </template>

    <template #cell(post)="data">
      <slot
        name="cell-post"
        :row="data.item"
        :index="data.index"
      >
        {{ data.item.post }}
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

    <!-- User role column -->
    <template #cell(user_role)="data">
      <slot
        name="cell-user_role"
        :row="data.item"
        :index="data.index"
      >
        {{ data.item.user_role }}
      </slot>
    </template>

    <!-- Cluster number column (for combined cluster data) -->
    <template #cell(cluster_num)="data">
      <slot
        name="cell-cluster_num"
        :row="data.item"
        :index="data.index"
      >
        {{ data.item.cluster_num }}
      </slot>
    </template>

    <!-- Curation comparison columns -->
    <template #cell(SysNDD)="data">
      <slot
        name="cell-SysNDD"
        :row="data.item"
        :index="data.index"
      >
        {{ data.item.SysNDD }}
      </slot>
    </template>

    <template #cell(radboudumc_ID)="data">
      <slot
        name="cell-radboudumc_ID"
        :row="data.item"
        :index="data.index"
      >
        {{ data.item.radboudumc_ID }}
      </slot>
    </template>

    <template #cell(gene2phenotype)="data">
      <slot
        name="cell-gene2phenotype"
        :row="data.item"
        :index="data.index"
      >
        {{ data.item.gene2phenotype }}
      </slot>
    </template>

    <template #cell(panelapp)="data">
      <slot
        name="cell-panelapp"
        :row="data.item"
        :index="data.index"
      >
        {{ data.item.panelapp }}
      </slot>
    </template>

    <template #cell(sfari)="data">
      <slot
        name="cell-sfari"
        :row="data.item"
        :index="data.index"
      >
        {{ data.item.sfari }}
      </slot>
    </template>

    <template #cell(geisinger_DBD)="data">
      <slot
        name="cell-geisinger_DBD"
        :row="data.item"
        :index="data.index"
      >
        {{ data.item.geisinger_DBD }}
      </slot>
    </template>

    <template #cell(omim_ndd)="data">
      <slot
        name="cell-omim_ndd"
        :row="data.item"
        :index="data.index"
      >
        {{ data.item.omim_ndd }}
      </slot>
    </template>

    <template #cell(orphanet_id)="data">
      <slot
        name="cell-orphanet_id"
        :row="data.item"
        :index="data.index"
      >
        {{ data.item.orphanet_id }}
      </slot>
    </template>

    <!-- Description column with truncation and tooltip -->
    <template #cell(description)="data">
      <slot
        name="cell-description"
        :row="data.item"
        :index="data.index"
      >
        <span
          v-b-tooltip.hover.top
          class="description-text"
          :title="data.item.description"
        >
          {{ data.item.description }}
        </span>
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

/* Mobile: enlarge details button to WCAG 44px touch target */
@media (max-width: 767px) {
  .btn-xs {
    width: 100%;
    min-height: 44px;
    padding: 0.5rem 1rem;
    line-height: 1.5;
  }
}
</style>
