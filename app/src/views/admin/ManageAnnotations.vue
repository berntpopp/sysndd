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
            body-class="p-1"
            header-class="p-1"
            border-variant="dark"
            class="mb-3 text-start"
          >
            <template #header>
              <h5 class="mb-0 text-start font-weight-bold">
                Updating Ontology Annotations
                <span
                  v-if="annotationDates.omim_update"
                  class="badge bg-secondary ms-2 fw-normal"
                >
                  Last: {{ formatDate(annotationDates.omim_update) }}
                </span>
              </h5>
            </template>

            <BButton
              variant="primary"
              :disabled="ontologyJob.isLoading.value"
              @click="updateOntologyAnnotations"
            >
              <BSpinner
                v-if="ontologyJob.isLoading.value"
                small
                type="grow"
                class="me-2"
              />
              {{ ontologyJob.isLoading.value ? 'Updating...' : 'Update Ontology Annotations' }}
            </BButton>

            <!-- Progress display -->
            <div
              v-if="ontologyJob.isLoading.value || ontologyJob.status.value !== 'idle'"
              class="mt-3"
            >
              <div class="d-flex align-items-center mb-2">
                <span
                  class="badge me-2"
                  :class="ontologyJob.statusBadgeClass.value"
                >
                  {{ ontologyJob.status.value }}
                </span>
                <span class="text-muted">{{ ontologyJob.step.value }}</span>
              </div>

              <BProgress
                v-if="ontologyJob.isLoading.value"
                :value="ontologyJob.hasRealProgress.value ? ontologyJob.progressPercent.value : 100"
                :max="100"
                :animated="true"
                :striped="!ontologyJob.hasRealProgress.value"
                :variant="(ontologyJob.progressVariant.value as 'primary' | 'success' | 'danger')"
                height="1.5rem"
              >
                <template #default>
                  <span v-if="ontologyJob.hasRealProgress.value">{{ ontologyJob.progressPercent.value }}% - {{ ontologyStepLabel }}</span>
                  <span v-else>{{ ontologyStepLabel }} ({{ ontologyJob.elapsedTimeDisplay.value }})</span>
                </template>
              </BProgress>

              <div
                v-if="ontologyJob.progress.value.current && ontologyJob.progress.value.total"
                class="small text-muted mt-1"
              >
                Step {{ ontologyJob.progress.value.current }} of {{ ontologyJob.progress.value.total }}
              </div>
              <div
                v-else-if="ontologyJob.isLoading.value"
                class="small text-muted mt-1"
              >
                Elapsed: {{ ontologyJob.elapsedTimeDisplay.value }} - This may take several minutes...
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
            body-class="p-1"
            header-class="p-1"
            border-variant="dark"
            class="mb-3 text-start"
          >
            <template #header>
              <h5 class="mb-0 text-start font-weight-bold">
                Updating HGNC Data
                <span
                  v-if="annotationDates.hgnc_update"
                  class="badge bg-secondary ms-2 fw-normal"
                >
                  Last: {{ formatDate(annotationDates.hgnc_update) }}
                </span>
              </h5>
            </template>

            <BButton
              variant="primary"
              :disabled="hgncJob.isLoading.value"
              @click="updateHgncData"
            >
              <BSpinner
                v-if="hgncJob.isLoading.value"
                small
                type="grow"
                class="me-2"
              />
              {{ hgncJob.isLoading.value ? 'Updating...' : 'Update HGNC Data' }}
            </BButton>

            <!-- HGNC Progress display -->
            <div
              v-if="hgncJob.isLoading.value || hgncJob.status.value !== 'idle'"
              class="mt-3"
            >
              <div class="d-flex align-items-center mb-2">
                <span
                  class="badge me-2"
                  :class="hgncJob.statusBadgeClass.value"
                >
                  {{ hgncJob.status.value }}
                </span>
                <span class="text-muted">{{ hgncJob.step.value }}</span>
              </div>

              <BProgress
                v-if="hgncJob.isLoading.value"
                :value="hgncJob.hasRealProgress.value ? hgncJob.progressPercent.value : 100"
                :max="100"
                :animated="true"
                :striped="!hgncJob.hasRealProgress.value"
                :variant="(hgncJob.progressVariant.value as 'primary' | 'success' | 'danger')"
                height="1.5rem"
              >
                <template #default>
                  <span v-if="hgncJob.hasRealProgress.value">{{ hgncJob.progressPercent.value }}% - {{ hgncStepLabel }}</span>
                  <span v-else>{{ hgncStepLabel }} ({{ hgncJob.elapsedTimeDisplay.value }})</span>
                </template>
              </BProgress>

              <div
                v-if="hgncJob.progress.value.current && hgncJob.progress.value.total"
                class="small text-muted mt-1"
              >
                Step {{ hgncJob.progress.value.current }} of {{ hgncJob.progress.value.total }}
              </div>
              <div
                v-else-if="hgncJob.isLoading.value"
                class="small text-muted mt-1"
              >
                Elapsed: {{ hgncJob.elapsedTimeDisplay.value }} - Downloading and processing HGNC data...
              </div>
            </div>
          </BCard>
        </BCol>
      </BRow>

      <!-- Deprecated OMIM Entities Section -->
      <BRow class="justify-content-md-center py-2">
        <BCol
          col
          md="10"
        >
          <BCard
            header-tag="header"
            body-class="p-2"
            header-class="p-1"
            border-variant="dark"
            class="mb-3 text-start"
          >
            <template #header>
              <h5 class="mb-0 text-start font-weight-bold d-flex align-items-center">
                Deprecated OMIM Entities
                <span
                  v-if="deprecatedData.mim2gene_date"
                  class="badge bg-secondary ms-2 fw-normal"
                >
                  mim2gene: {{ deprecatedData.mim2gene_date }}
                </span>
                <span
                  v-if="deprecatedData.affected_entity_count > 0"
                  class="badge bg-warning text-dark ms-2 fw-normal"
                >
                  {{ deprecatedData.affected_entity_count }} entities need review
                </span>
                <span
                  v-else-if="!loadingDeprecated && deprecatedData.deprecated_count !== null"
                  class="badge bg-success ms-2 fw-normal"
                >
                  No affected entities
                </span>
              </h5>
            </template>

            <div class="mb-3">
              <BButton
                variant="outline-secondary"
                size="sm"
                :disabled="loadingDeprecated"
                @click="fetchDeprecatedEntities"
              >
                <BSpinner
                  v-if="loadingDeprecated"
                  small
                  type="grow"
                  class="me-1"
                />
                {{ loadingDeprecated ? 'Checking...' : 'Check for Deprecated Entities' }}
              </BButton>
              <small class="text-muted ms-2">
                Compares database entities against OMIM moved/removed entries
              </small>
            </div>

            <div v-if="deprecatedData.message && !deprecatedData.affected_entities?.length">
              <BAlert
                variant="info"
                show
              >
                {{ deprecatedData.message }}
              </BAlert>
            </div>

            <div v-if="deprecatedData.affected_entities?.length > 0">
              <p class="text-muted small mb-2">
                The following entities reference OMIM IDs that have been marked as moved/removed.
                MONDO mappings and replacement suggestions are fetched from the EBI OLS4 API.
              </p>
              <BTable
                :items="deprecatedData.affected_entities"
                :fields="deprecatedTableFields"
                striped
                hover
                small
                responsive
                class="mb-0"
              >
                <template #cell(entity_id)="data">
                  <router-link
                    :to="{ name: 'Entity', params: { entity_id: String(data.value) } }"
                    class="text-decoration-none"
                  >
                    <span class="badge bg-primary">sysndd:{{ data.value }}</span>
                  </router-link>
                </template>
                <template #cell(symbol)="data">
                  <router-link
                    :to="{ name: 'Gene', params: { symbol: String(data.value) } }"
                    class="text-decoration-none fw-bold"
                  >
                    {{ data.value }}
                  </router-link>
                </template>
                <template #cell(disease_ontology_id)="data">
                  <div class="d-flex flex-column">
                    <a
                      :href="`https://omim.org/entry/${String(data.value).replace('OMIM:', '')}`"
                      target="_blank"
                      class="text-danger text-decoration-none"
                    >
                      {{ data.value }}
                      <small class="text-muted">(deprecated)</small>
                    </a>
                    <small
                      v-if="data.item.mondo_id"
                      class="text-muted"
                    >
                      <a
                        :href="`https://monarchinitiative.org/disease/${data.item.mondo_id}`"
                        target="_blank"
                        class="text-decoration-none"
                      >
                        {{ data.item.mondo_id }}
                      </a>
                    </small>
                  </div>
                </template>
                <template #cell(replacement_suggestion)="data">
                  <div
                    v-if="data.item.replacement_omim_id || data.item.replacement_mondo_id"
                    class="d-flex flex-column"
                  >
                    <span
                      v-if="data.item.replacement_omim_id"
                      class="d-flex align-items-center"
                    >
                      <span class="badge bg-success me-1">Suggested</span>
                      <a
                        :href="`https://omim.org/entry/${String(data.item.replacement_omim_id).replace('OMIM:', '')}`"
                        target="_blank"
                        class="text-decoration-none text-success fw-bold"
                      >
                        {{ data.item.replacement_omim_id }}
                      </a>
                    </span>
                    <small
                      v-if="data.item.replacement_mondo_id"
                      class="text-muted"
                    >
                      via
                      <a
                        :href="`https://monarchinitiative.org/disease/${data.item.replacement_mondo_id}`"
                        target="_blank"
                        class="text-decoration-none"
                      >
                        {{ data.item.replacement_mondo_id }}
                      </a>
                      <span v-if="data.item.replacement_mondo_label">
                        ({{ truncateText(String(data.item.replacement_mondo_label), 30) }})
                      </span>
                    </small>
                  </div>
                  <span
                    v-else-if="data.item.mondo_id"
                    class="text-muted small"
                  >
                    No replacement found
                  </span>
                  <span
                    v-else
                    class="text-muted small"
                  >
                    No MONDO mapping
                  </span>
                </template>
                <template #cell(deprecation_reason)="data">
                  <small
                    v-if="data.value"
                    class="text-muted deprecation-reason"
                    :title="String(data.value)"
                  >
                    {{ truncateText(String(data.value), 80) }}
                  </small>
                  <span
                    v-else
                    class="text-muted small"
                  >
                    -
                  </span>
                </template>
                <template #cell(category)="data">
                  <span
                    class="badge"
                    :class="categoryBadgeClass(String(data.value))"
                  >
                    {{ data.value }}
                  </span>
                </template>
              </BTable>
            </div>
          </BCard>
        </BCol>
      </BRow>

      <!-- Job History Section -->
      <BRow class="justify-content-md-center py-2">
        <BCol
          col
          md="10"
        >
          <BCard
            header-tag="header"
            body-class="p-2"
            header-class="p-1"
            border-variant="dark"
            class="mb-3 text-start"
          >
            <template #header>
              <h5 class="mb-0 text-start font-weight-bold d-flex align-items-center">
                Job History
                <BButton
                  size="sm"
                  variant="outline-secondary"
                  class="ms-auto"
                  :disabled="jobHistoryLoading"
                  @click="fetchJobHistory"
                >
                  <BSpinner
                    v-if="jobHistoryLoading"
                    small
                    class="me-1"
                  />
                  Refresh
                </BButton>
              </h5>
            </template>

            <GenericTable
              :items="jobHistory"
              :fields="jobHistoryFields"
              :is-busy="jobHistoryLoading"
              :sort-by="[{ key: 'submitted_at', order: 'desc' }]"
            >
              <template #cell-operation="{ row }">
                <span class="badge bg-info text-dark">
                  {{ formatOperationType(row.operation) }}
                </span>
              </template>

              <template #cell-status="{ row }">
                <span
                  class="badge"
                  :class="getStatusBadgeClass(row.status)"
                >
                  {{ row.status }}
                </span>
              </template>

              <template #cell-submitted_at="{ row }">
                {{ formatDateTime(row.submitted_at) }}
              </template>

              <template #cell-duration_seconds="{ row }">
                {{ formatDuration(row.duration_seconds) }}
              </template>

              <template #cell-error_message="{ row }">
                <span
                  v-if="row.error_message"
                  v-b-tooltip.hover.top
                  class="text-danger error-text"
                  :title="row.error_message"
                >
                  {{ truncateText(row.error_message, 50) }}
                </span>
                <span
                  v-else
                  class="text-muted"
                >
                  —
                </span>
              </template>
            </GenericTable>

            <div
              v-if="!jobHistoryLoading && jobHistory.length === 0"
              class="text-center text-muted py-3"
            >
              No job history available. Jobs appear here after they are submitted.
            </div>
          </BCard>
        </BCol>
      </BRow>
    </BContainer>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue';
