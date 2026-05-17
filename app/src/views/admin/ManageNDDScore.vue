<template>
  <AuthenticatedPageShell
    title="Manage NDDScore"
    description="Maintain the ML prediction release imported from Zenodo. The prediction layer stays separate from curated SysNDD evidence."
    content-class="authenticated-route-content"
    full-width
  >
    <BContainer fluid class="ndd-admin">
      <AdminOperationPanel
        title="Active release"
        description="Currently active NDDScore release and import provenance."
        icon="bi-graph-up-arrow"
        :meta="activeReleaseStatus"
      >
        <BAlert v-if="loadError" variant="danger" show class="mb-3">
          <i class="bi bi-exclamation-triangle-fill me-1" aria-hidden="true" />
          {{ loadError }}
        </BAlert>

        <div v-if="loadingStatus" class="ndd-loading">
          <BSpinner small class="me-2" />
          Loading NDDScore status...
        </div>

        <div v-else-if="activeRelease" class="ndd-release">
          <div class="ndd-release__identity">
            <div>
              <span class="ndd-label">Release ID</span>
              <strong class="ndd-mono">{{ displayValue(activeRelease.release_id) }}</strong>
            </div>
            <BBadge :class="statusClass(activeRelease.import_status)">
              {{ displayValue(activeRelease.import_status) }}
            </BBadge>
          </div>

          <div class="ndd-kpi-grid" aria-label="Imported counts">
            <div v-for="item in countItems" :key="item.key" class="ndd-kpi">
              <span>{{ item.label }}</span>
              <strong>{{ item.value }}</strong>
            </div>
          </div>

          <div class="ndd-detail-grid">
            <div v-for="row in releaseRows" :key="row.label" class="ndd-detail">
              <span class="ndd-label">{{ row.label }}</span>
              <span :class="{ 'ndd-mono': row.mono }">{{ row.value }}</span>
            </div>
          </div>

          <section v-if="performanceRows.length" class="ndd-subsection">
            <h3>Performance summary</h3>
            <div class="ndd-detail-grid ndd-detail-grid--compact">
              <div v-for="row in performanceRows" :key="row.label" class="ndd-detail">
                <span class="ndd-label">{{ row.label }}</span>
                <span>{{ row.value }}</span>
              </div>
            </div>
          </section>

          <BAlert v-if="activeRelease.last_error_message" variant="danger" show class="mt-3 mb-0">
            <i class="bi bi-exclamation-triangle-fill me-1" aria-hidden="true" />
            {{ displayValue(activeRelease.last_error_message) }}
          </BAlert>
        </div>

        <BAlert v-else variant="warning" show class="mb-0">
          No active NDDScore release is recorded.
        </BAlert>
      </AdminOperationPanel>

      <AdminOperationPanel
        title="Release update"
        description="Check Zenodo, validate the archive, then import and activate the latest release when ready."
        icon="bi-cloud-arrow-down"
        heading-tag="h2"
      >
        <template #actions>
          <BButton
            variant="outline-primary"
            size="sm"
            :disabled="checkingZenodo"
            @click="checkZenodo"
          >
            <BSpinner v-if="checkingZenodo" small class="me-1" />
            <i v-else class="bi bi-search me-1" aria-hidden="true" />
            Check Zenodo
          </BButton>
          <BButton
            variant="outline-primary"
            size="sm"
            :disabled="submittingJob || importJob.isLoading.value"
            @click="submitValidateOnly"
          >
            <BSpinner v-if="submittingValidate" small class="me-1" />
            <i v-else class="bi bi-shield-check me-1" aria-hidden="true" />
            Download & validate
          </BButton>
          <BButton
            variant="primary"
            size="sm"
            data-testid="ndd-import-btn"
            :disabled="submittingJob || importJob.isLoading.value"
            @click="showImportModal = true"
          >
            <i class="bi bi-upload me-1" aria-hidden="true" />
            Import & activate latest release
          </BButton>
        </template>

        <BAlert v-if="actionError" variant="danger" show class="mb-3">
          <i class="bi bi-exclamation-triangle-fill me-1" aria-hidden="true" />
          {{ actionError }}
        </BAlert>
        <BAlert v-if="actionMessage" variant="info" show class="mb-3">
          <i class="bi bi-info-circle-fill me-1" aria-hidden="true" />
          {{ actionMessage }}
        </BAlert>

        <div v-if="zenodoResult" class="ndd-zenodo" data-testid="ndd-zenodo-result">
          <div class="ndd-detail-grid">
            <div class="ndd-detail">
              <span class="ndd-label">Zenodo archive</span>
              <span class="ndd-mono">{{ zenodoArchiveName }}</span>
            </div>
            <div class="ndd-detail">
              <span class="ndd-label">Checksum</span>
              <span class="ndd-mono">{{ zenodoChecksum }}</span>
            </div>
            <div class="ndd-detail">
              <span class="ndd-label">Matches active</span>
              <span>{{ zenodoResult.matches_active ? 'Yes' : 'No' }}</span>
            </div>
          </div>
        </div>

        <div v-if="importJob.jobId.value" class="ndd-job" data-testid="ndd-active-job">
          <div class="ndd-job__header">
            <div>
              <BBadge :class="importJob.statusBadgeClass.value" class="me-2">
                {{ importJob.status.value }}
              </BBadge>
              <span class="ndd-job__id">Job {{ importJob.jobId.value }}</span>
            </div>
            <span class="ndd-job__elapsed">
              <i class="bi bi-clock me-1" aria-hidden="true" />
              {{ importJob.elapsedTimeDisplay.value }}
            </span>
          </div>
          <p v-if="importJob.step.value" class="ndd-job__step">{{ importJob.step.value }}</p>
          <BProgress :max="100" height="0.875rem">
            <BProgressBar
              :value="
                importJob.hasRealProgress.value ? (importJob.progressPercent.value ?? 0) : 100
              "
              :variant="importJob.progressVariant.value"
              :striped="!importJob.hasRealProgress.value"
              :animated="importJob.isLoading.value"
            >
              <template v-if="importJob.hasRealProgress.value">
                {{ importJob.progress.value.current }}/{{ importJob.progress.value.total }}
              </template>
              <template v-else-if="importJob.isLoading.value">Processing...</template>
            </BProgressBar>
          </BProgress>
          <BAlert v-if="importJob.error.value" variant="danger" show class="mt-3 mb-0">
            <i class="bi bi-exclamation-triangle-fill me-1" aria-hidden="true" />
            {{ importJob.error.value }}
          </BAlert>
        </div>
      </AdminOperationPanel>

      <AdminOperationPanel
        title="Recent jobs"
        description="Latest NDDScore import and validation jobs reported by the admin API."
        icon="bi-list-check"
        heading-tag="h2"
      >
        <div class="ndd-table-wrap d-none d-md-block">
          <table class="table table-sm align-middle mb-0 ndd-table">
            <thead>
              <tr>
                <th scope="col">Job</th>
                <th scope="col">Status</th>
                <th scope="col">Mode</th>
                <th scope="col">Release</th>
                <th scope="col">Updated</th>
                <th scope="col">Error</th>
              </tr>
            </thead>
            <tbody>
              <tr v-if="!recentJobs.length">
                <td colspan="6" class="ndd-empty-row">No recent NDDScore jobs.</td>
              </tr>
              <tr v-for="job in recentJobs" :key="jobKey(job)">
                <td class="ndd-mono">{{ firstValue(job, ['job_id', 'id']) }}</td>
                <td>
                  <BBadge :class="statusClass(firstValue(job, ['status', 'job_status']))">
                    {{ firstValue(job, ['status', 'job_status']) }}
                  </BBadge>
                </td>
                <td>{{ jobMode(job) }}</td>
                <td class="ndd-mono">{{ firstValue(job, ['release_id']) }}</td>
                <td>
                  {{ formatDate(firstValue(job, ['updated_at', 'completed_at', 'created_at'])) }}
                </td>
                <td class="ndd-error-cell">{{ firstValue(job, ['error', 'error_message']) }}</td>
              </tr>
            </tbody>
          </table>
        </div>

        <div class="ndd-mobile-rows d-md-none">
          <article v-if="!recentJobs.length" class="ndd-mobile-row">
            <div class="ndd-mobile-row__main">
              <strong>No recent NDDScore jobs</strong>
            </div>
          </article>
          <article v-for="job in recentJobs" :key="jobKey(job)" class="ndd-mobile-row">
            <div class="ndd-mobile-row__main">
              <strong class="ndd-mono">{{ firstValue(job, ['job_id', 'id']) }}</strong>
              <BBadge :class="statusClass(firstValue(job, ['status', 'job_status']))">
                {{ firstValue(job, ['status', 'job_status']) }}
              </BBadge>
            </div>
            <div class="ndd-mobile-row__meta">
              <span>{{ jobMode(job) }}</span>
              <span>{{
                formatDate(firstValue(job, ['updated_at', 'completed_at', 'created_at']))
              }}</span>
            </div>
            <div class="ndd-mono">{{ firstValue(job, ['release_id']) }}</div>
            <div v-if="firstValue(job, ['error', 'error_message'])" class="ndd-mobile-row__error">
              {{ firstValue(job, ['error', 'error_message']) }}
            </div>
          </article>
        </div>
      </AdminOperationPanel>

      <BModal v-model="showImportModal" title="Import and activate latest NDDScore release">
        <p>
          This starts a background import for the latest Zenodo archive. The previous active release
          stays active until activation succeeds.
        </p>
        <p class="mb-0">
          Use validate-only first when you need to check archive contents without changing the
          active release.
        </p>
        <template #footer>
          <BButton variant="secondary" @click="showImportModal = false">Cancel</BButton>
          <BButton variant="primary" :disabled="submittingJob" @click="confirmImport">
            <BSpinner v-if="submittingImport" small class="me-1" />
            Import & activate
          </BButton>
        </template>
      </BModal>
    </BContainer>
  </AuthenticatedPageShell>
