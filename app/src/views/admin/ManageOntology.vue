<!-- views/admin/ManageOntology.vue -->
/** * ManageOntology component * * @description This component is used to manage the variation
ontology entries. It includes a modern * table with search, filtering, pagination, and URL state
sync following the TablesEntities pattern. * * @component ManageOntology * * @script * - Imports the
GenericTable and TablePaginationControls components * - Uses composables for URL parsing, table
data, and Excel export * - Includes module-level caching to prevent duplicate API calls * -
Implements debounced search with 300ms delay * - Manages filter state with active/obsolete filters *
- Syncs table state to URL for bookmarkable views * * @style * - Uses the 'scoped' attribute to
limit the styles to this component only. * - Defines styles for small buttons and inputs within the
component. */

<template>
  <AuthenticatedPageShell
    title="Manage Ontology"
    content-class="authenticated-route-content"
    full-width
  >
    <div class="container-fluid">
      <BContainer fluid>
        <BRow class="justify-content-md-center py-2">
          <BCol md="12">
            <TableShell title="Variation Terms" :meta="`${totalRows} terms`">
              <template #actions>
                <BButton
                  v-b-tooltip.hover
                  size="sm"
                  class="me-1"
                  :variant="isExporting ? 'secondary' : 'outline-primary'"
                  :disabled="isExporting"
                  title="Export to Excel"
                  @click="handleExport"
                >
                  <BSpinner v-if="isExporting" small />
                  <i v-else class="bi bi-file-earmark-excel" />
                </BButton>
                <BButton
                  v-b-tooltip.hover
                  size="sm"
                  :variant="removeFiltersButtonVariant"
                  :title="removeFiltersButtonTitle"
                  @click="removeFilters"
                >
                  <i class="bi bi-funnel" />
                </BButton>
              </template>

              <template #toolbar>
                <!-- Search and Pagination Row -->
                <BRow class="g-2">
                  <BCol sm="8">
                    <BInputGroup>
                      <template #prepend>
                        <BInputGroupText><i class="bi bi-search" /></BInputGroupText>
                      </template>
                      <BFormInput
                        v-model="filter.any.content"
                        placeholder="Search by ID, name, or definition..."
                        debounce="300"
                        type="search"
                        @update:model-value="filtered()"
                      />
                    </BInputGroup>
                  </BCol>
                  <BCol sm="4">
                    <BContainer v-if="totalRows > perPage">
                      <TablePaginationControls
                        :total-rows="totalRows"
                        :initial-per-page="perPage"
                        :page-options="pageOptions"
                        :current-page="currentPage"
                        @page-change="handlePageChange"
                        @per-page-change="handlePerPageChange"
                      />
                    </BContainer>
                  </BCol>
                </BRow>

                <!-- Filter Row -->
                <BRow class="g-2 mt-1">
                  <BCol sm="3">
                    <BFormSelect
                      v-model="filter.is_active.content"
                      :options="activeFilterOptions"
                      size="sm"
                      @update:model-value="filtered()"
                    >
                      <template #first>
                        <BFormSelectOption :value="null"> All Status </BFormSelectOption>
                      </template>
                    </BFormSelect>
                  </BCol>
                  <BCol sm="3">
                    <BFormSelect
                      v-model="filter.obsolete.content"
                      :options="obsoleteFilterOptions"
                      size="sm"
                      @update:model-value="filtered()"
                    >
                      <template #first>
                        <BFormSelectOption :value="null"> All Terms </BFormSelectOption>
                      </template>
                    </BFormSelect>
                  </BCol>
                  <BCol sm="6" class="text-end">
                    <span class="text-muted small">
                      Showing {{ totalRows > 0 ? (currentPage - 1) * perPage + 1 : 0 }}-{{
                        Math.min(currentPage * perPage, totalRows)
                      }}
                      of {{ totalRows }}
                    </span>
                  </BCol>
                </BRow>

                <BRow class="g-2 mt-1 d-md-none">
                  <BCol>
                    <BInputGroup prepend="Sort" size="sm">
                      <BFormSelect
                        v-model="mobileSortValue"
                        :options="mobileSortOptions"
                        size="sm"
                      />
                    </BInputGroup>
                  </BCol>
                </BRow>

                <!-- Active Filter Pills -->
                <BRow v-if="hasActiveFilters" class="g-2 mt-1">
                  <BCol>
                    <BBadge
                      v-for="(activeFilter, index) in activeFilters"
                      :key="index"
                      variant="secondary"
                      class="me-2 mb-1"
                    >
                      {{ activeFilter.label }}: {{ activeFilter.value }}
                      <BButton
                        size="sm"
                        variant="link"
                        class="p-0 ms-1 text-light"
                        @click="clearFilter(activeFilter.key)"
                      >
                        <i class="bi bi-x" />
                      </BButton>
                    </BBadge>
                    <BButton size="sm" variant="link" class="p-0" @click="removeFilters">
                      Clear all
                    </BButton>
                  </BCol>
                </BRow>
              </template>

              <!-- Table with loading overlay -->
              <div class="position-relative">
                <BSpinner
                  v-if="isBusy"
                  class="position-absolute top-50 start-50 translate-middle"
                  variant="primary"
                  style="z-index: 10"
                />

                <!-- Empty state -->
                <div v-if="!isBusy && ontologies.length === 0" class="text-center py-4">
                  <i class="bi bi-journal-text fs-1 text-muted" />
                  <p class="text-muted mt-2">No ontology terms found matching your filters</p>
                  <BButton v-if="hasActiveFilters" variant="link" @click="removeFilters">
                    Clear filters
                  </BButton>
                </div>

                <GenericTable
                  v-else
                  class="d-none d-md-table"
                  :items="ontologies"
                  :fields="fields"
                  :sort-by="sortBy"
                  :class="{ 'opacity-50': isBusy }"
                  @update:sort-by="handleSortUpdate"
                >
                  <!-- Custom slot for the 'actions' column -->
                  <template #cell-actions="{ row }">
                    <div>
                      <BButton
                        v-b-tooltip.hover.top
                        size="sm"
                        class="me-1 btn-xs"
                        variant="outline-primary"
                        title="Edit ontology"
                        @click="editOntology(row)"
                      >
                        <i class="bi bi-pencil-square" />
                      </BButton>
                    </div>
                  </template>

                  <!-- Format obsolete as badge -->
                  <template #cell-obsolete="{ row }">
                    <BBadge :variant="row.obsolete ? 'warning' : 'success'">
                      {{ row.obsolete ? 'Yes' : 'No' }}
                    </BBadge>
                  </template>

                  <!-- Format is_active as badge -->
                  <template #cell-is_active="{ row }">
                    <BBadge :variant="row.is_active ? 'success' : 'secondary'">
                      {{ row.is_active ? 'Active' : 'Inactive' }}
                    </BBadge>
                  </template>
                </GenericTable>
                <OntologyMobileRows
                  v-if="!isBusy && ontologies.length > 0"
                  class="d-md-none"
                  :items="ontologies"
                  @edit="editOntology"
                />
              </div>
            </TableShell>
          </BCol>
        </BRow>

        <!-- Update Ontology Modal - extracted child, modern v-model design -->
        <OntologyEditModal
          v-model="showEditModal"
          v-model:ontology="ontologyToEdit"
          :fields="fields"
          @save="updateOntologyData"
        />
      </BContainer>
    </div>
  </AuthenticatedPageShell>
