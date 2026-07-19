<!-- app/src/views/admin/ManageAnalysisReleases.vue -->
<!--
  Administrator page to build/publish/DOI-tag analysis-snapshot releases
  (#573 Slice B, Task B4b): immutable, content-addressed frozen exports of
  the public-ready analysis snapshots (functional clusters, phenotype
  clusters, phenotype-functional correlation). The build itself is
  SYNCHRONOUS and DB-only — there is no async job/worker involved, so this
  view never polls a job status (contrast ManageNDDScore.vue's import job).

  Kept thin: every client call and reactive state lives in the co-located
  `useAnalysisReleaseAdmin` composable; this file is template + light local
  UI-only state (the build form fields, the per-row DOI form drafts, and the
  two-step "Delete draft" confirm — an in-page affordance, never a blocking
  native `window.confirm`/dialog).
-->
<template>
  <AuthenticatedPageShell
    title="Manage analysis-snapshot releases"
    description="Build, publish, and DOI-tag immutable, content-addressed exports of SysNDD's public-ready analysis snapshots (functional clusters, phenotype clusters, and their correlation). Each release freezes its own copy of the data and survives snapshot pruning or refresh byte-identically."
    content-class="authenticated-route-content"
    full-width
  >
    <BContainer fluid class="analysis-release-admin">
      <AdminOperationPanel
        title="Snapshot readiness"
        description="A release build requires every release layer below to be available from the currently active public-ready snapshots."
        icon="bi-clipboard-data"
        :aria-busy="loading ? 'true' : 'false'"
      >
        <BAlert v-if="admin.actionError.value" variant="danger" show class="mb-3">
          <i class="bi bi-exclamation-triangle-fill me-1" aria-hidden="true" />
          {{ admin.actionError.value }}
        </BAlert>

        <div class="layer-readiness-grid" data-testid="layer-readiness-grid">
          <div
            v-for="item in admin.layerReadiness.value"
            :key="item.analysis_type"
            class="layer-readiness-item"
            :class="{ 'layer-readiness-item--ready': item.state === 'available' }"
            :data-testid="`layer-readiness-${item.analysis_type}`"
          >
            <i
              :class="[
                'bi',
                item.state === 'available' ? 'bi-check-circle-fill' : 'bi-x-circle-fill',
              ]"
              aria-hidden="true"
            />
            <div>
              <strong>{{ item.label }}</strong>
              <span class="layer-readiness-state">{{ item.state }}</span>
            </div>
          </div>
        </div>

        <p v-if="!admin.canBuild.value" class="layer-readiness-hint mb-0">
          Build is disabled until every release layer above reports
          <strong>available</strong>. Snapshots self-heal automatically (stale or missing
          snapshots re-enqueue on the next API restart), or an operator can force a refresh via
          <code>POST /api/admin/analysis/snapshots/refresh</code>.
        </p>
      </AdminOperationPanel>

      <AdminOperationPanel
        title="Build a release"
        description="Freezes the currently active public-ready snapshots into a new immutable release. Building as a draft (the default) lets you review and record a DOI before publishing."
        icon="bi-box-arrow-in-down"
        heading-tag="h2"
        :aria-busy="building ? 'true' : 'false'"
      >
        <BAlert v-if="admin.buildError.value" variant="danger" show class="mb-3" data-testid="build-error">
          <i class="bi bi-exclamation-triangle-fill me-1" aria-hidden="true" />
          {{ admin.buildError.value }}
        </BAlert>

        <BAlert
          v-if="lockedOutcome"
          variant="warning"
          show
          class="mb-3"
          data-testid="build-locked"
        >
          <i class="bi bi-hourglass-split me-1" aria-hidden="true" />
          Snapshot sources are refreshing, retry in {{ lockedOutcome.retryAfter }}s.
          {{ lockedOutcome.message }}
        </BAlert>

        <BAlert
          v-else-if="createdOrExistingOutcome"
          variant="success"
          show
          class="mb-3"
          data-testid="build-success"
        >
          <i class="bi bi-check-circle-fill me-1" aria-hidden="true" />
          Release <strong>{{ createdOrExistingOutcome.release.release_id }}</strong>
          {{ createdOrExistingOutcome.outcome === 'created' ? 'created' : 'already existed (identical content)' }}
          — status <strong>{{ createdOrExistingOutcome.release.status }}</strong>.
        </BAlert>

        <form class="build-form" @submit.prevent="handleBuild">
          <div class="build-form__field">
            <label for="release-title" class="form-label fw-semibold">Title</label>
            <BFormInput id="release-title" v-model="buildForm.title" data-testid="build-title" />
          </div>
          <div class="build-form__field">
            <label for="release-scope" class="form-label fw-semibold">Scope statement</label>
            <BFormTextarea
              id="release-scope"
              v-model="buildForm.scope_statement"
              rows="2"
              data-testid="build-scope"
            />
          </div>
          <div class="build-form__field">
            <label for="release-license" class="form-label fw-semibold">License</label>
            <BFormInput id="release-license" v-model="buildForm.license" data-testid="build-license" />
          </div>
          <div class="build-form__field build-form__field--checkbox form-check">
            <input
              id="release-publish"
              v-model="buildForm.publish"
              class="form-check-input"
              type="checkbox"
              data-testid="build-publish-checkbox"
            />
            <label class="form-check-label" for="release-publish">
              Publish immediately (unchecked builds a draft for review)
            </label>
          </div>
          <BButton
            type="submit"
            variant="primary"
            data-testid="build-release-btn"
            :disabled="!admin.canBuild.value || building"
          >
            <BSpinner v-if="building" small class="me-1" />
            <i v-else class="bi bi-hammer me-1" aria-hidden="true" />
            Build release
          </BButton>
        </form>
      </AdminOperationPanel>

      <AdminOperationPanel
        title="Releases"
        description="All releases, including drafts. Publishing and DOI recording never change a release's content digest."
        icon="bi-archive"
        heading-tag="h2"
        :aria-busy="loading ? 'true' : 'false'"
      >
        <BAlert v-if="admin.actionMessage.value" variant="info" show class="mb-3" data-testid="action-message">
          {{ admin.actionMessage.value }}
        </BAlert>

        <GenericTable :items="releaseRows" :fields="RELEASE_ADMIN_TABLE_FIELDS" :is-busy="loading">
          <template #cell-status="{ row }">
            <BBadge :variant="row.status === 'published' ? 'success' : 'secondary'">
              {{ row.status }}
            </BBadge>
          </template>
          <template #cell-actions="{ row, expansionShowing, toggleExpansion }">
            <div class="release-actions">
              <BButton
                v-if="row.status === 'draft'"
                size="sm"
                variant="outline-primary"
                :data-testid="`publish-${row.release_id}`"
                @click="admin.publish(row.release_id)"
              >
                Publish
              </BButton>
              <BButton
                size="sm"
                variant="outline-secondary"
                :data-testid="`toggle-doi-${row.release_id}`"
                @click="toggleExpansion?.()"
              >
                {{ expansionShowing ? 'Hide DOI form' : 'Record DOI' }}
              </BButton>
              <template v-if="row.status === 'draft'">
                <BButton
                  v-if="pendingDeleteId !== row.release_id"
                  size="sm"
                  variant="outline-danger"
                  :data-testid="`delete-${row.release_id}`"
                  @click="pendingDeleteId = row.release_id"
                >
                  Delete draft
                </BButton>
                <template v-else>
                  <BButton
                    size="sm"
                    variant="danger"
                    :data-testid="`confirm-delete-${row.release_id}`"
                    @click="handleConfirmDelete(row.release_id)"
                  >
                    Confirm delete
                  </BButton>
                  <BButton size="sm" variant="outline-secondary" @click="pendingDeleteId = null">
                    Cancel
                  </BButton>
                </template>
              </template>
            </div>
          </template>
          <template #row-expansion="{ row, toggle }">
            <div class="doi-form" :data-testid="`doi-form-${row.release_id}`">
              <div class="doi-form__grid">
                <div class="doi-form__field">
                  <label :for="`doi-version-${row.release_id}`" class="form-label fw-semibold">
                    Version DOI
                  </label>
                  <BFormInput
                    :id="`doi-version-${row.release_id}`"
                    v-model="doiFormFor(row.release_id).version_doi"
                    :data-testid="`doi-version-input-${row.release_id}`"
                  />
                </div>
                <div class="doi-form__field">
                  <label :for="`doi-concept-${row.release_id}`" class="form-label fw-semibold">
                    Concept DOI
                  </label>
                  <BFormInput
                    :id="`doi-concept-${row.release_id}`"
                    v-model="doiFormFor(row.release_id).concept_doi"
                  />
                </div>
                <div class="doi-form__field">
                  <label :for="`doi-zenodo-id-${row.release_id}`" class="form-label fw-semibold">
                    Zenodo record ID
                  </label>
                  <BFormInput
                    :id="`doi-zenodo-id-${row.release_id}`"
                    v-model="doiFormFor(row.release_id).zenodo_record_id"
                  />
                </div>
                <div class="doi-form__field">
                  <label :for="`doi-zenodo-url-${row.release_id}`" class="form-label fw-semibold">
                    Zenodo record URL
                  </label>
                  <BFormInput
                    :id="`doi-zenodo-url-${row.release_id}`"
                    v-model="doiFormFor(row.release_id).zenodo_record_url"
                  />
                </div>
              </div>
              <BButton
                size="sm"
                variant="primary"
                class="mt-2"
                :data-testid="`save-doi-${row.release_id}`"
                @click="handleSaveDoi(row.release_id, toggle)"
              >
                Save DOI
              </BButton>
            </div>
          </template>
        </GenericTable>

        <p v-if="!loading && admin.releases.value.length === 0" class="text-muted small mb-0 mt-2">
          No releases yet.
        </p>
      </AdminOperationPanel>
    </BContainer>
  </AuthenticatedPageShell>
</template>

<script setup lang="ts">
import { computed, onMounted, reactive, ref } from 'vue';
import { useHead } from '@unhead/vue';
import { BAlert, BBadge, BButton, BContainer, BFormInput, BFormTextarea, BSpinner } from 'bootstrap-vue-next';
import AuthenticatedPageShell from '@/components/layout/AuthenticatedPageShell.vue';
import AdminOperationPanel from '@/components/admin/AdminOperationPanel.vue';
import GenericTable from '@/components/small/GenericTable.vue';
import type { RecordReleaseDoiFields } from '@/api/admin_analysis_release';
import { useAnalysisReleaseAdmin, type BuildReleaseFormInput } from './useAnalysisReleaseAdmin';

useHead({ title: 'Manage analysis-snapshot releases' });

const RELEASE_ADMIN_TABLE_FIELDS = [
  { key: 'release_id', label: 'Release' },
  { key: 'status', label: 'Status' },
  { key: 'source_data_version', label: 'Source data version' },
  { key: 'created_at', label: 'Created' },
  { key: 'published_at', label: 'Published' },
  { key: 'file_count', label: 'Files' },
  { key: 'version_doi', label: 'Version DOI' },
  { key: 'actions', label: 'Actions' },
];

/**
 * Flat display row for the releases table. `GenericDesktopTable.vue` only
 * wires custom `#cell(<key>)` slots for a fixed, hardcoded set of field keys
 * (`status` and `actions` here, notably NOT `created_at`/`published_at`/
 * `version_doi`) — the same BVN gotcha `dataReleaseTable.ts` documents for
 * the public /DataReleases table. A `field.formatter` silently never runs
 * either, so display formatting (dates, the DOI dash sentinel) is baked
 * into the row here rather than attempted via a cell slot or formatter for
 * an unwired key.
 */
interface AdminReleaseTableRow {
  release_id: string;
  status: string;
  source_data_version: string;
  created_at: string;
  published_at: string;
  file_count: number;
  version_doi: string;
}

const admin = useAnalysisReleaseAdmin();
const { loading, building } = admin;

const releaseRows = computed<AdminReleaseTableRow[]>(() =>
  admin.releases.value.map((release) => ({
    release_id: release.release_id,
    status: release.status,
    source_data_version: release.source_data_version,
    created_at: formatDate(release.created_at),
    published_at: formatDate(release.published_at),
    file_count: release.file_count,
    version_doi: release.version_doi || '—',
  }))
);

const buildForm = reactive<BuildReleaseFormInput>({
  title: '',
  scope_statement: '',
  license: 'CC-BY-4.0',
  // Safe operator flow: build as a draft by default, review, then publish explicitly.
  publish: false,
});

const lockedOutcome = computed(() =>
  admin.lastBuildOutcome.value?.outcome === 'locked' ? admin.lastBuildOutcome.value : null
);
const createdOrExistingOutcome = computed(() => {
  const outcome = admin.lastBuildOutcome.value;
  return outcome && outcome.outcome !== 'locked' ? outcome : null;
});

/** Two-step "Delete draft" confirm state — an in-page affordance, never a native dialog. */
const pendingDeleteId = ref<string | null>(null);

/** Per-row DOI draft form values, lazily created and kept across expand/collapse. */
const doiForms = reactive<Record<string, RecordReleaseDoiFields>>({});
function doiFormFor(releaseId: string): RecordReleaseDoiFields {
  if (!doiForms[releaseId]) {
    doiForms[releaseId] = {
      version_doi: '',
      concept_doi: '',
      zenodo_record_id: '',
      zenodo_record_url: '',
    };
  }
  return doiForms[releaseId];
}

function formatDate(value: string | null | undefined): string {
  if (!value) return '—';
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? value : parsed.toLocaleString();
}

async function handleBuild(): Promise<void> {
  await admin.build({ ...buildForm });
}

async function handleConfirmDelete(releaseId: string): Promise<void> {
  await admin.deleteDraft(releaseId);
  pendingDeleteId.value = null;
}

async function handleSaveDoi(releaseId: string, toggle: () => void): Promise<void> {
  await admin.recordDoi(releaseId, { ...doiFormFor(releaseId) });
  if (!admin.actionError.value) {
    toggle();
  }
}

onMounted(() => {
  void admin.refreshAll();
});

defineExpose({ handleBuild, handleConfirmDelete, handleSaveDoi });
</script>

<style scoped>
.analysis-release-admin {
  padding: 0;
}

.layer-readiness-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 0.75rem;
}