</template>

<script setup lang="ts">
import AuthenticatedPageShell from '@/components/layout/AuthenticatedPageShell.vue';
import AdminOperationPanel from '@/components/admin/AdminOperationPanel.vue';
import { computed, onMounted, ref } from 'vue';
import { useAsyncJob } from '@/composables/useAsyncJob';
import {
  fetchNddScoreStatus,
  fetchNddScoreZenodo,
  submitNddScoreImport,
  type NddScoreAdminStatus,
  type NddScoreZenodoComparison,
} from '@/api/nddscore_admin';
import {
  BAlert,
  BBadge,
  BButton,
  BContainer,
  BModal,
  BProgress,
  BProgressBar,
  BSpinner,
} from 'bootstrap-vue-next';

type RecordValue = string | number | boolean | null | undefined | Record<string, unknown>;
type AdminRecord = Record<string, RecordValue>;

const jobStatusUrl = (jobId: string) => `${import.meta.env.VITE_API_URL}/api/jobs/${jobId}/status`;
const importJob = useAsyncJob(jobStatusUrl);

const status = ref<NddScoreAdminStatus | null>(null);
const zenodoResult = ref<NddScoreZenodoComparison | null>(null);
const loadingStatus = ref(true);
const checkingZenodo = ref(false);
const submittingValidate = ref(false);
const submittingImport = ref(false);
const showImportModal = ref(false);
const loadError = ref('');
const actionError = ref('');
const actionMessage = ref('');

