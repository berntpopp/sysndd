<!-- views/admin/ManageAnnotations.vue -->
<template>
  <div class="container-fluid">
    <BContainer fluid>
      <!-- Updating Ontology Annotations Section -->
      <BRow class="justify-content-md-center py-2">
        <BCol col md="12">
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
                <span v-if="annotationDates.omim_update" class="badge bg-secondary ms-2 fw-normal">
                  Last: {{ formatDate(annotationDates.omim_update) }}
                </span>
              </h5>
            </template>

            <BButton
              variant="primary"
              :disabled="ontologyJob.isLoading.value"
              @click="updateOntologyAnnotations"
            >
              <BSpinner v-if="ontologyJob.isLoading.value" small type="grow" class="me-2" />
              {{ ontologyJob.isLoading.value ? 'Updating...' : 'Update Ontology Annotations' }}
            </BButton>

            <!-- Progress display -->
            <div
              v-if="ontologyJob.isLoading.value || ontologyJob.status.value !== 'idle'"
              class="mt-3"
            >
              <div class="d-flex align-items-center mb-2">
                <span class="badge me-2" :class="ontologyJob.statusBadgeClass.value">
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
                :variant="ontologyJob.progressVariant.value"
                height="1.5rem"
              >
                <template #default>
                  <span v-if="ontologyJob.hasRealProgress.value"
                    >{{ ontologyJob.progressPercent.value }}% - {{ ontologyStepLabel }}</span
                  >
                  <span v-else
                    >{{ ontologyStepLabel }} ({{ ontologyJob.elapsedTimeDisplay.value }})</span
                  >
                </template>
              </BProgress>

              <div
                v-if="ontologyJob.progress.value.current && ontologyJob.progress.value.total"
                class="small text-muted mt-1"
              >
                {{ ontologyJob.progress.value.current.toLocaleString() }} /
                {{ ontologyJob.progress.value.total.toLocaleString() }} ({{
                  ontologyJob.elapsedTimeDisplay.value
                }})
              </div>
              <div v-else-if="ontologyJob.isLoading.value" class="small text-muted mt-1">
                Elapsed: {{ ontologyJob.elapsedTimeDisplay.value }} - This may take several
                minutes...
              </div>
            </div>
          </BCard>
        </BCol>
      </BRow>

      <!-- Updating HGNC Data Section -->
      <BRow class="justify-content-md-center py-2">
        <BCol col md="12">
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
                <span v-if="annotationDates.hgnc_update" class="badge bg-secondary ms-2 fw-normal">
                  Last: {{ formatDate(annotationDates.hgnc_update) }}
                </span>
              </h5>
            </template>

            <BButton variant="primary" :disabled="hgncJob.isLoading.value" @click="updateHgncData">
              <BSpinner v-if="hgncJob.isLoading.value" small type="grow" class="me-2" />
              {{ hgncJob.isLoading.value ? 'Updating...' : 'Update HGNC Data' }}
            </BButton>

            <!-- HGNC Progress display -->
            <div v-if="hgncJob.isLoading.value || hgncJob.status.value !== 'idle'" class="mt-3">
              <div class="d-flex align-items-center mb-2">
                <span class="badge me-2" :class="hgncJob.statusBadgeClass.value">
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
                :variant="hgncJob.progressVariant.value"
                height="1.5rem"
              >
                <template #default>
                  <span v-if="hgncJob.hasRealProgress.value"
                    >{{ hgncJob.progressPercent.value }}% - {{ hgncStepLabel }}</span
                  >
                  <span v-else>{{ hgncStepLabel }} ({{ hgncJob.elapsedTimeDisplay.value }})</span>
                </template>
              </BProgress>

              <div
                v-if="hgncJob.progress.value.current && hgncJob.progress.value.total"
                class="small text-muted mt-1"
              >
                {{ hgncJob.progress.value.current.toLocaleString() }} /
                {{ hgncJob.progress.value.total.toLocaleString() }} ({{
                  hgncJob.elapsedTimeDisplay.value
                }})
              </div>
              <div v-else-if="hgncJob.isLoading.value" class="small text-muted mt-1">
                Elapsed: {{ hgncJob.elapsedTimeDisplay.value }} - Downloading HGNC data and
                enriching with gnomAD constraints (this may take hours on first run)...
              </div>
            </div>
          </BCard>
        </BCol>
      </BRow>

      <!-- Pubtator Cache Management Section -->
      <BRow class="justify-content-md-center py-2">
        <BCol col md="12">
          <BCard
            header-tag="header"
            body-class="p-1"
            header-class="p-1"
            border-variant="dark"
            class="mb-3 text-start"
          >
            <template #header>
              <h5 class="mb-0 text-start font-weight-bold">
                Pubtator Cache Management
                <span
                  v-if="pubtatorStats.publication_count !== null"
                  class="badge bg-info ms-2 fw-normal"
                >
                  {{ pubtatorStats.publication_count?.toLocaleString() }} publications
                </span>
                <span
                  v-if="pubtatorStats.gene_count !== null"
                  class="badge bg-info ms-2 fw-normal"
                >
                  {{ pubtatorStats.gene_count?.toLocaleString() }} genes
                </span>
                <span
                  v-if="pubtatorStats.novel_count !== null && pubtatorStats.novel_count > 0"
                  class="badge bg-warning text-dark ms-2 fw-normal"
                >
                  {{ pubtatorStats.novel_count?.toLocaleString() }} novel
                </span>
              </h5>
            </template>

            <div class="mb-2">
              <BButton
                variant="outline-secondary"
                size="sm"
                :disabled="loadingPubtatorStats"
                @click="fetchPubtatorStats"
              >
                <BSpinner v-if="loadingPubtatorStats" small type="grow" class="me-1" />
                <i v-else class="bi bi-arrow-clockwise me-1" />
                {{ loadingPubtatorStats ? 'Loading...' : 'Refresh Stats' }}
              </BButton>
              <small class="text-muted ms-2">
                Shows cached Pubtator gene-publication data for NDD literature
              </small>
            </div>

            <div v-if="pubtatorStats.gene_count !== null" class="mt-2">
              <p class="text-muted small mb-2">
                The Pubtator cache contains gene-publication associations from NCBI's PubTator
                text-mining service. Novel genes are those mentioned in NDD literature but not yet
                in SysNDD.
              </p>
              <div class="d-flex flex-wrap gap-2">
                <router-link
                  :to="{ name: 'PubtatorNDD' }"
                  class="btn btn-sm btn-outline-primary"
                >
                  <i class="bi bi-bar-chart me-1" />
                  View Pubtator Analysis
                </router-link>
              </div>
            </div>

            <BAlert
              v-if="pubtatorStats.gene_count === 0"
              variant="warning"
              show
              class="mt-2 mb-0"
            >
              No Pubtator data cached. The cache will be populated when the Pubtator search is
              first run.
            </BAlert>
          </BCard>
        </BCol>
      </BRow>

      <!-- Deprecated OMIM Entities Section -->
      <BRow class="justify-content-md-center py-2">
        <BCol col md="12">
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
                <span v-if="deprecatedData.mim2gene_date" class="badge bg-secondary ms-2 fw-normal">
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
                <BSpinner v-if="loadingDeprecated" small type="grow" class="me-1" />
                {{ loadingDeprecated ? 'Checking...' : 'Check for Deprecated Entities' }}
              </BButton>
              <small class="text-muted ms-2">
                Compares database entities against OMIM moved/removed entries
              </small>
            </div>

            <div v-if="deprecatedData.message && !deprecatedData.affected_entities?.length">
              <BAlert variant="info" show>
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
                    <small v-if="data.item.mondo_id" class="text-muted">
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
                    <span v-if="data.item.replacement_omim_id" class="d-flex align-items-center">
                      <span class="badge bg-success me-1">Suggested</span>
                      <a
                        :href="`https://omim.org/entry/${String(data.item.replacement_omim_id).replace('OMIM:', '')}`"
                        target="_blank"
                        class="text-decoration-none text-success fw-bold"
                      >
                        {{ data.item.replacement_omim_id }}
                      </a>
                    </span>
                    <small v-if="data.item.replacement_mondo_id" class="text-muted">
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
                  <span v-else-if="data.item.mondo_id" class="text-muted small">
                    No replacement found
                  </span>
                  <span v-else class="text-muted small"> No MONDO mapping </span>
                </template>
                <template #cell(deprecation_reason)="data">
                  <small
                    v-if="data.value"
                    class="text-muted deprecation-reason"
                    :title="String(data.value)"
                  >
                    {{ truncateText(String(data.value), 80) }}
                  </small>
                  <span v-else class="text-muted small"> - </span>
                </template>
                <template #cell(category)="data">
                  <span class="badge" :class="categoryBadgeClass(String(data.value))">
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
        <BCol col md="12">
          <BCard
            header-tag="header"
            body-class="p-0"
            header-class="p-2"
            border-variant="dark"
            class="mb-3 text-start"
          >
            <template #header>
              <div class="d-flex justify-content-between align-items-center flex-wrap gap-2">
                <h5 class="mb-0 font-weight-bold">
                  Job History
                  <span class="badge bg-secondary ms-2 fw-normal">
                    {{ filteredJobHistory.length }} jobs
                  </span>
                </h5>
                <div class="d-flex align-items-center gap-2">
                  <BButton
                    size="sm"
                    variant="outline-secondary"
                    :disabled="jobHistoryLoading"
                    @click="fetchJobHistory"
                  >
                    <BSpinner v-if="jobHistoryLoading" small class="me-1" />
                    <i v-else class="bi bi-arrow-clockwise me-1" />
                    Refresh
                  </BButton>
                </div>
              </div>
            </template>

            <!-- Table controls row -->
            <div class="p-2 border-bottom bg-light">
              <div class="d-flex justify-content-between align-items-center flex-wrap gap-2">
                <div class="d-flex align-items-center gap-2">
                  <TableSearchInput
                    v-model="searchFilter"
                    placeholder="Search jobs..."
                    @update="handleSearchChange"
                  />
                  <span v-if="searchFilter" class="badge bg-primary d-flex align-items-center">
                    Search: {{ searchFilter }}
                    <button
                      type="button"
                      class="btn-close btn-close-white ms-2"
                      style="font-size: 0.6rem"
                      aria-label="Clear search"
                      @click="clearSearch"
                    />
                  </span>
                </div>
                <div class="d-flex align-items-center gap-2">
                  <TableDownloadLinkCopyButtons
                    @request-excel="downloadJobHistory"
                    @copy-link="copyPageLink"
                    @remove-filters="clearAllFilters"
                  />
                  <TablePaginationControls
                    :current-page="currentPage"
                    :total-rows="filteredJobHistory.length"
                    :initial-per-page="pageSize"
                    :page-options="pageSizeOptions"
                    @page-change="handlePageChange"
                    @per-page-change="handlePageSizeChange"
                  />
                </div>
              </div>
            </div>

            <GenericTable
              :items="paginatedJobHistory"
              :fields="jobHistoryFields"
              :is-busy="jobHistoryLoading"
              :sort-by="sortBy"
              @update-sort="handleSortUpdate"
            >
              <template #cell-operation="{ row }">
                <span class="badge bg-info text-dark">
                  {{ formatOperationType(row.operation) }}
                </span>
              </template>

              <template #cell-status="{ row }">
                <span class="badge" :class="getStatusBadgeClass(row.status)">
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
                <span v-else class="text-muted"> — </span>
              </template>
            </GenericTable>

            <div
              v-if="!jobHistoryLoading && filteredJobHistory.length === 0"
              class="text-center text-muted py-4"
            >
              <i class="bi bi-inbox fs-1 d-block mb-2" />
              <span v-if="searchFilter">No jobs match your search criteria.</span>
              <span v-else
                >No job history available. Jobs appear here after they are submitted.</span
              >
            </div>

            <!-- Bottom pagination for longer lists -->
            <div v-if="filteredJobHistory.length > pageSize" class="p-2 border-top bg-light">
              <div class="d-flex justify-content-end">
                <TablePaginationControls
                  :current-page="currentPage"
                  :total-rows="filteredJobHistory.length"
                  :initial-per-page="pageSize"
                  :page-options="pageSizeOptions"
                  @page-change="handlePageChange"
                  @per-page-change="handlePageSizeChange"
                />
              </div>
            </div>
          </BCard>
        </BCol>
      </BRow>
    </BContainer>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue';
