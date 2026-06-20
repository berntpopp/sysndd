<template>
  <AuthenticatedPageShell
    title="Manage Ontology Mappings"
    description="Monitor and trigger the disease cross-ontology mapping build. Mappings populate automatically on startup and weekly."
    content-class="authenticated-route-content"
    full-width
  >
    <BContainer fluid class="ont-admin">
      <!-- ─── Status panel ──────────────────────────────────────────────── -->
      <AdminOperationPanel
        title="Mapping index status"
        description="Latest disease cross-ontology mapping build and recent build history."
        icon="bi-diagram-3"
        :meta="statusMeta"
        :aria-busy="loadingStatus ? 'true' : 'false'"
      >
        <BAlert v-if="loadError" variant="danger" show class="mb-3">
          <i class="bi bi-exclamation-triangle-fill me-1" aria-hidden="true" />
          {{ loadError }}
        </BAlert>

        <div v-if="loadingStatus" class="ont-loading" role="status" aria-live="polite">
          <BSpinner small class="me-2" />
          Loading mapping status...
        </div>

        <BAlert
          v-else-if="!mappingStatus?.build_exists"
          variant="warning"
          show
          class="mb-0"
          data-testid="ont-cold-start-warning"
        >
          <i class="bi bi-exclamation-triangle-fill me-1" aria-hidden="true" />
          No disease ontology mappings have been built yet. They populate automatically on startup
          (and weekly); click <strong>Refresh now</strong> to build them immediately.
        </BAlert>

        <div v-else-if="mappingStatus?.latest" class="ont-build">
          <div class="ont-build__identity">
            <div>
              <span class="ont-label">MONDO release</span>
              <strong class="ont-mono" data-testid="ont-mondo-release">{{
                mappingStatus.latest.mondo_release_version ?? '—'
              }}</strong>
            </div>
            <BBadge :class="buildStatusClass(mappingStatus.latest.status)">
              {{ mappingStatus.latest.status ?? '—' }}
            </BBadge>
          </div>

          <div class="ont-kpi-grid" aria-label="Build counts">
            <div class="ont-kpi">
              <span>Mappings</span>
              <strong data-testid="ont-mapping-count">{{
                fmtNum(mappingStatus.latest.mapping_count)
              }}</strong>
            </div>
            <div class="ont-kpi">
              <span>Diseases covered</span>
              <strong>{{ fmtNum(mappingStatus.latest.disease_covered_count) }}</strong>
            </div>
            <div class="ont-kpi">
              <span>MONDO terms</span>
              <strong>{{ fmtNum(mappingStatus.latest.mondo_term_count) }}</strong>
            </div>
            <div class="ont-kpi">
              <span>Cross-refs</span>
              <strong>{{ fmtNum(mappingStatus.latest.mondo_xref_count) }}</strong>
            </div>
          </div>

          <div class="ont-detail-grid">
            <div class="ont-detail">
              <span class="ont-label">Finished</span>
              <span>{{ fmtDate(mappingStatus.latest.build_finished_at) }}</span>
            </div>
            <div class="ont-detail">
              <span class="ont-label">Duration</span>
              <span>{{
                mappingStatus.latest.build_duration_s != null
                  ? `${mappingStatus.latest.build_duration_s.toFixed(1)} s`
                  : '—'
              }}</span>
            </div>
          </div>

          <section v-if="mappingStatus.history.length > 1" class="ont-subsection">
            <h3>Recent history</h3>
            <div class="ont-history-list">
              <div
                v-for="row in mappingStatus.history.slice(0, 5)"
                :key="row.id"
                class="ont-history-row"
              >
                <BBadge :class="buildStatusClass(row.status)" class="me-2">
                  {{ row.status ?? '—' }}
                </BBadge>
                <span class="ont-mono me-2">{{ row.mondo_release_version ?? '—' }}</span>
                <span class="ont-muted">{{ fmtDate(row.build_finished_at) }}</span>
              </div>
            </div>
          </section>
        </div>

        <BAlert v-else variant="secondary" show class="mb-0">
          No build records found.
        </BAlert>
      </AdminOperationPanel>

      <!-- ─── Control panel ─────────────────────────────────────────────── -->
      <AdminOperationPanel
        title="Rebuild mappings"
        description="Enqueue an immediate mapping refresh. The orchestrator skips the heavy rebuild when the MONDO release is unchanged unless you request a force rebuild."
        icon="bi-arrow-repeat"
        heading-tag="h2"
        :aria-busy="submitting || refreshJob.isLoading.value ? 'true' : 'false'"
      >
        <template #actions>
          <BButton
            variant="primary"
            size="sm"
            data-testid="ontology-mapping-refresh-btn"
            :disabled="submitting || refreshJob.isLoading.value"
            @click="triggerRefresh"
          >
            <BSpinner v-if="submitting" small class="me-1" />
            <i v-else class="bi bi-arrow-clockwise me-1" aria-hidden="true" />
            Refresh now
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

        <div
          v-if="refreshJob.jobId.value"
          class="ont-job"
          data-testid="ont-active-job"
          role="status"
          aria-live="polite"
        >
          <div class="ont-job__header">
            <div>
              <BBadge :class="refreshJob.statusBadgeClass.value" class="me-2">
                {{ refreshJob.status.value }}
              </BBadge>
              <span class="ont-job__id">Job {{ refreshJob.jobId.value }}</span>
            </div>
            <span class="ont-job__elapsed">
              <i class="bi bi-clock me-1" aria-hidden="true" />
              {{ refreshJob.elapsedTimeDisplay.value }}
            </span>
          </div>
          <p v-if="refreshJob.step.value" class="ont-job__step">{{ refreshJob.step.value }}</p>
          <BProgress :max="100" height="0.875rem">
            <BProgressBar
              :value="
                refreshJob.hasRealProgress.value ? (refreshJob.progressPercent.value ?? 0) : 100
              "
              :variant="refreshJob.progressVariant.value"
              :striped="!refreshJob.hasRealProgress.value"
              :animated="refreshJob.isLoading.value"
            >
              <template v-if="refreshJob.hasRealProgress.value">
                {{ refreshJob.progress.value.current }}/{{ refreshJob.progress.value.total }}
              </template>
              <template v-else-if="refreshJob.isLoading.value">Processing...</template>
            </BProgressBar>
          </BProgress>
          <BAlert v-if="refreshJob.error.value" variant="danger" show class="mt-3 mb-0">
            <i class="bi bi-exclamation-triangle-fill me-1" aria-hidden="true" />
            {{ refreshJob.error.value }}
          </BAlert>
        </div>
      </AdminOperationPanel>
    </BContainer>
  </AuthenticatedPageShell>
