<!-- src/components/analyses/PhenotypeClusterVariableTable.vue -->
<!--
  Right-pane variable/entity table for the phenotype-clusters analysis. Owns the
  table's own concerns: table-type selection, the global "any" + per-column
  filters, sorting, client-side pagination, and Excel export (all delegated to
  usePhenotypeClusterTable). Cluster selection, the Cytoscape network, and the
  LLM summary card live in the parent (AnalysesPhenotypeClusters.vue), which
  threads the selected cluster's rows in as `selectedCluster`.
-->
<template>
  <BCard
    header-tag="header"
    class="my-3 mx-2 text-start"
    body-class="p-0"
    header-class="p-1"
    border-variant="light"
  >
    <template #header>
      <div class="mb-0 font-weight-bold">
        <BRow>
          <BCol sm="6" class="mb-1">
            <BInputGroup size="sm">
              <label for="phenotype-table-type-select" class="input-group-text">Table type</label>
              <BFormSelect
                id="phenotype-table-type-select"
                v-model="tableType"
                :options="tableOptions"
                size="sm"
                aria-label="Select table type"
              />
            </BInputGroup>
          </BCol>

          <BCol sm="6" class="mb-1 text-end">
            <div class="d-flex align-items-center justify-content-end gap-2">
              <TableSearchInput
                v-model="filter.any.content"
                :placeholder="'Search variables here...'"
                :debounce-time="500"
                @input="onFilterChange"
              />
              <BButton
                v-b-tooltip.hover.bottom
                size="sm"
                variant="outline-secondary"
                title="Download table data as Excel file"
                aria-label="Download table data as Excel file"
                :disabled="loading || isExporting"
                @click="downloadExcel"
              >
                <i class="bi bi-table me-1" aria-hidden="true" />
                <i v-if="!isExporting" class="bi bi-download" aria-hidden="true" />
                <BSpinner v-else small />
                .xlsx
              </BButton>
            </div>
          </BCol>
        </BRow>
      </div>
    </template>

    <BCardText class="text-start" :aria-busy="loading ? 'true' : 'false'">
      <TableLoadingState
        v-if="loading"
        class="phenotype-table-loading"
        label="Loading phenotype cluster rows"
        :rows="6"
      />

      <GenericTable
        v-else
        :items="displayedItems"
        :fields="fields"
        :sort-by="sortBy"
        :sort-desc="sortDesc"
        @update-sort="handleSortUpdate"
      >
        <template #filter-controls>
          <td v-for="field in fields" :key="field.key" role="presentation">
            <BFormInput
              v-if="field.key !== 'details'"
              v-model="filter[field.key].content"
              :placeholder="'Filter ' + field.label"
              :aria-label="'Filter by ' + field.label"
              debounce="500"
              @input="onFilterChange"
            />
          </td>
        </template>
      </GenericTable>

      <BRow v-if="!loading" class="justify-content-end">
        <BCol cols="12" md="auto" class="my-1">
          <TablePaginationControls
            :total-rows="totalRows"
            :initial-per-page="perPage"
            :page-options="[5, 10, 20]"
            @page-change="handlePageChange"
            @per-page-change="handlePerPageChange"
          />
        </BCol>
      </BRow>
    </BCardText>
  </BCard>
</template>

<script>
import GenericTable from '@/components/small/GenericTable.vue';
import TableSearchInput from '@/components/small/TableSearchInput.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';
import TableLoadingState from '@/components/table/TableLoadingState.vue';

import { usePhenotypeClusterTable } from './usePhenotypeClusterTable';

export default {
  name: 'PhenotypeClusterVariableTable',
  components: {
    GenericTable,
    TableSearchInput,
    TablePaginationControls,
    TableLoadingState,
  },
  props: {
    /** Rows keyed by table type ({ quali_inp_var, quali_sup_var, quanti_sup_var }). */
    selectedCluster: {
      type: Object,
      required: true,
    },
    /** True while the parent is loading cluster data. */
    loading: {
      type: Boolean,
      default: false,
    },
    /** Active cluster number (used for the Excel export filename). */
    activeCluster: {
      type: [String, Number],
      default: '',
    },
  },
  setup(props) {
    return usePhenotypeClusterTable(props);
  },
};
</script>

<style scoped>
mark {
  display: inline-block;
  line-height: 0em;
  padding-bottom: 0.5em;
  font-weight: bold;
  background-color: #eaadba;
}
</style>