import { useRoute } from 'vue-router';
import axios from 'axios';
import useToast from '@/composables/useToast';
import { useAsyncJob } from '@/composables/useAsyncJob';
import GenericTable from '@/components/small/GenericTable.vue';
import TablePaginationControls from '@/components/small/TablePaginationControls.vue';
import TableSearchInput from '@/components/small/TableSearchInput.vue';
import TableDownloadLinkCopyButtons from '@/components/small/TableDownloadLinkCopyButtons.vue';

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
const route = useRoute();
const { makeToast } = useToast();

// URL state parameters
const currentPage = ref(1);
const pageSize = ref(10);
const sortField = ref('submitted_at');
const sortOrder = ref<'asc' | 'desc'>('desc');
const searchFilter = ref('');

// Page size options for dropdown
const pageSizeOptions = [10, 25, 50, 100];

// Create job instances for ontology and HGNC updates
const ontologyJob = useAsyncJob(
  (jobId: string) => `${import.meta.env.VITE_API_URL}/api/jobs/${jobId}/status`
);
const hgncJob = useAsyncJob(
  (jobId: string) => `${import.meta.env.VITE_API_URL}/api/jobs/${jobId}/status`
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

// Pubtator stats state
const pubtatorStats = ref({
  publication_count: null as number | null,
  gene_count: null as number | null,
  novel_count: null as number | null,
});
const loadingPubtatorStats = ref(false);

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

// Computed: sort string for GenericTable
const sortBy = computed(() => [
  {
    key: sortField.value,
    order: sortOrder.value,
  },
]);

// Computed: filtered job history based on search
const filteredJobHistory = computed(() => {
  if (!searchFilter.value.trim()) {
    return jobHistory.value;
  }
  const search = searchFilter.value.toLowerCase();
  return jobHistory.value.filter(
    (job) =>
      job.operation.toLowerCase().includes(search) ||
      job.status.toLowerCase().includes(search) ||
      (job.error_message && job.error_message.toLowerCase().includes(search))
  );
});

// Computed: paginated job history
const paginatedJobHistory = computed(() => {
  const filtered = filteredJobHistory.value;
  const start = (currentPage.value - 1) * pageSize.value;
  const end = start + pageSize.value;
  return filtered.slice(start, end);
});

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
  }
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
  }
);