</template>

<script setup lang="ts">
import AuthenticatedPageShell from '@/components/layout/AuthenticatedPageShell.vue';
import AdminOperationPanel from '@/components/admin/AdminOperationPanel.vue';
import { computed, onMounted, ref, watch } from 'vue';
import { useAsyncJob } from '@/composables/useAsyncJob';
import {
  fetchOntologyMappingStatus,
  submitOntologyMappingRefresh,
  type OntologyMappingStatus,
} from '@/api/ontology_mapping_admin';
import {
  BAlert,
  BBadge,
  BButton,
  BContainer,
  BProgress,
  BProgressBar,
  BSpinner,
} from 'bootstrap-vue-next';
import { extractApiErrorMessage } from '@/utils/api-errors';
import { useHead } from '@unhead/vue';

useHead({ title: 'Manage Ontology Mappings' });

const jobStatusUrl = (jobId: string) => `/api/jobs/${encodeURIComponent(jobId)}/status`;
const refreshJob = useAsyncJob(jobStatusUrl);

const mappingStatus = ref<OntologyMappingStatus | null>(null);
const loadingStatus = ref(true);
const submitting = ref(false);
const loadError = ref('');
const actionError = ref('');
const actionMessage = ref('');

const statusMeta = computed<string | null>(() => {
  if (!mappingStatus.value?.latest) return null;
  const v = mappingStatus.value.latest.mondo_release_version;
  return v ? `MONDO ${v}` : null;
});

onMounted(() => {
  void loadStatus();
});

watch(
  () => refreshJob.status.value,
  (nextStatus) => {
    if (nextStatus === 'completed' || nextStatus === 'failed') {
      void loadStatus();
    }
  }
);

