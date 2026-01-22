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
    <b-container fluid>
      <b-row class="justify-content-md-center py-2">
        <b-col
          col
          md="12"
        >
          <h3>Manage Variation Ontology</h3>
          <b-card
            body-class="p-0"
            header-class="p-1"
            border-variant="dark"
          >
            <b-spinner
              v-if="isLoading"
              label="Loading..."
              class="m-5"
            />
            <GenericTable
              v-else
              :items="ontologies"
              :fields="fields"
              :sort-by.sync="sortBy"
              :sort-desc.sync="sortDesc"
            >
              <!-- Custom slot for the 'actions' column -->
              <template v-slot:cell-actions="{ row }">
                <div>
                  <b-button
                    v-b-tooltip.hover.top
                    size="sm"
                    class="mr-1 btn-xs"
                    title="Edit ontology"
                    @click="editOntology(row, $event.target)"
                  >
                    <b-icon
                      icon="pen"
                      font-scale="0.9"
                    />
                  </b-button>
                </div>
              </template>
            </GenericTable>
          </b-card>
        </b-col>
      </b-row>

      <!-- Update Ontology Modal -->
      <b-modal
        :id="updateOntologyModal.id"
        title="Update Ontology"
        ok-title="Update"
        ok-variant="primary"
        cancel-title="Cancel"
        @ok="updateOntologyData"
      >
        <b-form @submit.prevent="updateOntologyData">
          <!-- Display vario_id as a read-only text field -->
          <b-form-group
            label="Vario ID:"
            label-for="input-vario_id"
          >
            <b-form-input
              id="input-vario_id"
              v-model="ontologyToUpdate.vario_id"
              readonly
            />
          </b-form-group>
          <!-- Display update_date as a read-only text field -->
          <b-form-group
            label="Last Update:"
            label-for="input-update_date"
          >
            <b-form-input
              id="input-update_date"
              v-model="ontologyToUpdate.update_date"
              readonly
            />
          </b-form-group>
          <!-- Dynamically create form inputs for each editable ontology attribute -->
          <b-form-group
            v-for="field in editableFields"
            :key="field.key"
            :label="field.label + ':'"
            :label-for="'input-' + field.key"
          >
            <b-form-input
              :id="'input-' + field.key"
              v-model="ontologyToUpdate[field.key]"
            />
          </b-form-group>
        </b-form>
      </b-modal>
    </b-container>
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
          class: 'text-left',
        },
        {
          key: 'vario_name',
          label: 'Name',
          sortable: true,
          sortDirection: 'asc',
          class: 'text-left',
        },
        {
          key: 'definition',
          label: 'Definition',
          sortable: true,
          sortDirection: 'asc',
          class: 'text-left',
        },
        {
          key: 'obsolete',
          label: 'Obsolete',
          sortable: true,
          sortDirection: 'asc',
          class: 'text-left',
        },
        {
          key: 'is_active',
          label: 'Active',
          sortable: true,
          sortDirection: 'asc',
          class: 'text-left',
        },
        {
          key: 'sort',
          label: 'Sort',
          sortable: true,
          sortDirection: 'asc',
          class: 'text-left',
        },
        {
          key: 'update_date',
          label: 'Update',
          sortable: true,
          sortDirection: 'asc',
          class: 'text-left',
        },
        {
          key: 'actions',
          label: 'Actions',
          class: 'text-center',
        },
      ],
      isLoading: false,
      sortBy: 'vario_id',
      sortDesc: false,
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
