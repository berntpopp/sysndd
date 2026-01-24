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
              {{ loading ? jobStep : 'Update Ontology Annotations' }}
            </BButton>

            <div
              v-if="jobStatus"
              class="mt-2 small text-muted"
            >
              Status: {{ jobStatus }}
              <span v-if="jobStep"> - {{ jobStep }}</span>
            </div>
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
import useToast from '@/composables/useToast';

export default {
  name: 'ManageAnnotations',
  setup() {
    const { makeToast } = useToast();
    return { makeToast };
  },
  data() {
    return {
      loading: false, // Indicates the loading state of the API call
      loadingHgnc: false, // Loading state for HGNC data update
      // Async job state for ontology updates
      jobId: null,
      jobStatus: null,
      jobStep: '',
      pollInterval: null,
    };
  },
  beforeUnmount() {
    this.stopPolling();
  },
  methods: {
    async updateOntologyAnnotations() {
      this.loading = true;
      this.jobStatus = null;
      this.jobStep = 'Starting update...';

      try {
        // Call async endpoint
        const response = await this.axios.put(
          `${import.meta.env.VITE_API_URL}/api/admin/update_ontology_async`,
          {},
          {
            headers: {
              Authorization: `Bearer ${localStorage.getItem('token')}`,
            },
          },
        );

        if (response.data.error) {
          this.makeToast(response.data.message || 'Failed to start update', 'Error', 'danger');
          this.loading = false;
          return;
        }

        this.jobId = response.data.job_id;
        this.jobStatus = 'accepted';
        this.jobStep = 'Job submitted, starting...';

        // Start polling
        this.startPolling();
      } catch (error) {
        this.makeToast('Failed to start ontology update', 'Error', 'danger');
        this.loading = false;
      }
    },
    startPolling() {
      // Poll every 3 seconds
      this.pollInterval = setInterval(async () => {
        await this.checkJobStatus();
      }, 3000);
    },
    stopPolling() {
      if (this.pollInterval) {
        clearInterval(this.pollInterval);
        this.pollInterval = null;
      }
    },
    async checkJobStatus() {
      if (!this.jobId) return;

      try {
        const response = await this.axios.get(
          `${import.meta.env.VITE_API_URL}/api/jobs/${this.jobId}`,
          {
            headers: {
              Authorization: `Bearer ${localStorage.getItem('token')}`,
            },
          },
        );

        const data = response.data;

        if (data.error === 'JOB_NOT_FOUND') {
          this.stopPolling();
          this.makeToast('Job not found', 'Error', 'danger');
          this.loading = false;
          return;
        }

        this.jobStatus = data.status;
        this.jobStep = data.step || this.jobStep;

        if (data.status === 'completed') {
          this.stopPolling();
          this.loading = false;
          this.makeToast('Ontology annotations updated successfully', 'Success', 'success');
        } else if (data.status === 'failed') {
          this.stopPolling();
          this.loading = false;
          const errorMsg = data.error?.message || 'Update failed';
          this.makeToast(errorMsg, 'Error', 'danger');
        }
        // If still running, polling continues
      } catch (error) {
        this.stopPolling();
        this.loading = false;
        this.makeToast('Failed to check job status', 'Error', 'danger');
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