import axios from 'axios';
import useToast from '@/composables/useToast';
import { useAsyncJob } from '@/composables/useAsyncJob';
import GenericTable from '@/components/small/GenericTable.vue';

// Types
interface JobHistoryItem {
  job_id: string;
  operation: string;
  status: 'pending' | 'running' | 'completed' | 'failed';
  submitted_at: string;
  completed_at: string | null;
  duration_seconds: number;
  error_message: string | null;
}

// Composables
const { makeToast } = useToast();

// Create job instances for ontology and HGNC updates
const ontologyJob = useAsyncJob(
  (jobId: string) => `${import.meta.env.VITE_API_URL}/api/jobs/${jobId}/status`,
);
const hgncJob = useAsyncJob(
  (jobId: string) => `${import.meta.env.VITE_API_URL}/api/jobs/${jobId}/status`,
);

// Reactive state
const annotationDates = ref({
  omim_update: null as string | null,
  hgnc_update: null as string | null,
  mondo_update: null as string | null,
  disease_ontology_update: null as string | null,
});

const loadingDeprecated = ref(false);
const deprecatedData = ref({
  deprecated_count: null as number | null,
  affected_entity_count: 0,
  affected_entities: [] as Array<Record<string, unknown>>,
  mim2gene_date: null as string | null,
  message: null as string | null,
});