const activeRelease = computed<AdminRecord | null>(() =>
  normalizeRecord(status.value?.active_release)
);
const recentJobs = computed<AdminRecord[]>(() =>
  (status.value?.recent_jobs ?? [])
    .map(normalizeRecord)
    .filter((job): job is AdminRecord => Boolean(job))
);
const submittingJob = computed(() => submittingValidate.value || submittingImport.value);

const activeReleaseStatus = computed(() => {
  if (loadingStatus.value) return 'Loading';
  if (!activeRelease.value) return 'No active release';
  return displayValue(activeRelease.value.import_status);
});

const countItems = computed(() => [
  {
    key: 'genes',
    label: 'Genes',
    value: formatInteger(activeRelease.value?.n_genes),
  },
  {
    key: 'hpo-predictions',
    label: 'HPO predictions',
    value: formatInteger(activeRelease.value?.n_hpo_predictions),
  },
  {
    key: 'hpo-terms',
    label: 'HPO terms',
    value: formatInteger(activeRelease.value?.n_hpo_terms),
  },
]);

const releaseRows = computed(() => [
  {
    label: 'Version DOI',
    value: displayValue(activeRelease.value?.version_doi),
    mono: true,
  },
  {
    label: 'Concept DOI',
    value: displayValue(activeRelease.value?.concept_doi),
    mono: true,
  },
  {
    label: 'Archive',
    value: firstValue(activeRelease.value, [
      'source_archive_name',
      'archive_name',
      'zenodo_archive_name',
    ]),
    mono: true,
  },
  {
    label: 'Checksum',
    value: firstValue(activeRelease.value, [
      'source_archive_checksum',
      'archive_checksum',
      'checksum',
    ]),
    mono: true,
  },
  {
    label: 'Activated',
    value: formatDate(activeRelease.value?.activated_at),
    mono: false,
  },
  {
    label: 'Imported',
    value: formatDate(activeRelease.value?.imported_at),
    mono: false,
  },
]);

