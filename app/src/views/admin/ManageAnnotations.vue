<!-- views/admin/ManageAnnotations.vue -->
<template>
  <div class="container-fluid">
    <BContainer fluid>
      <!-- Updating Ontology Annotations Section -->
      <BRow class="justify-content-md-center py-2">
        <BCol
          col
          md="10"
        >
          <h3>Manage Annotations</h3>
          <BCard
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

            <BButton
              variant="primary"
              :disabled="loading"
              @click="updateOntologyAnnotations"
            >
              <BSpinner
                v-if="loading"
                small
                type="grow"
              />
              {{ loading ? 'Updating...' : 'Update Ontology Annotations' }}
            </BButton>
          </BCard>
        </BCol>
      </BRow>

      <!-- Updating HGNC Data Section -->
      <BRow class="justify-content-md-center py-2">
        <BCol
          col
          md="10"
        >
          <BCard
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

            <BButton
              variant="primary"
              :disabled="loadingHgnc"
              @click="updateHgncData"
            >
              <BSpinner
                v-if="loadingHgnc"
                small
                type="grow"
              />
              {{ loadingHgnc ? 'Updating...' : 'Update HGNC Data' }}
            </BButton>
          </BCard>
        </BCol>
      </BRow>
    </BContainer>
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
        const response = await this.axios.put(`${import.meta.env.VITE_API_URL}/api/admin/update_ontology`, {}, {
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
        const response = await this.axios.put(`${import.meta.env.VITE_API_URL}/api/admin/update_hgnc_data`, {}, {
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