const deprecatedTableFields = [
  { key: 'entity_id', label: 'Entity', sortable: true },
  { key: 'symbol', label: 'Gene', sortable: true },
  { key: 'disease_ontology_id', label: 'Deprecated OMIM', sortable: true },
  { key: 'replacement_suggestion', label: 'Replacement', sortable: false },
  { key: 'deprecation_reason', label: 'Reason', sortable: false },
  { key: 'category', label: 'Category', sortable: true },
];

// Job history state
const jobHistory = ref<JobHistoryItem[]>([]);
const jobHistoryLoading = ref(false);

const jobHistoryFields = [
  { key: 'operation', label: 'Job Type', sortable: true },
  { key: 'status', label: 'Status', sortable: true },
  { key: 'submitted_at', label: 'Started', sortable: true },
  { key: 'duration_seconds', label: 'Duration', sortable: true },
  { key: 'error_message', label: 'Error', sortable: false },
];

// Computed properties for step labels
const ontologyStepLabel = computed(() => {
  if (!ontologyJob.step.value) return 'Initializing...';
  if (ontologyJob.step.value.length > 40) {
    return ontologyJob.step.value.substring(0, 37) + '...';
  }
  return ontologyJob.step.value;
});

const hgncStepLabel = computed(() => {
  if (!hgncJob.step.value) return 'Initializing...';
  if (hgncJob.step.value.length > 40) {
    return hgncJob.step.value.substring(0, 37) + '...';
  }
  return hgncJob.step.value;
});

