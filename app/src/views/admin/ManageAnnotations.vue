<!-- views/admin/ManageAnnotations.vue -->
<template>
  <div class="container-fluid">
    <BContainer fluid>
      <BRow class="justify-content-md-center py-2">
        <BCol col md="12">
          <h3>Manage Annotations</h3>

          <OntologyAnnotationsCard
            :ontology-job="ontologyJob"
            :force-apply-job="forceApplyJob"
            :blocked="ontologyBlocked"
            :last-updated="annotationDates.omim_update"
            :user-options="forceApplyUserOptions"
            :loading-users="loadingForceApplyUsers"
            @start-ontology="onStartOntology"
            @force-apply="onForceApply"
            @dismiss-blocked="dismissBlockedOntology"
          />
        </BCol>
      </BRow>

      <BRow class="justify-content-md-center py-2">
        <BCol col md="12">
          <HgncAnnotationsCard
            :hgnc-job="hgncJob"
            :last-updated="annotationDates.hgnc_update"
            @start-hgnc="onStartHgnc"
          />
        </BCol>
      </BRow>

      <BRow class="justify-content-md-center py-2">
        <BCol col md="12">
          <PubtatorStatsCard
            :stats="pubtatorStats"
            :loading="loadingPubtatorStats"
            @refresh="loadPubtatorStats"
          />
        </BCol>
      </BRow>

      <BRow class="justify-content-md-center py-2">
        <BCol col md="12">
          <ComparisonsRefreshCard
            :job="comparisonsJob"
            :metadata="comparisonsMetadata"
            :loading-metadata="loadingComparisonsMetadata"
            @refresh-metadata="loadComparisonsMetadata"
            @start-refresh="onStartComparisons"
          />
        </BCol>
      </BRow>

      <BRow class="justify-content-md-center py-2">
        <BCol col md="12">
          <PublicationRefreshCard
            :job="publicationRefreshJob"
            :stats="publicationStats"
            :loading-stats="loadingPublicationStats"
            :preset="selectedPreset"
            :custom-date="customDate"
            :today-date="todayDate"
            :filtered-count="filteredCount"
            :loading-filtered-count="loadingFilteredCount"
            @update:preset="setPreset"
            @update:custom-date="(value: string) => (customDate = value)"
            @refresh-stats="loadPublicationStats"
            @refresh-filtered="onRefreshFilteredPublications"
            @refresh-all="onRefreshAllPublications"
          />
        </BCol>
      </BRow>

      <BRow class="justify-content-md-center py-2">
        <BCol col md="12">
          <DeprecatedEntitiesCard
            :data="deprecatedData"
            :loading="loadingDeprecated"
            @check="onCheckDeprecated"
          />
        </BCol>
      </BRow>

      <BRow class="justify-content-md-center py-2">
        <BCol col md="12">
          <JobHistoryCard
            :filtered-job-history="filteredJobHistory"
            :paginated-job-history="paginatedJobHistory"
            :loading="jobHistoryLoading"
            :current-page="currentPage"
            :page-size="pageSize"
            :page-size-options="pageSizeOptions"
            :sort-by="sortBy"
            :search-filter="searchFilter"
            :job-history-fields="jobHistoryFields"
            @refresh="loadJobHistory"
            @download="downloadJobHistory"
            @copy-link="copyPageLink"
            @clear-filters="clearAllFilters"
            @clear-search="clearSearch"
            @update:search-filter="handleSearchChange"
            @page-change="handlePageChange"
            @per-page-change="handlePageSizeChange"
            @update-sort="handleSortUpdate"
          />
        </BCol>
      </BRow>
    </BContainer>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, watch } from 'vue';