// URL state synchronization
function initFromUrl() {
  const query = route.query;
  if (query.page) {
    currentPage.value = parseInt(String(query.page), 10) || 1;
  }
  if (query.page_size) {
    const ps = parseInt(String(query.page_size), 10);
    if (pageSizeOptions.includes(ps)) {
      pageSize.value = ps;
    }
  }
  if (query.sort) {
    const sortStr = String(query.sort);
    if (sortStr.startsWith('-')) {
      sortField.value = sortStr.slice(1);
      sortOrder.value = 'desc';
    } else if (sortStr.startsWith('+')) {
      sortField.value = sortStr.slice(1);
      sortOrder.value = 'asc';
    } else {
      sortField.value = sortStr;
      sortOrder.value = 'asc';
    }
  }
  if (query.search) {
    searchFilter.value = String(query.search);
  }
}

function updateUrl() {
  const query: Record<string, string> = {};
  if (currentPage.value !== 1) {
    query.page = String(currentPage.value);
  }
  if (pageSize.value !== 10) {
    query.page_size = String(pageSize.value);
  }
  const sortPrefix = sortOrder.value === 'desc' ? '-' : '+';
  if (sortField.value !== 'submitted_at' || sortOrder.value !== 'desc') {
    query.sort = `${sortPrefix}${sortField.value}`;
  }
  if (searchFilter.value.trim()) {
    query.search = searchFilter.value.trim();
  }
  // Use replaceState to avoid adding history entries
  const url = new URL(window.location.href);
  url.search = new URLSearchParams(query).toString();
  window.history.replaceState({}, '', url.toString());
}

