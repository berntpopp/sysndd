<!-- views/admin/ManageOntology.vue -->
/**
 * ManageOntology component
 *
 * @description This component is used to manage the variation ontology entries. It includes a modern
 *              table with search, filtering, pagination, and URL state sync following the TablesEntities pattern.
 *
 * @component ManageOntology
 *
 * @script
 *   - Imports the GenericTable and TablePaginationControls components
 *   - Uses composables for URL parsing, table data, and Excel export
 *   - Includes module-level caching to prevent duplicate API calls
 *   - Implements debounced search with 300ms delay
 *   - Manages filter state with active/obsolete filters
 *   - Syncs table state to URL for bookmarkable views
 *
 * @style
 *   - Uses the 'scoped' attribute to limit the styles to this component only.
 *   - Defines styles for small buttons and inputs within the component.
 */

<template>
  <div class="container-fluid">
    <BContainer fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol md="12">
          <BCard
            header-tag="header"
            body-class="p-0"
            header-class="p-1"
            border-variant="dark"
          >
            <template #header>
              <BRow>
                <BCol>
                  <h5 class="mb-1 text-start">
                    <strong>Manage Variation Ontology</strong>
                    <BBadge variant="secondary" class="ms-2">
                      {{ totalRows }} terms
                    </BBadge>
                  </h5>
                </BCol>
                <BCol class="text-end">
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
                </BCol>
              </BRow>
            </template>

            <!-- Search and Pagination Row -->
            <BRow class="px-2 py-2">
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
            <BRow class="px-2 pb-2">
              <BCol sm="3">
                <BFormSelect
                  v-model="filter.is_active.content"
                  :options="activeFilterOptions"
                  size="sm"
                  @update:model-value="filtered()"
                >
                  <template #first>
                    <BFormSelectOption :value="null">
                      All Status
                    </BFormSelectOption>
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
                    <BFormSelectOption :value="null">
                      All Terms
                    </BFormSelectOption>
                  </template>
                </BFormSelect>
              </BCol>
              <BCol sm="6" class="text-end">
                <span class="text-muted small">
                  Showing {{ totalRows > 0 ? (currentPage - 1) * perPage + 1 : 0 }}-{{ Math.min(currentPage * perPage, totalRows) }} of {{ totalRows }}
                </span>
              </BCol>
            </BRow>

            <!-- Active Filter Pills -->
            <BRow v-if="hasActiveFilters" class="px-2 pb-2">
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

            <!-- Table with loading overlay -->
            <div class="position-relative">
              <BSpinner
                v-if="isBusy"
                class="position-absolute top-50 start-50 translate-middle"
                variant="primary"
                style="z-index: 10;"
              />

              <!-- Empty state -->
              <div v-if="!isBusy && ontologies.length === 0" class="text-center py-4">
                <i class="bi bi-journal-text fs-1 text-muted" />
                <p class="text-muted mt-2">
                  No ontology terms found matching your filters
                </p>
                <BButton v-if="hasActiveFilters" variant="link" @click="removeFilters">
                  Clear filters
                </BButton>
              </div>

              <GenericTable
                v-else
                :items="ontologies"
                :fields="fields"
                :sort-by="sortBy"
                :class="{ 'opacity-50': isBusy }"
                @update:sort-by="handleSortUpdate"
              >
                <!-- Custom slot for the 'actions' column -->
                <template v-slot:cell-actions="{ row }">
                  <div>
                    <BButton
                      v-b-tooltip.hover.top
                      size="sm"
                      class="me-1 btn-xs"
                      title="Edit ontology"
                      @click="editOntology(row, $event.target)"
                    >
                      <i class="bi bi-pen" />
                    </BButton>
                  </div>
                </template>

                <!-- Format obsolete as badge -->
                <template v-slot:cell-obsolete="{ row }">
                  <BBadge :variant="row.obsolete ? 'warning' : 'success'">
                    {{ row.obsolete ? 'Yes' : 'No' }}
                  </BBadge>
                </template>

                <!-- Format is_active as badge -->
                <template v-slot:cell-is_active="{ row }">
                  <BBadge :variant="row.is_active ? 'success' : 'secondary'">
                    {{ row.is_active ? 'Active' : 'Inactive' }}
                  </BBadge>
                </template>
              </GenericTable>
            </div>
          </BCard>
        </BCol>
      </BRow>

      <!-- Update Ontology Modal -->
      <BModal
        :id="updateOntologyModal.id"
        title="Update Ontology"
        ok-title="Update"
        ok-variant="primary"
        cancel-title="Cancel"
        @ok="updateOntologyData"
      >
        <BForm @submit.prevent="updateOntologyData">
          <!-- Display vario_id as a read-only text field -->
          <BFormGroup label="Vario ID:" label-for="input-vario_id">
            <BFormInput
              id="input-vario_id"
              v-model="ontologyToUpdate.vario_id"
              readonly
            />
          </BFormGroup>
          <!-- Display update_date as a read-only text field -->
          <BFormGroup label="Last Update:" label-for="input-update_date">
            <BFormInput
              id="input-update_date"
              v-model="ontologyToUpdate.update_date"
              readonly
            />
          </BFormGroup>
          <!-- Dynamically create form inputs for each editable ontology attribute -->
          <BFormGroup
            v-for="field in editableFields"
            :key="field.key"
            :label="field.label + ':'"
            :label-for="'input-' + field.key"
          >
            <BFormInput
              :id="'input-' + field.key"
              v-model="ontologyToUpdate[field.key]"
            />
          </BFormGroup>
        </BForm>
      </BModal>
    </BContainer>
  </div>