// Watch for job completion/failure
watch(
  () => ontologyJob.status.value,
  (newStatus) => {
    if (newStatus === 'completed') {
      makeToast('Ontology annotations updated successfully', 'Success', 'success');
      fetchAnnotationDates();
      fetchJobHistory();
    } else if (newStatus === 'failed') {
      const errorMsg = ontologyJob.error.value || 'Ontology update failed';
      makeToast(errorMsg, 'Error', 'danger');
      fetchJobHistory();
    }
  },
);

watch(
  () => hgncJob.status.value,
  (newStatus) => {
    if (newStatus === 'completed') {
      makeToast('HGNC data updated successfully', 'Success', 'success');
      fetchAnnotationDates();
      fetchJobHistory();
    } else if (newStatus === 'failed') {
      const errorMsg = hgncJob.error.value || 'HGNC update failed';
      makeToast(errorMsg, 'Error', 'danger');
      fetchJobHistory();
    }
  },
);

// Methods
async function fetchAnnotationDates() {
  try {
    const response = await axios.get(
      `${import.meta.env.VITE_API_URL}/api/admin/annotation_dates`,
      {
        headers: {
          Authorization: `Bearer ${localStorage.getItem('token')}`,
        },
      },
    );
    const data = response.data;
    annotationDates.value = {
      omim_update: Array.isArray(data.omim_update) ? data.omim_update[0] : data.omim_update,
      hgnc_update: Array.isArray(data.hgnc_update) ? data.hgnc_update[0] : data.hgnc_update,
      mondo_update: Array.isArray(data.mondo_update) ? data.mondo_update[0] : data.mondo_update,
      disease_ontology_update: Array.isArray(data.disease_ontology_update)
        ? data.disease_ontology_update[0]
        : data.disease_ontology_update,
    };
  } catch (error) {
    // Silently fail - dates are optional enhancement
    console.warn('Failed to fetch annotation dates:', error);
  }
}