import { useRoute } from 'vue-router';
import useToast from '@/composables/useToast';
import { useAsyncJob } from '@/composables/useAsyncJob';
import { unwrapValue } from '@/composables/annotations/useAnnotationFormatters';
import * as api from '@/composables/annotations/useAnnotationsApi';
import { useJobHistoryUrlState } from '@/composables/annotations/useJobHistoryUrlState';
import OntologyAnnotationsCard, {
  type OntologyBlockedState,
  type UserOption,
} from '@/components/annotations/OntologyAnnotationsCard.vue';
import HgncAnnotationsCard from '@/components/annotations/HgncAnnotationsCard.vue';
import PubtatorStatsCard, {
  type PubtatorStats,
} from '@/components/annotations/PubtatorStatsCard.vue';
import ComparisonsRefreshCard, {
  type ComparisonsMetadata,
} from '@/components/annotations/ComparisonsRefreshCard.vue';
import PublicationRefreshCard, {
  type FilterPreset,
  type PublicationStats,
} from '@/components/annotations/PublicationRefreshCard.vue';
import DeprecatedEntitiesCard, {
  type DeprecatedData,
} from '@/components/annotations/DeprecatedEntitiesCard.vue';
import JobHistoryCard, {
  type JobHistoryItem,
} from '@/components/annotations/JobHistoryCard.vue';

// ---------------------------------------------------------------------------
// Composables
// ---------------------------------------------------------------------------
const route = useRoute();
const { makeToast } = useToast();

const jobStatusUrl = (jobId: string): string =>
  `${import.meta.env.VITE_API_URL}/api/jobs/${jobId}/status`;

const ontologyJob = useAsyncJob(jobStatusUrl);
const forceApplyJob = useAsyncJob(jobStatusUrl);
const hgncJob = useAsyncJob(jobStatusUrl);
const comparisonsJob = useAsyncJob(jobStatusUrl);
const publicationRefreshJob = useAsyncJob(jobStatusUrl);

// ---------------------------------------------------------------------------
// Page-level state
// ---------------------------------------------------------------------------
const annotationDates = ref<api.AnnotationDates>({
  omim_update: null,
  hgnc_update: null,
  mondo_update: null,
  disease_ontology_update: null,
});

const ontologyBlocked = ref<OntologyBlockedState | null>(null);
const forceApplyUserOptions = ref<UserOption[]>([]);
const loadingForceApplyUsers = ref(false);

const loadingDeprecated = ref(false);
const deprecatedData = ref<DeprecatedData>({
  deprecated_count: null,
  affected_entity_count: 0,
  affected_entities: [],
  mim2gene_date: null,
  message: null,
});

const pubtatorStats = ref<PubtatorStats>({
  publication_count: null,
  gene_count: null,
  novel_count: null,
});
const loadingPubtatorStats = ref(false);

const publicationStats = ref<PublicationStats>({
  total: null,
  oldest_update: null,
  outdated_count: null,
});
const loadingPublicationStats = ref(false);

const comparisonsMetadata = ref<ComparisonsMetadata>({
  last_full_refresh: null,
  last_refresh_status: 'never',
  last_refresh_error: null,
  sources_count: 0,
  rows_imported: 0,
});
const loadingComparisonsMetadata = ref(false);

const selectedPreset = ref<FilterPreset>('all');
const customDate = ref<string>('');
const filteredCount = ref<number | null>(null);
const loadingFilteredCount = ref(false);

const todayDate = computed(() => new Date().toISOString().split('T')[0]);

const notUpdatedSince = computed<string | null>(() => {
  const now = new Date();
  switch (selectedPreset.value) {
    case '1year':
      now.setFullYear(now.getFullYear() - 1);
      return now.toISOString().split('T')[0];
    case '6months':
      now.setMonth(now.getMonth() - 6);
      return now.toISOString().split('T')[0];
    case '3months':
      now.setMonth(now.getMonth() - 3);
      return now.toISOString().split('T')[0];
    case 'custom':
      return customDate.value || null;
    case 'all':
    default:
      return null;
  }
});

// Job history / table-controls state (URL sync extracted to composable)
const {
  currentPage,
  pageSize,
  searchFilter,
  pageSizeOptions,
  sortBy,
  initFromUrl,
  handlePageChange,
  handlePageSizeChange,
  handleSortUpdate,
  handleSearchChange,
  clearSearch,
  clearAllFilters: resetTableState,
} = useJobHistoryUrlState(route);

const jobHistory = ref<JobHistoryItem[]>([]);
const jobHistoryLoading = ref(false);

const jobHistoryFields = [
  { key: 'operation', label: 'Job Type', sortable: true },
  { key: 'status', label: 'Status', sortable: true },
  { key: 'submitted_at', label: 'Started', sortable: true },
  { key: 'duration_seconds', label: 'Duration', sortable: true },
  { key: 'error_message', label: 'Error', sortable: false },
];