async function loadStatus(): Promise<void> {
  loadingStatus.value = true;
  loadError.value = '';
  try {
    mappingStatus.value = await fetchOntologyMappingStatus();
  } catch (err) {
    loadError.value = extractApiErrorMessage(
      err,
      'Failed to load disease ontology mapping status.'
    );
  } finally {
    loadingStatus.value = false;
  }
}

async function triggerRefresh(): Promise<void> {
  submitting.value = true;
  actionError.value = '';
  actionMessage.value = '';
  try {
    const result = await submitOntologyMappingRefresh(true);
    if (result.skipped) {
      actionMessage.value = result.message || 'Mapping build skipped (already up to date).';
      return;
    }
    if (result.job_id) {
      refreshJob.reset();
      refreshJob.startJob(result.job_id);
    }
    if (result.duplicate) {
      actionMessage.value = result.message || 'A mapping refresh is already running.';
    } else if (result.submitted) {
      actionMessage.value = result.message || 'Mapping refresh job submitted.';
    }
  } catch (err) {
    actionError.value = extractApiErrorMessage(
      err,
      'Failed to submit disease ontology mapping refresh.'
    );
  } finally {
    submitting.value = false;
  }
}

function buildStatusClass(status: string | null): string {
  switch (status) {
    case 'success':
      return 'bg-success';
    case 'failed':
      return 'bg-danger';
    case 'skipped':
      return 'bg-warning text-dark';
    default:
      return 'bg-secondary';
  }
}

function fmtNum(n: number | null | undefined): string {
  if (n == null) return '—';
  return n.toLocaleString();
}

function fmtDate(s: string | null | undefined): string {
  if (!s) return '—';
  try {
    return new Date(s).toLocaleString();
  } catch {
    return s;
  }
}
</script>

<style scoped>
.ont-admin {
  padding: 0;
}

.ont-loading {
  color: var(--neutral-600, #757575);
  font-size: 0.875rem;
}

.ont-build,
.ont-job {
  min-width: 0;
}

.ont-build__identity,
.ont-job__header {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  align-items: center;
  justify-content: space-between;
}

.ont-label {
  display: block;
  color: var(--neutral-600, #757575);
  font-size: 0.75rem;
  font-weight: 700;
  line-height: 1.25;
}

.ont-mono,
.ont-job__id {
  overflow-wrap: anywhere;
  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, Consolas, monospace);
}

.ont-muted {
  color: var(--neutral-600, #757575);
  font-size: 0.8125rem;
}

.ont-kpi-grid {
  display: grid;
  grid-template-columns: repeat(4, minmax(0, 1fr));
  gap: 0.75rem;
  margin-top: 1rem;
}

.ont-kpi,
.ont-detail {
  min-width: 0;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: var(--radius-md, 0.375rem);
  background: #f8fafc;
}

.ont-kpi {
  padding: 0.625rem 0.75rem;
}

.ont-kpi span {
  display: block;
  color: var(--neutral-600, #757575);
  font-size: 0.75rem;
  font-weight: 700;
}

.ont-kpi strong {
  color: var(--neutral-900, #212121);
  font-size: 1.1rem;
  line-height: 1.25;
}

.ont-detail-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0.75rem;
  margin-top: 1rem;
}

.ont-detail {
  padding: 0.625rem 0.75rem;
  color: var(--neutral-900, #212121);
  font-size: 0.875rem;
}

.ont-subsection {
  margin-top: 1rem;
}

.ont-subsection h3 {
  margin: 0 0 0.5rem;
  color: var(--neutral-900, #212121);
  font-size: 0.95rem;
  font-weight: 700;
}

.ont-history-list {
  display: flex;
  flex-direction: column;
  gap: 0.375rem;
}

.ont-history-row {
  display: flex;
  align-items: center;
  font-size: 0.875rem;
}

.ont-job {
  margin-top: 1rem;
  padding: 0.75rem;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: var(--radius-md, 0.375rem);
  background: #f8fafc;
}

.ont-job__step,
.ont-job__elapsed {
  margin: 0.35rem 0;
  color: var(--neutral-600, #757575);
  font-size: 0.8125rem;
}

@media (max-width: 767.98px) {
  .ont-kpi-grid,
  .ont-detail-grid {
    grid-template-columns: repeat(2, minmax(0, 1fr));
  }
}

@media (max-width: 479.98px) {
  .ont-kpi-grid,
  .ont-detail-grid {
    grid-template-columns: 1fr;
  }
}
</style>