</template>

<script>
import { ref, inject } from 'vue';
import GenericTable from '@/components/small/GenericTable.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';
import useToast from '@/composables/useToast';
import useModalControls from '@/composables/useModalControls';
import { useUrlParsing, useTableData, useExcelExport } from '@/composables';

// Import the Pinia store
import { useUiStore } from '@/stores/ui';

// Module-level variables to track API calls across component remounts
// This survives when Vue Router remounts the component on URL changes
let moduleLastApiParams = null;
let moduleApiCallInProgress = false;
let moduleLastApiCallTime = 0;
let moduleLastApiResponse = null; // Cache last API response for remounted components

export default {
  name: 'ManageOntology',
  components: {
    GenericTable,
    TablePaginationControls,
  },
  setup() {
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

    const axios = inject('axios');

    return {
      ...tableData,
      filter,
      makeToast,
      filterObjToStr,
      filterStrToObj,
      sortStringToVariables,
      isExporting,
      exportToExcel,
      axios,
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
      ontologyToUpdate: {},
      updateOntologyModal: {
        id: 'update-ontology-modal',
        title: '',
        content: [],
      },
    };
  },
  computed: {
    /**
     * Computed property to filter out non-editable fields
     *
     * @returns {Array} List of editable fields
     */
    editableFields() {
      // Filter out non-editable fields like 'actions', 'vario_id', and 'update_date'
      return this.fields.filter(
        (field) => field.key !== 'actions' && field.key !== 'vario_id' && field.key !== 'update_date',
      );
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
        if (this.filter[key] && typeof this.filter[key] === 'object' && 'content' in this.filter[key]) {
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
      const urlParam = `sort=${this.sort}&filter=${this.filter_string}&page_after=${this.currentItemID}&page_size=${this.perPage}`;
      const now = Date.now();

      // Prevent duplicate API calls using module-level tracking
      if (moduleLastApiParams === urlParam && (now - moduleLastApiCallTime) < 500) {
        if (moduleLastApiResponse) {
          this.applyApiResponse(moduleLastApiResponse);
        }
        return;
      }

      // Also prevent if a call is already in progress with same params
      if (moduleApiCallInProgress && moduleLastApiParams === urlParam) {
        return;
      }

      moduleLastApiParams = urlParam;
      moduleLastApiCallTime = now;
      moduleApiCallInProgress = true;
      this.isBusy = true;

      const apiUrl = `${import.meta.env.VITE_API_URL}/api/ontology/variant/table?${urlParam}`;

      try {
        const response = await this.axios.get(apiUrl, {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });
        moduleApiCallInProgress = false;
        moduleLastApiResponse = response.data;
        this.applyApiResponse(response.data);
        this.updateBrowserUrl();
        this.isBusy = false;
      } catch (e) {
        moduleApiCallInProgress = false;
        this.makeToast(e, 'Error', 'danger');
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
     * @param {Object} button - The button that triggered the edit action
     * @returns {void}
     */
    editOntology(item, button) {
      this.updateOntologyModal.title = `${item.vario_id}`;
      this.ontologyToUpdate = item;
      const { showModal } = useModalControls();
      showModal(this.updateOntologyModal.id);
    },

    /**
     * Updates the ontology data via the API
     *
     * @async
     * @function updateOntologyData
     * @returns {Promise<void>}
     */
    async updateOntologyData() {
      const apiUrl = `${import.meta.env.VITE_API_URL}/api/ontology/variant/update`;
      try {
        const response = await this.axios.put(
          apiUrl,
          { ontology_details: this.ontologyToUpdate },
          {
            headers: {
              Authorization: `Bearer ${localStorage.getItem('token')}`,
            },
          },
        );
        this.makeToast(response.data.message, 'Success', 'success');
        // Update the ontology in the local state
        const index = this.ontologies.findIndex((o) => o.vario_id === this.ontologyToUpdate.vario_id);
        if (index !== -1) {
          this.ontologies.splice(index, 1, this.ontologyToUpdate);
        }
      } catch (e) {
        this.makeToast(e.response.data.error || e.message, 'Error', 'danger');
      }
      // Close the modal after the update
      const { hideModal } = useModalControls();
      hideModal(this.updateOntologyModal.id);
      // Reset the ontologyToUpdate object
      this.ontologyToUpdate = {};
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
