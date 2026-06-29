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
import { useHead } from '@unhead/vue';
import AuthenticatedPageShell from '@/components/layout/AuthenticatedPageShell.vue';
import TableShell from '@/components/table/TableShell.vue';
import { ref } from 'vue';
import GenericTable from '@/components/small/GenericTable.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';
import OntologyMobileRows from './components/OntologyMobileRows.vue';
import OntologyEditModal from './components/OntologyEditModal.vue';
import useToast from '@/composables/useToast';
import { useUrlParsing, useTableData, useExcelExport } from '@/composables';
// Migrated to the typed ontology client (feat/admin-typed-client-migration):
// `listVariantOntology` / `updateVariantOntology` delegate to `apiClient`, so
// the request interceptor still injects the Bearer header from
// `useAuth().token.value` (single source of truth for session auth).
import { listVariantOntology, updateVariantOntology } from '@/api/ontology';
import { createTableRequestCoordinator } from '@/utils/tableRequestCoordinator';

// Import the Pinia store
import { useUiStore } from '@/stores/ui';

// Module-level request coordinator (survives Vue Router remounts on URL change).
// Replaces the previous hand-rolled module-level dedup, which deduped only
// identical params and applied every response unconditionally — so a slow
// earlier request could overwrite the table after a newer filter was applied.
// The coordinator dedupes identical concurrent requests, serves a short recent
// cache, and (via isCurrent) drops stale responses.
const ontologyRequestCoordinator = createTableRequestCoordinator();