const performanceRows = computed(() => {
  const raw = activeRelease.value?.performance_summary;
  const record = normalizeRecord(raw);
  if (!record) return [];

  return Object.entries(record).map(([key, value]) => ({
    label: humanizeKey(key),
    value: displayValue(value),
  }));
});

const zenodoArchiveName = computed(() =>
  firstValue(normalizeRecord(zenodoResult.value?.zenodo), [
    'source_archive_name',
    'archive_name',
    'filename',
    'name',
  ])
);

const zenodoChecksum = computed(() =>
  firstValue(normalizeRecord(zenodoResult.value?.zenodo), [
    'source_archive_checksum',
    'archive_checksum',
    'checksum',
  ])
);

onMounted(() => {
  void loadStatus();
});

async function loadStatus() {
  loadingStatus.value = true;
  loadError.value = '';
  try {
    status.value = await fetchNddScoreStatus();
  } catch {
    loadError.value = 'Failed to load NDDScore admin status.';
  } finally {
    loadingStatus.value = false;
  }
}

async function checkZenodo() {
  checkingZenodo.value = true;
  actionError.value = '';
  actionMessage.value = '';
  try {
    zenodoResult.value = await fetchNddScoreZenodo();
    actionMessage.value = zenodoResult.value.matches_active
      ? 'Latest Zenodo archive matches the active release.'
      : 'Latest Zenodo archive differs from the active release.';
  } catch {
    actionError.value = 'Failed to check Zenodo release metadata.';
  } finally {
    checkingZenodo.value = false;
  }
}

async function submitValidateOnly() {
  submittingValidate.value = true;
  actionError.value = '';
  actionMessage.value = '';
  try {
    const result = await submitNddScoreImport({ validateOnly: true });
    importJob.reset();
    importJob.startJob(result.jobId);
    actionMessage.value = 'Validate-only job submitted.';
  } catch {
    actionError.value = 'Failed to submit validate-only job.';
  } finally {
    submittingValidate.value = false;
  }
}

async function confirmImport() {
  showImportModal.value = false;
  submittingImport.value = true;
  actionError.value = '';
  actionMessage.value = '';
  try {
    const result = await submitNddScoreImport({ validateOnly: false });
    importJob.reset();
    importJob.startJob(result.jobId);
    actionMessage.value = 'Import and activation job submitted.';
  } catch {
    actionError.value = 'Failed to submit import job.';
  } finally {
    submittingImport.value = false;
  }
}

function normalizeRecord(value: unknown): AdminRecord | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  return value as AdminRecord;
}

function firstValue(record: AdminRecord | null | undefined, keys: string[]) {
  if (!record) return 'Not recorded';
  const match = keys
    .map((key) => record[key])
    .find((value) => value !== null && value !== undefined);
  return displayValue(match);
}

function displayValue(value: unknown): string {
  if (Array.isArray(value)) {
    return value.length === 1 ? displayValue(value[0]) : value.map(displayValue).join(', ');
  }
  if (value === null || value === undefined || value === '') return 'Not recorded';
  if (typeof value === 'number') return Number.isFinite(value) ? String(value) : 'Not recorded';
  if (typeof value === 'boolean') return value ? 'Yes' : 'No';
  if (typeof value === 'object') return JSON.stringify(value);
  return String(value);
}

function formatInteger(value: unknown): string {
  const scalar = Array.isArray(value) ? value[0] : value;
  const numberValue = Number(scalar);
  return Number.isFinite(numberValue) ? numberValue.toLocaleString() : '0';
}

function formatDate(value: unknown): string {
  const raw = displayValue(value);
  if (raw === 'Not recorded') return raw;
  const parsed = new Date(raw);
  return Number.isNaN(parsed.getTime()) ? raw : parsed.toLocaleString();
}