</template>

<script>
// Thin shell: all ontology-table state/filter/URL-sync/load/edit/update/
// export orchestration lives in the useOntologyAdminTable composable; the
// static column/filter/select config lives in ontologyTableConfig.ts.
import { useHead } from '@unhead/vue';
import { defineComponent } from 'vue';
import AuthenticatedPageShell from '@/components/layout/AuthenticatedPageShell.vue';
import TableShell from '@/components/table/TableShell.vue';
import GenericTable from '@/components/small/GenericTable.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';
import OntologyMobileRows from './components/OntologyMobileRows.vue';
import OntologyEditModal from './components/OntologyEditModal.vue';
import { useOntologyAdminTable } from './composables/useOntologyAdminTable';

export default defineComponent({
  name: 'ManageOntology',
  components: {
    AuthenticatedPageShell,
    TableShell,
    GenericTable,
    TablePaginationControls,
    OntologyMobileRows,
    OntologyEditModal,
  },
  setup() {
    useHead({ title: 'Manage Ontology' });
    return useOntologyAdminTable();
  },
});
</script>

<style scoped>
/* Scoped styles for the ManageOntology component */
.btn-group-xs > .btn,
.btn-xs {
  padding: 0.25rem 0.4rem;
  font-size: 0.875rem;
  line-height: 0.5;
  border-radius: 0.2rem;
}
</style>
