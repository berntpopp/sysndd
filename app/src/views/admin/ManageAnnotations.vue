<!-- views/admin/ManageAnnotations.vue -->
<template>
  <div class="container-fluid">
    <b-container fluid>
      <b-row class="justify-content-md-center py-2">
        <b-col
          col
          md="10"
        >
          <h3>Manage Annotations</h3>

          <!-- Updating Ontology Annotations Section -->
          <b-card
            header-tag="header"
            align="left"
            body-class="p-1"
            header-class="p-1"
            border-variant="dark"
            class="mb-3"
          >
            <template #header>
              <h5 class="mb-0 text-left font-weight-bold">
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
    </b-container>
  </div>
</template>

<script>
export default {
  name: 'ManageAnnotations',
  data() {
    return {
      loading: false, // Indicates the loading state of the API call
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
        this.$bvToast.toast('Ontology annotations updated successfully', {
          title: 'Success',
          variant: 'success',
          solid: true,
        });
      } catch (error) {
        this.$bvToast.toast('Failed to update ontology annotations', {
          title: 'Error',
          variant: 'danger',
          solid: true,
        });
      } finally {
        this.loading = false; // Reset loading to false after the API call
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
