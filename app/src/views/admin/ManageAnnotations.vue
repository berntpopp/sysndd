<!-- views/admin/ManageAnnotations.vue -->
<template>
  <AuthenticatedPageShell
    title="Manage Annotations"
    content-class="authenticated-route-content"
    full-width
  >
    <div class="container-fluid">
      <BContainer fluid>
        <BRow class="justify-content-md-center py-2">
          <BCol col md="12">
            <OntologyAnnotationsCard
              :ontology-job="ontologyJob"
              :force-apply-job="forceApplyJob"
              :blocked="ontologyBlocked"
              :last-updated="annotationDates.omim_update"
              :user-options="forceApplyUserOptions"
              :loading-users="loadingForceApplyUsers"
              @start-ontology="() => requestConfirm(ONTOLOGY_UPDATE_CONFIRM, onStartOntology)"
              @force-apply="
                (payload) => requestConfirm(FORCE_APPLY_CONFIRM, () => onForceApply(payload))
              "
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
              @start-refresh="() => requestConfirm(COMPARISONS_REFRESH_CONFIRM, onStartComparisons)"
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
              @refresh-all="() => requestConfirm(REFRESH_ALL_PUBLICATIONS_CONFIRM, onRefreshAllPublications)"
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

    <!-- Shared confirmation gate for heavy / irreversible operations. Stays
         mounted (no v-if) so its @hidden lifecycle clears any pending action. -->
    <ConfirmActionModal
      v-model="confirmOpen"
      :title="confirmConfig.title"
      :message="confirmConfig.message"
      :confirm-label="confirmConfig.confirmLabel ?? 'Confirm'"
      :confirm-variant="confirmConfig.confirmVariant ?? 'warning'"
      :header-bg-variant="confirmConfig.confirmVariant ?? 'warning'"
      :header-text-variant="confirmConfig.confirmVariant === 'danger' ? 'light' : 'dark'"
      icon="bi-exclamation-triangle-fill"
      :icon-class="confirmConfig.confirmVariant === 'danger' ? 'text-danger' : 'text-warning'"
      @confirm="acceptConfirm"
      @hidden="resetConfirm"
    />
  </AuthenticatedPageShell>
</template>

<script setup lang="ts">
import AuthenticatedPageShell from '@/components/layout/AuthenticatedPageShell.vue';
import ConfirmActionModal from '@/components/ui/ConfirmActionModal.vue';
import { ref, computed, onMounted, watch } from 'vue';
import { useRoute } from 'vue-router';
import { useHead } from '@unhead/vue';
import useToast from '@/composables/useToast';
import { useAsyncJob } from '@/composables/useAsyncJob';
import { useConfirmGate } from '@/composables/useConfirmGate';
import { unwrapValue } from '@/composables/annotations/useAnnotationFormatters';
import * as api from '@/composables/annotations/useAnnotationsApi';
import { useJobHistoryPanel } from '@/composables/annotations/useJobHistoryPanel';
import { useAnnotationJobReactions } from '@/composables/annotations/useAnnotationJobReactions';
import {
  ONTOLOGY_UPDATE_CONFIRM,
  FORCE_APPLY_CONFIRM,
  COMPARISONS_REFRESH_CONFIRM,
  REFRESH_ALL_PUBLICATIONS_CONFIRM,
} from '@/composables/annotations/annotationsConfirmCopy';
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
import JobHistoryCard from '@/components/annotations/JobHistoryCard.vue';

// ---------------------------------------------------------------------------
// Composables
// ---------------------------------------------------------------------------
const route = useRoute();
const { makeToast } = useToast();

useHead({ title: 'Manage Annotations' });

// Confirmation gate for heavy / irreversible operations (pairs with
// ConfirmActionModal in the template).
const {
  open: confirmOpen,
  config: confirmConfig,
  request: requestConfirm,
  accept: acceptConfirm,
  reset: resetConfirm,
} = useConfirmGate();

const jobStatusUrl = (jobId: string): string => `/api/jobs/${encodeURIComponent(jobId)}/status`;

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

// Job history panel: URL-synced table controls + data, derived views, CSV
// download, copy-link, and clear-all — all extracted to one composable.
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
  clearAllFilters,
  jobHistoryLoading,
  jobHistoryFields,
  filteredJobHistory,
  paginatedJobHistory,
  loadJobHistory,
  downloadJobHistory,
  copyPageLink,
} = useJobHistoryPanel(route, { onToast: makeToast });

// ---------------------------------------------------------------------------
// Toast-and-history wiring: per-job status reactions live in a composable.
// ---------------------------------------------------------------------------
function toastFail(msg: string): void {
  makeToast(msg, 'Error', 'danger');
}

useAnnotationJobReactions({
  ontologyJob,
  forceApplyJob,
  hgncJob,
  comparisonsJob,
  publicationRefreshJob,
  ontologyBlocked,
  forceApplyUserOptions,
  loadingForceApplyUsers,
  makeToast,
  reload: {
    annotationDates: loadAnnotationDates,
    jobHistory: loadJobHistory,
    publicationStats: loadPublicationStats,
    filteredCount: loadFilteredCount,
    comparisonsMetadata: loadComparisonsMetadata,
  },
});

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