export default {
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
    const { makeToast } = useToast();
    const { filterObjToStr, filterStrToObj, sortStringToVariables } = useUrlParsing();
    const { isExporting, exportToExcel } = useExcelExport();

    const tableData = useTableData({
      pageSizeInput: 25,
      sortInput: '+vario_id',
      pageAfterInput: '0',
    });

    // Filter object structure for ontology table
    const filter = ref({
      any: { content: null, join_char: null, operator: 'contains' },
      vario_id: { content: null, join_char: null, operator: 'contains' },
      vario_name: { content: null, join_char: null, operator: 'contains' },
      definition: { content: null, join_char: null, operator: 'contains' },
      obsolete: { content: null, join_char: null, operator: 'equals' },
      is_active: { content: null, join_char: null, operator: 'equals' },
    });

    // Modal visibility state - Bootstrap-Vue-Next uses v-model pattern
    const showEditModal = ref(false);
    const ontologyToEdit = ref({});

    return {
      ...tableData,
      filter,
      makeToast,
      filterObjToStr,
      filterStrToObj,
      sortStringToVariables,
      isExporting,
      exportToExcel,
      showEditModal,
      ontologyToEdit,
    };
  },
  data() {
    return {
      // Flag to prevent watchers from triggering during initialization
      isInitializing: true,
      // Debounce timer for loadData to prevent duplicate calls
      loadDataDebounceTimer: null,
      // Pagination state not in useTableData
      totalPages: 0,
      // Table data
      ontologies: [],
      fields: [
        {
          key: 'vario_id',
          label: 'ID',
          sortable: true,
          filterable: true,
          class: 'text-start',
        },
        {
          key: 'vario_name',
          label: 'Name',
          sortable: true,
          filterable: true,
          class: 'text-start',
        },
        {
          key: 'definition',
          label: 'Definition',
          sortable: true,
          filterable: true,
          class: 'text-start',
        },
        {
          key: 'obsolete',
          label: 'Obsolete',
          sortable: true,
          selectable: true,
          class: 'text-center',
        },
        {
          key: 'is_active',
          label: 'Active',
          sortable: true,
          selectable: true,
          class: 'text-center',
        },
        {
          key: 'sort',
          label: 'Sort',
          sortable: true,
          class: 'text-center',
        },
        {
          key: 'update_date',
          label: 'Updated',
          sortable: true,
          class: 'text-start',
        },
        {
          key: 'actions',
          label: 'Actions',
          class: 'text-center',
        },
      ],
      mobileSortOptions: [
        { value: '+vario_id', text: 'ID ascending' },
        { value: '-vario_id', text: 'ID descending' },
        { value: '+vario_name', text: 'Name ascending' },
        { value: '-vario_name', text: 'Name descending' },
        { value: '+update_date', text: 'Updated ascending' },
        { value: '-update_date', text: 'Updated descending' },
      ],
    };
  },
  computed: {
    mobileSortValue: {
      get() {
        return this.sort || '+vario_id';
      },
      set(value) {
        const sort_object = this.sortStringToVariables(value);
        this.sortBy = sort_object.sortBy;
        this.sort = value;
        this.currentItemID = 0;
        this.filtered();
      },
    },
    activeFilterOptions() {
      return [
        { value: '1', text: 'Active' },
        { value: '0', text: 'Inactive' },
      ];
    },
    obsoleteFilterOptions() {
      return [
        { value: '0', text: 'Current' },
        { value: '1', text: 'Obsolete' },
      ];
    },
    hasActiveFilters() {
      return Object.values(this.filter).some((f) => f.content !== null && f.content !== '');
    },
    activeFilters() {
      const filters = [];
      if (this.filter.any.content) {
        filters.push({ key: 'any', label: 'Search', value: this.filter.any.content });
      }
      if (this.filter.is_active.content !== null) {
        filters.push({
          key: 'is_active',
          label: 'Status',
          value: this.filter.is_active.content === '1' ? 'Active' : 'Inactive',
        });
      }
      if (this.filter.obsolete.content !== null) {
        filters.push({
          key: 'obsolete',
          label: 'Terms',
          value: this.filter.obsolete.content === '1' ? 'Obsolete' : 'Current',
        });
      }
      return filters;
    },
  },
  watch: {
    // Watch for filter changes (deep required for Vue 3 behavior)
    // Skip during initialization to prevent multiple API calls
    filter: {
      handler() {
        if (this.isInitializing) return;
        this.filtered();
      },
      deep: true,
    },
    // Watch for sortBy changes (deep watch for array)
    // Skip during initialization to prevent multiple API calls
    sortBy: {
      handler() {
        if (this.isInitializing) return;
        this.handleSortByOrDescChange();
      },
      deep: true,
    },
  },
  mounted() {
    // Initialize from URL parameters
    const urlParams = new URLSearchParams(window.location.search);
    if (urlParams.get('sort')) {
      const sort_object = this.sortStringToVariables(urlParams.get('sort'));
      this.sortBy = sort_object.sortBy;
      this.sort = urlParams.get('sort');
    }
    if (urlParams.get('filter')) {
      this.filter = this.filterStrToObj(urlParams.get('filter'), this.filter);
      this.filter_string = urlParams.get('filter');
    }
    if (urlParams.get('page_after')) {
      this.currentItemID = parseInt(urlParams.get('page_after'), 10) || 0;
    }
    if (urlParams.get('page_size')) {
      this.perPage = parseInt(urlParams.get('page_size'), 10) || 25;
    }

    this.$nextTick(() => {
      this.loadData();
      this.$nextTick(() => {
        this.isInitializing = false;
      });
    });
  },
  methods: {
    // Update browser URL with current table state
    // Uses history.replaceState instead of router.replace to prevent component remount
    updateBrowserUrl() {
      // Don't update URL during initialization - preserves URL params from navigation
      if (this.isInitializing) return;

      const searchParams = new URLSearchParams();

      if (this.sort) {
        searchParams.set('sort', this.sort);
      }
      if (this.filter_string) {
        searchParams.set('filter', this.filter_string);
      }
      if (this.currentItemID > 0) {
        searchParams.set('page_after', String(this.currentItemID));
      }
      searchParams.set('page_size', String(this.perPage));

      // Use history.replaceState to update URL without triggering Vue Router navigation
      const newUrl = `${window.location.pathname}?${searchParams.toString()}`;
      window.history.replaceState({ ...window.history.state }, '', newUrl);
    },

    // Filter method that triggers data load
    filtered() {
      const filter_string_loc = this.filterObjToStr(this.filter);
      if (filter_string_loc !== this.filter_string) {
        this.filter_string = filter_string_loc;
      }
      this.currentItemID = 0; // Reset to first page on filter change
      this.loadData();
    },

    // Handle page change events
    handlePageChange(value) {
      if (value === 1) {
        this.currentItemID = 0;
      } else if (value === this.totalPages) {
        this.currentItemID = Number(this.lastItemID) || 0;
      } else if (value > this.currentPage) {
        this.currentItemID = Number(this.nextItemID) || 0;
      } else if (value < this.currentPage) {
        this.currentItemID = Number(this.prevItemID) || 0;
      }
      this.filtered();
    },

    // Handle per-page change events
    handlePerPageChange(newPerPage) {
      this.perPage = parseInt(newPerPage, 10);
      this.currentItemID = 0;
      this.filtered();
    },

    // Handle sort changes
    handleSortByOrDescChange() {
      this.currentItemID = 0;
      const sortColumn = this.sortBy.length > 0 ? this.sortBy[0].key : '';
      const sortOrder = this.sortBy.length > 0 ? this.sortBy[0].order : 'asc';
      const isDesc = sortOrder === 'desc';
      this.sort = (isDesc ? '-' : '+') + sortColumn;
      this.filtered();
    },

    // Remove all filters
    removeFilters() {
      Object.keys(this.filter).forEach((key) => {
        if (
          this.filter[key] &&
          typeof this.filter[key] === 'object' &&
          'content' in this.filter[key]
        ) {
          this.filter[key].content = null;
        }
      });
      this.filtered();
    },

    // Clear a specific filter
    clearFilter(key) {
      if (this.filter[key]) {
        this.filter[key].content = null;
      }
      this.filtered();
    },

    // Handle sort updates from GenericTable
    handleSortUpdate(newSortBy) {
      this.sortBy = newSortBy;
      this.handleSortByOrDescChange();
    },

    // Load data with debouncing
    loadData() {
      if (this.loadDataDebounceTimer) {
        clearTimeout(this.loadDataDebounceTimer);
      }
      this.loadDataDebounceTimer = setTimeout(() => {
        this.loadDataDebounceTimer = null;
        this.doLoadData();
      }, 50);
    },

    // Actual data loading method with module-level caching
    async doLoadData() {
      const buildParams = () =>
        `sort=${this.sort}&filter=${this.filter_string}&page_after=${this.currentItemID}&page_size=${this.perPage}`;
      const urlParam = buildParams();
      this.isBusy = true;

      const result = await ontologyRequestCoordinator.request({
        params: urlParam,
        // Typed ontology client resolves with the response payload directly;
        // apiClient's interceptor adds the Bearer header.
        fetcher: () =>
          listVariantOntology({
            sort: this.sort,
            filter: this.filter_string,
            page_after: this.currentItemID,
            page_size: this.perPage,
          }),
        apply: (data, source) => {
          this.applyApiResponse(data);
          if (source === 'network') {
            this.updateBrowserUrl();
          }
        },
        onError: (e) => this.makeToast(e, 'Error', 'danger'),
        isCurrent: (params) => buildParams() === params,
      });

      if (result.handled) {
        this.isBusy = false;
      }
    },

    /**
     * Apply API response data to component state.
     * Extracted to allow reuse when skipping duplicate API calls.
     * @param {Object} data - API response data
     */
    applyApiResponse(data) {
      this.ontologies = data.data;
      this.totalRows = data.meta[0].totalItems;
      this.$nextTick(() => {
        this.currentPage = data.meta[0].currentPage;
      });
      this.totalPages = data.meta[0].totalPages;
      this.prevItemID = Number(data.meta[0].prevItemID) || 0;
      this.currentItemID = Number(data.meta[0].currentItemID) || 0;
      this.nextItemID = Number(data.meta[0].nextItemID) || 0;
      this.lastItemID = Number(data.meta[0].lastItemID) || 0;
      this.executionTime = data.meta[0].executionTime;

      const uiStore = useUiStore();
      uiStore.requestScrollbarUpdate();
    },

    /**
     * Handle Excel export
     */
    handleExport() {
      this.exportToExcel(this.ontologies, {
        filename: `ontology_export_${new Date().toISOString().split('T')[0]}`,
        sheetName: 'Ontology',
        headers: {
          vario_id: 'Vario ID',
          vario_name: 'Name',
          definition: 'Definition',
          obsolete: 'Obsolete',
          is_active: 'Active',
          sort: 'Sort Order',
          update_date: 'Last Updated',
        },
      });
    },

    /**
     * Opens the edit modal with the selected ontology data
     *
     * @function editOntology
     * @param {Object} item - The selected ontology item
     * @returns {void}
     */
    editOntology(item) {
      // Deep copy to prevent direct mutation of table data
      this.ontologyToEdit = JSON.parse(JSON.stringify(item));
      this.showEditModal = true;
    },

    /**
     * Updates the ontology data via the API
     *
     * @async
     * @function updateOntologyData
     * @returns {Promise<void>}
     */
    async updateOntologyData() {
      try {
        // Typed ontology client routes through apiClient (Bearer via interceptor).
        const data = await updateVariantOntology({
          ontology_details: this.ontologyToEdit,
        });
        this.makeToast(data.message, 'Success', 'success');
        // Update the ontology in the local state
        const index = this.ontologies.findIndex((o) => o.vario_id === this.ontologyToEdit.vario_id);
        if (index !== -1) {
          this.ontologies.splice(index, 1, { ...this.ontologyToEdit });
        }
        // Close the modal after successful update
        this.showEditModal = false;
        // Reset the ontologyToEdit object
        this.ontologyToEdit = {};
      } catch (e) {
        this.makeToast(e.response?.data?.error || e.message, 'Error', 'danger');
      }
    },
  },
};
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