function formatDate(dateString: string | null): string {
  if (!dateString) return '';
  // Handle both date-only (YYYY-MM-DD) and datetime formats
  const date = new Date(dateString);
  if (isNaN(date.getTime())) return dateString;
  return date.toLocaleDateString();
}

function formatDateTime(dateString: string | null): string {
  if (!dateString) return '';
  const date = new Date(dateString);
  if (isNaN(date.getTime())) return dateString;
  return date.toLocaleString();
}

function formatDuration(seconds: number | null): string {
  if (seconds === null || seconds === undefined) return '—';
  const mins = Math.floor(seconds / 60);
  const secs = seconds % 60;
  if (mins > 0) {
    return `${mins}m ${secs}s`;
  }
  return `${secs}s`;
}

function formatOperationType(operation: string): string {
  const labels: Record<string, string> = {
    clustering: 'Clustering',
    phenotype_clustering: 'Phenotype Clustering',
    ontology_update: 'Ontology Update',
    hgnc_update: 'HGNC Update',
  };
  return labels[operation] || operation;
}

function getStatusBadgeClass(status: string): string {
  const classes: Record<string, string> = {
    completed: 'bg-success',
    failed: 'bg-danger',
    running: 'bg-primary',
    pending: 'bg-info',
  };
  return classes[status] || 'bg-secondary';
}

async function fetchJobHistory() {
  jobHistoryLoading.value = true;
  try {
    const response = await axios.get(
      `${import.meta.env.VITE_API_URL}/api/jobs/history`,
      {
        headers: {
          Authorization: `Bearer ${localStorage.getItem('token')}`,
        },
        params: {
          limit: 20,
        },
      },
    );
    // Handle R/Plumber response structure
    const data = response.data;
    if (data && Array.isArray(data.data)) {
      // Unwrap single-element arrays from R/Plumber
      jobHistory.value = data.data.map((job: Record<string, unknown>) => ({
        job_id: unwrapValue(job.job_id),
        operation: unwrapValue(job.operation),
        status: unwrapValue(job.status),
        submitted_at: unwrapValue(job.submitted_at),
        completed_at: unwrapValue(job.completed_at),
        duration_seconds: unwrapValue(job.duration_seconds),
        error_message: unwrapValue(job.error_message),
      })) as JobHistoryItem[];
    } else {
      jobHistory.value = [];
    }
  } catch (error) {
    console.warn('Failed to fetch job history:', error);
    // Don't show toast - job history is optional enhancement
    jobHistory.value = [];
  } finally {
    jobHistoryLoading.value = false;
  }
}