function handlePageChange(page: number) {
  currentPage.value = page;
  updateUrl();
}

function handlePageSizeChange(size: number) {
  pageSize.value = size;
  currentPage.value = 1; // Reset to first page
  updateUrl();
}

function handleSortUpdate(event: { sortBy: string; sortDesc: boolean }) {
  sortField.value = event.sortBy;
  sortOrder.value = event.sortDesc ? 'desc' : 'asc';
  updateUrl();
}

function handleSearchChange(value: string) {
  searchFilter.value = value;
  currentPage.value = 1; // Reset to first page on search
  updateUrl();
}

function clearSearch() {
  searchFilter.value = '';
  currentPage.value = 1;
  updateUrl();
}

function clearAllFilters() {
  searchFilter.value = '';
  sortField.value = 'submitted_at';
  sortOrder.value = 'desc';
  currentPage.value = 1;
  pageSize.value = 10;
  updateUrl();
  makeToast('All filters cleared', 'Filters Reset', 'info');
}

async function downloadJobHistory() {
  try {
    const response = await axios.get(`${import.meta.env.VITE_API_URL}/api/jobs/history`, {
      headers: {
        Authorization: `Bearer ${localStorage.getItem('token')}`,
      },
      params: {
        limit: 1000,
      },
    });
    const data = response.data?.data || [];
    if (data.length === 0) {
      makeToast('No job history to download', 'Info', 'info');
      return;
    }
    // Convert to CSV
    const headers = ['Job ID', 'Operation', 'Status', 'Started', 'Duration (s)', 'Error'];
    const rows = data.map((job: Record<string, unknown>) => [
      unwrapValue(job.job_id),
      unwrapValue(job.operation),
      unwrapValue(job.status),
      unwrapValue(job.submitted_at),
      unwrapValue(job.duration_seconds) ?? '',
      unwrapValue(job.error_message) ?? '',
    ]);
    const csvContent = [
      headers.join(','),
      ...rows.map((row: (string | number)[]) =>
        row.map((v) => `"${String(v).replace(/"/g, '""')}"`).join(',')
      ),
    ].join('\n');
    // Download
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `job_history_${new Date().toISOString().split('T')[0]}.csv`;
    link.click();
    URL.revokeObjectURL(url);
    makeToast('Job history downloaded', 'Download Complete', 'success');
  } catch (error) {
    makeToast('Failed to download job history', 'Error', 'danger');
    console.error('Download error:', error);
  }
}