function clearAllFilters(): void {
  resetTableState();
  makeToast('All filters cleared', 'Filters Reset', 'info');
}

const filteredJobHistory = computed<JobHistoryItem[]>(() => {
  if (!searchFilter.value.trim()) return jobHistory.value;
  const search = searchFilter.value.toLowerCase();
  return jobHistory.value.filter(
    (job) =>
      job.operation.toLowerCase().includes(search) ||
      job.status.toLowerCase().includes(search) ||
      (job.error_message && job.error_message.toLowerCase().includes(search))
  );
});

const paginatedJobHistory = computed<JobHistoryItem[]>(() => {
  const start = (currentPage.value - 1) * pageSize.value;
  return filteredJobHistory.value.slice(start, start + pageSize.value);
});

// ---------------------------------------------------------------------------
// Toast-and-history wiring for each job watcher
// ---------------------------------------------------------------------------
function toastDone(msg: string): void {
  makeToast(msg, 'Success', 'success');
}
function toastFail(msg: string): void {
  makeToast(msg, 'Error', 'danger');
}

watch(
  () => ontologyJob.status.value,
  async (newStatus) => {
    if (newStatus === 'completed') {
      try {
        const jobId = ontologyJob.jobId.value;
        if (jobId) {
          const result = await api.fetchOntologyJobResult(jobId);
          if (result && result.kind === 'blocked') {
            ontologyBlocked.value = result.state;
            forceApplyUserOptions.value = [];
            loadingForceApplyUsers.value = true;
            try {
              forceApplyUserOptions.value = await api.fetchForceApplyUsers();
            } catch {
              forceApplyUserOptions.value = [];
            } finally {
              loadingForceApplyUsers.value = false;
            }
            makeToast(
              `Ontology update blocked: ${result.state.critical_count} critical changes`,
              'Update Blocked',
              'warning'
            );
            loadJobHistory();
            return;
          }
          const autoFixes = result && result.kind === 'ok' ? result.autoFixesApplied : 0;
          if (autoFixes > 0) {
            toastDone(`Ontology updated. ${autoFixes} entity version(s) auto-fixed.`);
          } else {
            toastDone('Ontology annotations updated successfully');
          }
        }
      } catch {
        toastDone('Ontology annotations updated successfully');
      }
      loadAnnotationDates();
      loadJobHistory();
    } else if (newStatus === 'failed') {
      toastFail(ontologyJob.error.value || 'Ontology update failed');
      loadJobHistory();
    }
  }
);

watch(
  () => forceApplyJob.status.value,
  (newStatus) => {
    if (newStatus === 'completed') {
      toastDone(
        'Ontology force-applied successfully. Re-review batch created for critical entities.'
      );
      ontologyBlocked.value = null;
      loadAnnotationDates();
      loadJobHistory();
    } else if (newStatus === 'failed') {
      toastFail(forceApplyJob.error.value || 'Force-apply failed');
      loadJobHistory();
    }
  }
);

watch(
  () => hgncJob.status.value,
  (newStatus) => {
    if (newStatus === 'completed') {
      toastDone('HGNC data updated successfully');
      loadAnnotationDates();
      loadJobHistory();
    } else if (newStatus === 'failed') {
      toastFail(hgncJob.error.value || 'HGNC update failed');
      loadJobHistory();
    }
  }
);

watch(
  () => publicationRefreshJob.status.value,
  (newStatus) => {
    if (newStatus === 'completed') {
      toastDone('Publications refreshed successfully');
      loadPublicationStats();
      loadFilteredCount();
      loadJobHistory();
    } else if (newStatus === 'failed') {
      toastFail(publicationRefreshJob.error.value || 'Publication refresh failed');
      loadJobHistory();
    }
  }
);

watch(
  () => comparisonsJob.status.value,
  (newStatus) => {
    if (newStatus === 'completed') {
      toastDone('Comparisons data refreshed successfully');
      loadComparisonsMetadata();
      loadJobHistory();
    } else if (newStatus === 'failed') {
      toastFail(comparisonsJob.error.value || 'Comparisons refresh failed');
      loadJobHistory();
    }
  }
);

