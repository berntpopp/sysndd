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
                class="me-2"
              />
              {{ loading ? 'Updating...' : 'Update Ontology Annotations' }}
            </BButton>

            <!-- Progress display -->
            <div
              v-if="loading || jobStatus"
              class="mt-3"
            >
              <div class="d-flex align-items-center mb-2">
                <span
                  class="badge me-2"
                  :class="statusBadgeClass"
                >
                  {{ jobStatus || 'starting' }}
                </span>
                <span class="text-muted">{{ jobStep }}</span>
              </div>

              <BProgress
                v-if="loading"
                :value="progressPercent"
                :max="100"
                show-progress
                animated
                :variant="progressVariant"
                height="1.5rem"
              >
                <template #default>
                  {{ progressPercent }}% - {{ currentStepLabel }}
                </template>
              </BProgress>

              <div
                v-if="jobProgress.current && jobProgress.total"
                class="small text-muted mt-1"
              >
                Step {{ jobProgress.current }} of {{ jobProgress.total }}
              </div>
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
      jobProgress: {
        current: 0,
        total: 0,
      },
    };
  },
  computed: {
    progressPercent() {
      if (this.jobProgress.total > 0) {
        return Math.round((this.jobProgress.current / this.jobProgress.total) * 100);
      }
      // Estimate progress based on step name
      const stepProgress = {
        'Starting update...': 5,
        'Job submitted, starting...': 10,
        'Downloading mim2gene.txt': 15,
        'Parsing mim2gene.txt': 25,
        'Fetching disease names from JAX API': 40,
        'Downloading MONDO SSSOM': 60,
        'Parsing MONDO mappings': 70,
        'Building ontology set': 80,
        'Validating data': 85,
        'Writing to database': 90,
        'Completed': 100,
      };
      return stepProgress[this.jobStep] || 50;
    },
    progressVariant() {
      if (this.jobStatus === 'failed') return 'danger';
      if (this.jobStatus === 'completed') return 'success';
      return 'primary';
    },
    statusBadgeClass() {
      const classes = {
        accepted: 'bg-info',
        running: 'bg-primary',
        completed: 'bg-success',
        failed: 'bg-danger',
      };
      return classes[this.jobStatus] || 'bg-secondary';
    },
    currentStepLabel() {
      if (!this.jobStep) return 'Initializing...';
      // Shorten long step names
      if (this.jobStep.length > 40) {
        return this.jobStep.substring(0, 37) + '...';
      }
      return this.jobStep;
    },
  },
  beforeUnmount() {
    this.stopPolling();
  },
  methods: {
    async updateOntologyAnnotations() {
      this.loading = true;
      this.jobStatus = null;
      this.jobStep = 'Starting update...';
      this.jobProgress = { current: 0, total: 0 };

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
          `${import.meta.env.VITE_API_URL}/api/jobs/${this.jobId}/status`,
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

        // Handle array values from R/Plumber API (extracts first element if array)
        this.jobStatus = Array.isArray(data.status) ? data.status[0] : data.status;
        const stepValue = Array.isArray(data.step) ? data.step[0] : data.step;
        this.jobStep = stepValue || this.jobStep;

        // Update progress if provided
        if (data.progress) {
          this.jobProgress = {
            current: data.progress.current || 0,
            total: data.progress.total || 0,
          };
        }

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