function copyPageLink() {
  navigator.clipboard
    .writeText(window.location.href)
    .then(() => {
      makeToast('Page link copied to clipboard', 'Copied', 'success');
    })
    .catch(() => {
      makeToast('Failed to copy link', 'Error', 'danger');
    });
}

// Methods
async function fetchAnnotationDates() {
  try {
    const response = await axios.get(`${import.meta.env.VITE_API_URL}/api/admin/annotation_dates`, {
      headers: {
        Authorization: `Bearer ${localStorage.getItem('token')}`,
      },
    });
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
    pubtator_update: 'Pubtator Update',
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
    const response = await axios.get(`${import.meta.env.VITE_API_URL}/api/jobs/history`, {
      headers: {
        Authorization: `Bearer ${localStorage.getItem('token')}`,
      },
      params: {
        limit: 20,
      },
    });
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
      }
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
      }
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
        'warning'
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
      }
    );

    if (response.data.error) {
      makeToast(response.data.message || 'Failed to start update', 'Error', 'danger');
      return;
    }

    // Start tracking the job
    ontologyJob.startJob(response.data.job_id);
  } catch (_error) {
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
      }
    );

    if (response.data.error) {
      makeToast(response.data.message || 'Failed to start HGNC update', 'Error', 'danger');
      return;
    }

    // Start tracking the job
    hgncJob.startJob(response.data.job_id);
  } catch (_error) {
    makeToast('Failed to start HGNC update', 'Error', 'danger');
  }
}

async function fetchPubtatorStats() {
  loadingPubtatorStats.value = true;
  try {
    // Fetch gene count and novel count from pubtator/genes endpoint
    const genesResponse = await axios.get(
      `${import.meta.env.VITE_API_URL}/api/publication/pubtator/genes`,
      {
        params: {
          page_size: 1,
          fields: 'gene_symbol',
        },
      }
    );

    // Get total gene count from meta
    const geneCount = genesResponse.data?.meta?.totalItems ?? null;

    // Fetch publication count from pubtator/table endpoint
    const pubsResponse = await axios.get(
      `${import.meta.env.VITE_API_URL}/api/publication/pubtator/table`,
      {
        params: {
          page_size: 1,
          fields: 'search_id',
        },
      }
    );

    // Get total publication count from meta
    const pubCount = pubsResponse.data?.meta?.totalItems ?? null;

    // Fetch novel gene count (is_novel=1)
    const novelResponse = await axios.get(
      `${import.meta.env.VITE_API_URL}/api/publication/pubtator/genes`,
      {
        params: {
          page_size: 1,
          filter: "is_novel==1",
          fields: 'gene_symbol',
        },
      }
    );

    const novelCount = novelResponse.data?.meta?.totalItems ?? null;

    pubtatorStats.value = {
      publication_count: pubCount,
      gene_count: geneCount,
      novel_count: novelCount,
    };
  } catch (error) {
    console.warn('Failed to fetch Pubtator stats:', error);
    // Don't show toast - stats are optional enhancement
    pubtatorStats.value = {
      publication_count: null,
      gene_count: null,
      novel_count: null,
    };
  } finally {
    loadingPubtatorStats.value = false;
  }
}

// Lifecycle
onMounted(() => {
  initFromUrl();
  fetchAnnotationDates();
  fetchJobHistory();
  fetchPubtatorStats();
});
</script>

<style scoped>
.btn-group-xs > .btn,
.btn-xs {
  padding: 0.25rem 0.4rem;
  font-size: 0.875rem;
  line-height: 0.5;
  border-radius: 0.2rem;
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
