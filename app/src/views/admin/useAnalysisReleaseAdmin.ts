// app/src/views/admin/useAnalysisReleaseAdmin.ts
//
// Co-located composable for the `ManageAnalysisReleases.vue` Administrator
// view (#573 Slice B, Task B4b). Owns every client call from the typed
// admin release client (`@/api/admin_analysis_release`, Task B4a) plus the
// reactive state the view renders, so the `.vue` stays a thin template.
// Mirrors the `./useNddScoreAdminDerivedRows` co-location convention.
//
// The build is SYNCHRONOUS and DB-only (no async job/worker involved) —
// `build()` is a single request/response round trip, not a job poll.

import { computed, ref, type ComputedRef, type Ref } from 'vue';
import {
  buildRelease,
  deleteDraftRelease,
  fetchSnapshotStatus,
  listAdminReleases,
  publishRelease,
  recordReleaseDoi,
  RELEASE_LAYER_TYPES,
  type AdminReleaseHead,
  type BuildReleaseRequest,
  type BuildReleaseResult,
  type RecordReleaseDoiFields,
  type SnapshotPresetState,
  type SnapshotStatusResponse,
} from '@/api/admin_analysis_release';
import { extractApiErrorMessage } from '@/utils/api-errors';

/** Human-readable label for each release layer, keyed by `analysis_type`. */
const RELEASE_LAYER_LABELS: Record<(typeof RELEASE_LAYER_TYPES)[number], string> = {
  functional_clusters: 'Functional clusters',
  phenotype_clusters: 'Phenotype clusters',
  phenotype_functional_correlations: 'Phenotype-functional correlation',
};

export interface LayerReadinessItem {
  analysis_type: (typeof RELEASE_LAYER_TYPES)[number];
  label: string;
  /** `'missing'` when the preset is absent from the status response entirely. */
  state: SnapshotPresetState['state'] | 'missing';
}

/** Build-form fields the view collects — the fixed default layer registry is always used. */
export type BuildReleaseFormInput = Omit<BuildReleaseRequest, 'layers'>;

export interface UseAnalysisReleaseAdmin {
  releases: Ref<AdminReleaseHead[]>;
  status: Ref<SnapshotStatusResponse | null>;
  loading: Ref<boolean>;
  buildError: Ref<string | null>;
  building: Ref<boolean>;
  lastBuildOutcome: Ref<BuildReleaseResult | null>;
  actionError: Ref<string | null>;
  actionMessage: Ref<string | null>;
  canBuild: ComputedRef<boolean>;
  layerReadiness: ComputedRef<LayerReadinessItem[]>;
  loadReleases: () => Promise<void>;
  loadStatus: () => Promise<void>;
  refreshAll: () => Promise<void>;
  build: (input: BuildReleaseFormInput) => Promise<void>;
  publish: (releaseId: string) => Promise<void>;
  recordDoi: (releaseId: string, fields: RecordReleaseDoiFields) => Promise<void>;
  deleteDraft: (releaseId: string) => Promise<void>;
}

/** Drops undefined/null/empty-string values so the client only receives filled DOI fields. */
function nonEmptyDoiFields(fields: RecordReleaseDoiFields): RecordReleaseDoiFields {
  const result: RecordReleaseDoiFields = {};
  (Object.keys(fields) as (keyof RecordReleaseDoiFields)[]).forEach((key) => {
    const value = fields[key];
    if (value !== undefined && value !== null && value !== '') {
      result[key] = value;
    }
  });
  return result;
}

export function useAnalysisReleaseAdmin(): UseAnalysisReleaseAdmin {
  const releases = ref<AdminReleaseHead[]>([]);
  const status = ref<SnapshotStatusResponse | null>(null);
  const loading = ref(false);
  const buildError = ref<string | null>(null);
  const building = ref(false);
  const lastBuildOutcome = ref<BuildReleaseResult | null>(null);
  const actionError = ref<string | null>(null);
  const actionMessage = ref<string | null>(null);

  const canBuild = computed<boolean>(() => {
    const current = status.value;
    if (!current) return false;
    return RELEASE_LAYER_TYPES.every(
      (type) => current.presets.find((preset) => preset.analysis_type === type)?.state === 'available'
    );
  });

  const layerReadiness = computed<LayerReadinessItem[]>(() =>
    RELEASE_LAYER_TYPES.map((type) => ({
      analysis_type: type,
      label: RELEASE_LAYER_LABELS[type],
      state: status.value?.presets.find((preset) => preset.analysis_type === type)?.state ?? 'missing',
    }))
  );

  async function loadReleases(): Promise<void> {
    try {
      const response = await listAdminReleases();
      releases.value = response.releases;
    } catch (err) {
      actionError.value = extractApiErrorMessage(
        err,
        'Failed to load analysis-snapshot releases.'
      );
    }
  }

  async function loadStatus(): Promise<void> {
    try {
      status.value = await fetchSnapshotStatus();
    } catch (err) {
      actionError.value = extractApiErrorMessage(
        err,
        'Failed to load snapshot readiness status.'
      );
    }
  }

  async function refreshAll(): Promise<void> {
    loading.value = true;
    try {
      await Promise.all([loadReleases(), loadStatus()]);
    } finally {
      loading.value = false;
    }
  }

  async function build(input: BuildReleaseFormInput): Promise<void> {
    buildError.value = null;
    lastBuildOutcome.value = null;
    building.value = true;
    try {
      const outcome = await buildRelease({ ...input, publish: input.publish ?? false });
      lastBuildOutcome.value = outcome;
      if (outcome.outcome === 'created' || outcome.outcome === 'exists') {
        await loadReleases();
      }
    } catch (err) {
      buildError.value = extractApiErrorMessage(
        err,
        'Failed to build the analysis-snapshot release.'
      );
    } finally {
      building.value = false;
    }
  }

  async function publish(releaseId: string): Promise<void> {
    actionError.value = null;
    actionMessage.value = null;
    try {
      const updated = await publishRelease(releaseId);
      actionMessage.value = `Release ${updated.release_id} published.`;
      await loadReleases();
    } catch (err) {
      actionError.value = extractApiErrorMessage(err, 'Failed to publish the release.');
    }
  }

  async function recordDoi(releaseId: string, fields: RecordReleaseDoiFields): Promise<void> {
    actionError.value = null;
    actionMessage.value = null;
    try {
      await recordReleaseDoi(releaseId, nonEmptyDoiFields(fields));
      actionMessage.value = 'DOI metadata recorded.';
      await loadReleases();
    } catch (err) {
      actionError.value = extractApiErrorMessage(err, 'Failed to record DOI metadata.');
    }
  }

  async function deleteDraft(releaseId: string): Promise<void> {
    actionError.value = null;
    actionMessage.value = null;
    try {
      await deleteDraftRelease(releaseId);
      actionMessage.value = 'Draft release deleted.';
      await loadReleases();
    } catch (err) {
      actionError.value = extractApiErrorMessage(err, 'Failed to delete the draft release.');
    }
  }

  return {
    releases,
    status,
    loading,
    buildError,
    building,
    lastBuildOutcome,
    actionError,
    actionMessage,
    canBuild,
    layerReadiness,
    loadReleases,
    loadStatus,
    refreshAll,
    build,
    publish,
    recordDoi,
    deleteDraft,
  };
}