watch(notUpdatedSince, () => {
  if (notUpdatedSince.value) {
    loadFilteredCount();
  } else {
    filteredCount.value = null;
  }
});

// ---------------------------------------------------------------------------
// Loaders
// ---------------------------------------------------------------------------
async function loadAnnotationDates(): Promise<void> {
  try {
    annotationDates.value = await api.fetchAnnotationDates();
  } catch (error) {
    console.warn('Failed to fetch annotation dates:', error);
  }
}

async function loadJobHistory(): Promise<void> {
  jobHistoryLoading.value = true;
  try {
    jobHistory.value = await api.fetchJobHistory(20);
  } catch (error) {
    console.warn('Failed to fetch job history:', error);
    jobHistory.value = [];
  } finally {
    jobHistoryLoading.value = false;
  }
}

async function onCheckDeprecated(): Promise<void> {
  loadingDeprecated.value = true;
  try {
    deprecatedData.value = await api.fetchDeprecatedEntities();
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
    toastFail('Failed to check deprecated entities');
    console.error('Failed to fetch deprecated entities:', error);
  } finally {
    loadingDeprecated.value = false;
  }
}

async function loadPubtatorStats(): Promise<void> {
  loadingPubtatorStats.value = true;
  try {
    pubtatorStats.value = await api.fetchPubtatorStats();
  } catch (error) {
    console.warn('Failed to fetch Pubtator stats:', error);
    pubtatorStats.value = { publication_count: null, gene_count: null, novel_count: null };
  } finally {
    loadingPubtatorStats.value = false;
  }
}

async function loadPublicationStats(): Promise<void> {
  loadingPublicationStats.value = true;
  try {
    const stats = await api.fetchPublicationStats();
    publicationStats.value = {
      total: stats.total,
      oldest_update: stats.oldest_update,
      outdated_count: stats.outdated_count,
    };
  } catch (error) {
    console.warn('Failed to fetch publication stats:', error);
  } finally {
    loadingPublicationStats.value = false;
  }
}

async function loadComparisonsMetadata(): Promise<void> {
  loadingComparisonsMetadata.value = true;
  try {
    comparisonsMetadata.value = await api.fetchComparisonsMetadata();
  } catch (error) {
    console.warn('Failed to fetch comparisons metadata:', error);
  } finally {
    loadingComparisonsMetadata.value = false;
  }
}

async function loadFilteredCount(): Promise<void> {
  if (!notUpdatedSince.value) {
    filteredCount.value = null;
    return;
  }
  loadingFilteredCount.value = true;
  try {
    const stats = await api.fetchPublicationStats(notUpdatedSince.value);
    filteredCount.value = stats.filtered_count;
  } catch (error) {
    console.warn('Failed to fetch filtered count:', error);
    filteredCount.value = null;
  } finally {
    loadingFilteredCount.value = false;
  }
}

// ---------------------------------------------------------------------------
// Actions
// ---------------------------------------------------------------------------
function startJobIfOk(
  job: ReturnType<typeof useAsyncJob>,
  data: api.JobSubmissionResponse,
  fallbackMsg: string
): void {
  if (data.error) {
    toastFail(data.message || fallbackMsg);
    return;
  }
  if (data.job_id !== undefined) {
    job.startJob(unwrapValue(data.job_id) as string);
  }
}

async function onStartOntology(): Promise<void> {
  ontologyJob.reset();
  try {
    startJobIfOk(ontologyJob, await api.submitOntologyUpdate(), 'Failed to start update');
  } catch {
    toastFail('Failed to start ontology update');
  }
}

async function onForceApply(payload: {
  blocked_job_id: string;
  assigned_user_id: number | null;
}): Promise<void> {
  forceApplyJob.reset();
  try {
    const data = await api.submitForceApplyOntology(
      payload.blocked_job_id,
      payload.assigned_user_id
    );
    startJobIfOk(forceApplyJob, data, data.error ?? 'Force-apply failed');
  } catch {
    toastFail('Failed to start force-apply');
  }
}

function dismissBlockedOntology(): void {
  ontologyBlocked.value = null;
}

