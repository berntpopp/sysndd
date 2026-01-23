<!-- views/admin/ManageOntology.vue -->
/**
 * ManageOntology component
 *
 * @description This component is used to manage the variation ontology entries. It includes a table
 *              to display the ontology data and a modal to edit the details of a selected ontology entry.
 *
 * @component ManageOntology
 *
 * @script
 *   - Imports the GenericTable component for displaying data in a table format.
 *   - Uses the toastMixin for displaying toast notifications.
 *   - Defines the data properties for holding ontologies, table fields, loading state, sorting options, and modal data.
 *   - Contains methods for loading ontology data, editing an ontology entry, and updating ontology data via API.
 *
 * @style
 *   - Uses the 'scoped' attribute to limit the styles to this component only.
 *   - Defines styles for small buttons and inputs within the component.
 */

<template>
  <div class="container-fluid">
    <BContainer fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol
          col
          md="12"
        >
          <h3>Manage Variation Ontology</h3>
          <BCard
            body-class="p-0"
            header-class="p-1"
            border-variant="dark"
          >
            <BSpinner
              v-if="isLoading"
              label="Loading..."
              class="m-5"
            />
            <GenericTable
              v-else
              :items="ontologies"
              :fields="fields"
              :sort-by="sortBy"
              @update:sort-by="handleSortByUpdate"
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
            </GenericTable>
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
          <BFormGroup
            label="Vario ID:"
            label-for="input-vario_id"
          >
            <BFormInput
              id="input-vario_id"
              v-model="ontologyToUpdate.vario_id"
              readonly
            />
          </BFormGroup>
          <!-- Display update_date as a read-only text field -->
          <BFormGroup
            label="Last Update:"
            label-for="input-update_date"
          >
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
import GenericTable from '@/components/small/GenericTable.vue';
import toastMixin from '@/assets/js/mixins/toastMixin';
import useModalControls from '@/composables/useModalControls';

// Import the Pinia store
import { useUiStore } from '@/stores/ui';

export default {
  name: 'ManageOntology',
  components: {
    GenericTable,
  },
  mixins: [toastMixin],
  data() {
    return {
      ontologies: [],
      fields: [
        {
          key: 'vario_id',
          label: 'Vario ID',
          sortable: true,
          sortDirection: 'asc',
          class: 'text-start',
        },
        {
          key: 'vario_name',
          label: 'Name',
          sortable: true,
          sortDirection: 'asc',
          class: 'text-start',
        },
        {
          key: 'definition',
          label: 'Definition',
          sortable: true,
          sortDirection: 'asc',
          class: 'text-start',
        },
        {
          key: 'obsolete',
          label: 'Obsolete',
          sortable: true,
          sortDirection: 'asc',
          class: 'text-start',
        },
        {
          key: 'is_active',
          label: 'Active',
          sortable: true,
          sortDirection: 'asc',
          class: 'text-start',
        },
        {
          key: 'sort',
          label: 'Sort',
          sortable: true,
          sortDirection: 'asc',
          class: 'text-start',
        },
        {
          key: 'update_date',
          label: 'Update',
          sortable: true,
          sortDirection: 'asc',
          class: 'text-start',
        },
        {
          key: 'actions',
          label: 'Actions',
          class: 'text-center',
        },
      ],
      isLoading: false,
      // Bootstrap-Vue-Next uses array-based sortBy format
      sortBy: [{ key: 'vario_id', order: 'asc' }],
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
  },
  mounted() {
    this.loadOntologyTableData();
  },
  methods: {
    /**
     * Loads ontology data from the API
     *
     * @async
     * @function loadOntologyTableData
     * @returns {Promise<void>}
     */
    async loadOntologyTableData() {
      this.isLoading = true;
      const apiUrl = `${process.env.VUE_APP_API_URL}/api/ontology/variant/table`;
      try {
        const response = await this.axios.get(apiUrl, {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });
        this.ontologies = response.data;

        const uiStore = useUiStore();
        uiStore.requestScrollbarUpdate();
      } catch (e) {
        this.makeToast(e, 'Error', 'danger');
      }

      this.isLoading = false;
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
      const apiUrl = `${process.env.VUE_APP_API_URL}/api/ontology/variant/update`;
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
    /**
     * Handles sortBy updates from Bootstrap-Vue-Next GenericTable
     * @param {Array} newSortBy - Array of sort objects [{key, order}]
     */
    handleSortByUpdate(newSortBy) {
      this.sortBy = newSortBy;
    },
  },
};
</script>

<style scoped>
  /* Scoped styles for the ManageOntology component */
  .btn-group-xs > .btn, .btn-xs {
    padding: .25rem .4rem;
    font-size: .875rem;
    line-height: .5;
    border-radius: .2rem;
  }
</style>