function humanizeKey(key: string): string {
  return key.replace(/_/g, ' ').replace(/\b\w/g, (char) => char.toUpperCase());
}

function statusClass(value: unknown): string {
  const normalized = displayValue(value).toLowerCase();
  if (['active', 'completed', 'success', 'succeeded'].includes(normalized)) return 'bg-success';
  if (['failed', 'error'].includes(normalized)) return 'bg-danger';
  if (['running', 'accepted', 'pending'].includes(normalized)) return 'bg-primary';
  return 'bg-secondary';
}

function jobMode(job: AdminRecord): string {
  const validateOnly = job.validate_only;
  if (validateOnly === true || validateOnly === 'true' || validateOnly === 1)
    return 'Validate only';
  return 'Import';
}

function jobKey(job: AdminRecord): string {
  return firstValue(job, ['job_id', 'id', 'release_id', 'created_at']);
}

defineExpose({ confirmImport });
</script>

<style scoped>
.ndd-admin {
  padding: 0;
}

.ndd-loading,
.ndd-empty-row {
  color: var(--neutral-600, #757575);
  font-size: 0.875rem;
}

.ndd-release,
.ndd-zenodo,
.ndd-job {
  min-width: 0;
}

.ndd-release__identity,
.ndd-job__header,
.ndd-mobile-row__main,
.ndd-mobile-row__meta {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  align-items: center;
  justify-content: space-between;
}

.ndd-label {
  display: block;
  color: var(--neutral-600, #757575);
  font-size: 0.75rem;
  font-weight: 700;
  line-height: 1.25;
}

.ndd-mono,
.ndd-job__id,
.ndd-error-cell {
  overflow-wrap: anywhere;
  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, Consolas, monospace);
}

.ndd-kpi-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 0.75rem;
  margin-top: 1rem;
}

.ndd-kpi,
.ndd-detail,
.ndd-mobile-row {
  min-width: 0;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: var(--radius-md, 0.375rem);
  background: #f8fafc;
}

.ndd-kpi {
  padding: 0.625rem 0.75rem;
}

.ndd-kpi span {
  display: block;
  color: var(--neutral-600, #757575);
  font-size: 0.75rem;
  font-weight: 700;
}

.ndd-kpi strong {
  color: var(--neutral-900, #212121);
  font-size: 1.1rem;
  line-height: 1.25;
}

.ndd-detail-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0.75rem;
  margin-top: 1rem;
}

.ndd-detail-grid--compact {
  grid-template-columns: repeat(3, minmax(0, 1fr));
  margin-top: 0.5rem;
}

.ndd-detail {
  padding: 0.625rem 0.75rem;
  color: var(--neutral-900, #212121);
  font-size: 0.875rem;
}

.ndd-subsection {
  margin-top: 1rem;
}

.ndd-subsection h3 {
  margin: 0;
  color: var(--neutral-900, #212121);
  font-size: 0.95rem;
  font-weight: 700;
}

.ndd-job {
  margin-top: 1rem;
  padding: 0.75rem;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: var(--radius-md, 0.375rem);
  background: #f8fafc;
}

.ndd-job__step,
.ndd-job__elapsed {
  margin: 0.35rem 0;
  color: var(--neutral-600, #757575);
  font-size: 0.8125rem;
}

.ndd-table-wrap {
  overflow-x: auto;
}

.ndd-table {
  min-width: 760px;
  font-size: 0.875rem;
}

.ndd-table th {
  color: var(--neutral-900, #212121);
  font-size: 0.75rem;
  white-space: nowrap;
}

.ndd-table td {
  max-width: 18rem;
  vertical-align: middle;
}

.ndd-mobile-rows {
  display: grid;
  gap: 0.75rem;
}

.ndd-mobile-row {
  padding: 0.75rem;
  font-size: 0.875rem;
}

.ndd-mobile-row__meta {
  justify-content: flex-start;
  color: var(--neutral-600, #757575);
  font-size: 0.8125rem;
}

.ndd-mobile-row__error {
  margin-top: 0.5rem;
  color: var(--status-danger, #c62828);
  overflow-wrap: anywhere;
}

@media (max-width: 767.98px) {
  .ndd-kpi-grid,
  .ndd-detail-grid,
  .ndd-detail-grid--compact {
    grid-template-columns: 1fr;
  }
}
</style>