async function onStartHgnc(): Promise<void> {
  hgncJob.reset();
  try {
    startJobIfOk(hgncJob, await api.submitHgncUpdate(), 'Failed to start HGNC update');
  } catch {
    toastFail('Failed to start HGNC update');
  }
}

async function onStartComparisons(): Promise<void> {
  comparisonsJob.reset();
  try {
    const data = await api.submitComparisonsRefresh();
    if (data.error === 'DUPLICATE_JOB') {
      makeToast('A comparisons update job is already running', 'Info', 'info');
      if (data.existing_job_id !== undefined) {
        comparisonsJob.startJob(unwrapValue(data.existing_job_id) as string);
      }
      return;
    }
    startJobIfOk(comparisonsJob, data, 'Failed to start comparisons update');
  } catch (error) {
    toastFail('Failed to start comparisons update');
    console.error('Comparisons refresh error:', error);
  }
}

function setPreset(preset: FilterPreset): void {
  selectedPreset.value = preset;
  if (preset !== 'custom') customDate.value = '';
}

async function onRefreshFilteredPublications(): Promise<void> {
  if (!notUpdatedSince.value) {
    makeToast('No filter selected', 'Info', 'info');
    return;
  }
  publicationRefreshJob.reset();
  try {
    const data = await api.submitPublicationRefresh({
      not_updated_since: notUpdatedSince.value,
    });
    if (data.error) {
      toastFail(data.message || 'Failed to start refresh');
      return;
    }
    if (data.count === 0) {
      makeToast(data.message || 'No publications need refreshing', 'Info', 'info');
      return;
    }
    if (data.status === 'already_running') {
      makeToast('A refresh job is already running', 'Info', 'info');
    }
    if (data.job_id !== undefined) {
      publicationRefreshJob.startJob(unwrapValue(data.job_id) as string);
    }
  } catch (error) {
    toastFail('Failed to start publication refresh');
    console.error('Publication refresh error:', error);
  }
}

async function onRefreshAllPublications(): Promise<void> {
  publicationRefreshJob.reset();
  try {
    const pmids = await api.fetchAllPublicationPmids();
    if (pmids.length === 0) {
      makeToast('No publications to refresh', 'Info', 'info');
      return;
    }
    const data = await api.submitPublicationRefresh({ pmids });
    if (data.error) {
      toastFail(data.message || 'Failed to start refresh');
      return;
    }
    if (data.status === 'already_running') {
      makeToast('A refresh job is already running', 'Info', 'info');
    }
    if (data.job_id !== undefined) {
      publicationRefreshJob.startJob(unwrapValue(data.job_id) as string);
    }
  } catch (error) {
    toastFail('Failed to start publication refresh');
    console.error('Publication refresh error:', error);
  }
}

async function downloadJobHistory(): Promise<void> {
  try {
    const rows = await api.fetchJobHistoryRaw(1000);
    if (rows.length === 0) {
      makeToast('No job history to download', 'Info', 'info');
      return;
    }
    const headers = ['Job ID', 'Operation', 'Status', 'Started', 'Duration (s)', 'Error'];
    const csvRows = rows.map((job) => [
      unwrapValue(job.job_id),
      unwrapValue(job.operation),
      unwrapValue(job.status),
      unwrapValue(job.submitted_at),
      unwrapValue(job.duration_seconds) ?? '',
      unwrapValue(job.error_message) ?? '',
    ]);
    const csv = [
      headers.join(','),
      ...csvRows.map((row) =>
        row.map((v) => `"${String(v).replace(/"/g, '""')}"`).join(',')
      ),
    ].join('\n');
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.href = url;
    link.download = `job_history_${new Date().toISOString().split('T')[0]}.csv`;
    link.click();
    URL.revokeObjectURL(url);
    toastDone('Job history downloaded');
  } catch (error) {
    toastFail('Failed to download job history');
    console.error('Download error:', error);
  }
}

function copyPageLink(): void {
  navigator.clipboard
    .writeText(window.location.href)
    .then(() => makeToast('Page link copied to clipboard', 'Copied', 'success'))
    .catch(() => toastFail('Failed to copy link'));
}

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------
onMounted(() => {
  initFromUrl();
  loadAnnotationDates();
  loadJobHistory();
  loadPubtatorStats();
  loadPublicationStats();
  loadComparisonsMetadata();
});
</script>