.layer-readiness-item {
  display: flex;
  align-items: center;
  gap: 0.6rem;
  padding: 0.625rem 0.75rem;
  border: 1px solid rgba(198, 40, 40, 0.28);
  border-radius: var(--radius-md, 0.375rem);
  background: #fff5f5;
  color: var(--status-danger, #c62828);
}

.layer-readiness-item--ready {
  border-color: rgba(46, 125, 50, 0.28);
  background: #f3fbf4;
  color: var(--status-success, #2e7d32);
}

.layer-readiness-item strong {
  display: block;
  color: var(--neutral-900, #212121);
  font-size: 0.875rem;
}

.layer-readiness-state {
  display: block;
  font-size: 0.75rem;
  text-transform: capitalize;
}

.layer-readiness-hint {
  margin-top: 0.85rem;
  color: var(--neutral-600, #757575);
  font-size: 0.8125rem;
}

.layer-readiness-hint code {
  font-family: var(--font-family-mono, ui-monospace, SFMono-Regular, Menlo, monospace);
  font-size: 0.8em;
}

.build-form {
  display: grid;
  gap: 0.85rem;
  max-width: 32rem;
}

.build-form__field--checkbox {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.release-actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
  justify-content: flex-end;
}

.doi-form {
  padding: 0.75rem;
  border: 1px solid rgba(15, 23, 42, 0.08);
  border-radius: var(--radius-md, 0.375rem);
  background: #f8fafc;
}

.doi-form__grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 0.75rem;
}

@media (max-width: 767.98px) {
  .layer-readiness-grid {
    grid-template-columns: 1fr;
  }

  .doi-form__grid {
    grid-template-columns: 1fr;
  }
}
</style>