function categoryBadgeClass(category: string): string {
  const classes: Record<string, string> = {
    Definitive: 'bg-success',
    Moderate: 'bg-info',
    Limited: 'bg-warning text-dark',
    Refuted: 'bg-danger',
  };
  return classes[category] || 'bg-secondary';
}

function truncateText(text: string | null, maxLength: number): string {
  if (!text || text.length <= maxLength) return text || '';
  return `${text.substring(0, maxLength)}...`;
}

// Helper to unwrap R/Plumber array values (scalars come as single-element arrays)
function unwrapValue<T>(val: T | T[]): T {
  return Array.isArray(val) && val.length === 1 ? val[0] : (val as T);
}

async function fetchDeprecatedEntities() {
  loadingDeprecated.value = true;
  try {
    const response = await axios.get(
      `${import.meta.env.VITE_API_URL}/api/admin/deprecated_entities`,
      {
        headers: {
          Authorization: `Bearer ${localStorage.getItem('token')}`,
        },
      },
    );
    const data = response.data;
    // Unwrap entity fields (R/Plumber returns scalars as single-element arrays)
    const unwrappedEntities = (data.affected_entities || []).map(
      (entity: Record<string, unknown>) => {
        const unwrapped: Record<string, unknown> = {};
        Object.keys(entity).forEach((key) => {
          unwrapped[key] = unwrapValue(entity[key]);
        });
        return unwrapped;
      },
    );
    deprecatedData.value = {
      deprecated_count: unwrapValue(data.deprecated_count),
      affected_entity_count: unwrapValue(data.affected_entity_count) || 0,
      affected_entities: unwrappedEntities,
      mim2gene_date: unwrapValue(data.mim2gene_date),
      message: unwrapValue(data.message),
    };
    if (deprecatedData.value.affected_entity_count > 0) {
      makeToast(
        `Found ${deprecatedData.value.affected_entity_count} entities using deprecated OMIM IDs`,
        'Review Needed',
        'warning',
      );
    } else {
      makeToast('No entities affected by deprecated OMIM IDs', 'Check Complete', 'success');
    }
  } catch (error) {
    makeToast('Failed to check deprecated entities', 'Error', 'danger');
    console.error('Failed to fetch deprecated entities:', error);
  } finally {
    loadingDeprecated.value = false;
  }
}

async function updateOntologyAnnotations() {
  // Reset and prepare job
  ontologyJob.reset();

  try {
    // Call async endpoint
    const response = await axios.put(
      `${import.meta.env.VITE_API_URL}/api/admin/update_ontology_async`,
      {},
      {
        headers: {
          Authorization: `Bearer ${localStorage.getItem('token')}`,
        },
      },
    );

    if (response.data.error) {
      makeToast(response.data.message || 'Failed to start update', 'Error', 'danger');
      return;
    }

    // Start tracking the job
    ontologyJob.startJob(response.data.job_id);
  } catch (error) {
    makeToast('Failed to start ontology update', 'Error', 'danger');
  }
}

async function updateHgncData() {
  // Reset and prepare job
  hgncJob.reset();

  try {
    // Call async endpoint
    const response = await axios.post(
      `${import.meta.env.VITE_API_URL}/api/jobs/hgnc_update/submit`,
      {},
      {
        headers: {
          Authorization: `Bearer ${localStorage.getItem('token')}`,
        },
      },
    );

    if (response.data.error) {
      makeToast(response.data.message || 'Failed to start HGNC update', 'Error', 'danger');
      return;
    }

    // Start tracking the job
    hgncJob.startJob(response.data.job_id);
  } catch (error) {
    makeToast('Failed to start HGNC update', 'Error', 'danger');
  }
}

// Lifecycle
onMounted(() => {
  fetchAnnotationDates();
  fetchJobHistory();
});
</script>

<style scoped>
  .btn-group-xs > .btn, .btn-xs {
    padding: .25rem .4rem;
    font-size: .875rem;
    line-height: .5;
    border-radius: .2rem;
  }

  .deprecation-reason {
    display: block;
    max-width: 250px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    cursor: help;
  }

  .error-text {
    display: block;
    max-width: 200px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    cursor: help;
  }
</style>
