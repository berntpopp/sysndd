<!-- views/admin/ManageAnnotations.vue -->
<template>
  <div class="container-fluid">
    <b-container fluid>
      <!-- Updating Ontology Annotations Section -->
      <b-row class="justify-content-md-center py-2">
        <b-col
          col
          md="10"
        >
          <h3>Manage Annotations</h3>
          <b-card
            header-tag="header"
            align="left"
            body-class="p-1"
            header-class="p-1"
            border-variant="dark"
            class="mb-3"
          >
            <template #header>
              <h5 class="mb-0 text-start font-weight-bold">
                Updating Ontology Annotations
              </h5>
            </template>

            <b-button
              variant="primary"
              :disabled="loading"
              @click="updateOntologyAnnotations"
            >
              <b-spinner
                v-if="loading"
                small
                type="grow"
              />
              {{ loading ? 'Updating...' : 'Update Ontology Annotations' }}
            </b-button>
          </b-card>
        </b-col>
      </b-row>

      <!-- Updating HGNC Data Section -->
      <b-row class="justify-content-md-center py-2">
        <b-col
          col
          md="10"
        >
          <b-card
            header-tag="header"
            align="left"
            body-class="p-1"
            header-class="p-1"
            border-variant="dark"
            class="mb-3"
          >
            <template #header>
              <h5 class="mb-0 text-start font-weight-bold">
                Updating HGNC Data
              </h5>
            </template>

            <b-button
              variant="primary"
              :disabled="loadingHgnc"
              @click="updateHgncData"
            >
              <b-spinner
                v-if="loadingHgnc"
                small
                type="grow"
              />
              {{ loadingHgnc ? 'Updating...' : 'Update HGNC Data' }}
            </b-button>
          </b-card>
        </b-col>
      </b-row>
    </b-container>
  </div>
</template>

<script>
import toastMixin from '@/assets/js/mixins/toastMixin';

export default {
  name: 'ManageAnnotations',
  mixins: [toastMixin],
  data() {
    return {
      loading: false, // Indicates the loading state of the API call
      loadingHgnc: false, // Loading state for HGNC data update
    };
  },
  methods: {
    async updateOntologyAnnotations() {
      this.loading = true; // Set loading to true to show spinner and disable button
      try {
        const response = await this.axios.put(`${process.env.VUE_APP_API_URL}/api/admin/update_ontology`, {}, {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });
        this.makeToast('Ontology annotations updated successfully', 'Success', 'success');
      } catch (error) {
        this.makeToast('Failed to update ontology annotations', 'Error', 'danger');
      } finally {
        this.loading = false; // Reset loading to false after the API call
      }
    },
    async updateHgncData() {
      this.loadingHgnc = true;
      try {
        const response = await this.axios.put(`${process.env.VUE_APP_API_URL}/api/admin/update_hgnc_data`, {}, {
          headers: {
            Authorization: `Bearer ${localStorage.getItem('token')}`,
          },
        });
        this.makeToast('HGNC data updated successfully', 'Success', 'success');
      } catch (error) {
        this.makeToast('Failed to update HGNC data', 'Error', 'danger');
      } finally {
        this.loadingHgnc = false;
      }
    },
  },
};
</script>

<style scoped>
  .btn-group-xs > .btn, .btn-xs {
    padding: .25rem .4rem;
    font-size: .875rem;
    line-height: .5;
    border-radius: .2rem;
  }
</style>
