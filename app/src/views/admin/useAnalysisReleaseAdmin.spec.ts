// app/src/views/admin/useAnalysisReleaseAdmin.spec.ts
//
// Unit tests for the ManageAnalysisReleases composable (#573 Slice B, Task
// B4b). Mocks the typed admin client (Task B4a) entirely so these assert
// composable behavior only: the `canBuild` release-layer gate, the
// discriminated build outcome handling (created/exists/locked/400-throw),
// and that publish/recordDoi/deleteDraft forward the right arguments.

import { describe, expect, it, vi, beforeEach } from 'vitest';
import type {
  AdminReleaseHead,
  SnapshotStatusResponse,
} from '@/api/admin_analysis_release';

vi.mock('@/api/admin_analysis_release', async () => {
  const actual = await vi.importActual<typeof import('@/api/admin_analysis_release')>(
    '@/api/admin_analysis_release'
  );
  return {
    ...actual,
    buildRelease: vi.fn(),
    listAdminReleases: vi.fn(),
    getAdminRelease: vi.fn(),
    publishRelease: vi.fn(),
    recordReleaseDoi: vi.fn(),
    deleteDraftRelease: vi.fn(),
    fetchSnapshotStatus: vi.fn(),
  };
});

import {
  buildRelease,
  listAdminReleases,
  publishRelease,
  recordReleaseDoi,
  deleteDraftRelease,
  fetchSnapshotStatus,
} from '@/api/admin_analysis_release';
import { useAnalysisReleaseAdmin } from './useAnalysisReleaseAdmin';

function makeRelease(overrides: Partial<AdminReleaseHead> = {}): AdminReleaseHead {
  return {
    release_id: 'asr_abc123',
    release_version: null,
    title: 'Test release',
    status: 'draft',
    manifest_schema_version: '1.0',
    content_digest: 'a'.repeat(64),
    source_data_version: 'v1',
    db_release_version: null,
    db_release_commit: null,
    manifest_sha256: 'b'.repeat(64),
    bundle_sha256: 'c'.repeat(64),
    license: 'CC-BY-4.0',
    file_count: 5,
    total_bytes: 1024,
    created_by_user_id: 1,
    created_at: '2026-07-01T00:00:00Z',
    published_at: null,
    updated_at: '2026-07-01T00:00:00Z',
    zenodo_record_id: null,
    zenodo_record_url: null,
    version_doi: null,
    concept_doi: null,
    last_error_message: null,
    ...overrides,
  };
}

function makeStatus(states: Record<string, string>): SnapshotStatusResponse {
  return {
    presets: Object.entries(states).map(([analysis_type, state]) => ({
      analysis_type,
      parameter_hash: 'hash',
      state: state as SnapshotStatusResponse['presets'][number]['state'],
      generated_at: null,
      activated_at: null,
      stale_after: null,
      source_data_version: null,
      row_counts: null,
    })),
    summary: { total: 0, available: 0, missing: 0, stale: 0, mismatch: 0 },
  };
}

const ALL_AVAILABLE = makeStatus({
  functional_clusters: 'available',
  phenotype_clusters: 'available',
  phenotype_functional_correlations: 'available',
  phenotype_correlations: 'missing',
  gene_network_edges: 'missing',
});

describe('useAnalysisReleaseAdmin', () => {
  beforeEach(() => {
    vi.clearAllMocks();
  });

  describe('canBuild', () => {
    it('is false while status has not loaded', () => {
      const admin = useAnalysisReleaseAdmin();
      expect(admin.canBuild.value).toBe(false);
    });

    it('is false when a release layer is not available', async () => {
      (fetchSnapshotStatus as ReturnType<typeof vi.fn>).mockResolvedValue(
        makeStatus({
          functional_clusters: 'available',
          phenotype_clusters: 'stale',
          phenotype_functional_correlations: 'available',
        })
      );
      const admin = useAnalysisReleaseAdmin();
      await admin.loadStatus();
      expect(admin.canBuild.value).toBe(false);
    });

    it('is true when all three release layers are available, ignoring non-release presets', async () => {
      (fetchSnapshotStatus as ReturnType<typeof vi.fn>).mockResolvedValue(ALL_AVAILABLE);
      const admin = useAnalysisReleaseAdmin();
      await admin.loadStatus();
      expect(admin.canBuild.value).toBe(true);
    });

    it('is false when a release layer preset is entirely absent from the response', async () => {
      (fetchSnapshotStatus as ReturnType<typeof vi.fn>).mockResolvedValue(
        makeStatus({
          functional_clusters: 'available',
          phenotype_clusters: 'available',
        })
      );
      const admin = useAnalysisReleaseAdmin();
      await admin.loadStatus();
      expect(admin.canBuild.value).toBe(false);
    });
  });

  describe('layerReadiness', () => {
    it('reports the three release-layer states, "missing" when absent', async () => {
      (fetchSnapshotStatus as ReturnType<typeof vi.fn>).mockResolvedValue(
        makeStatus({ functional_clusters: 'available' })
      );
      const admin = useAnalysisReleaseAdmin();
      await admin.loadStatus();
      const byType = Object.fromEntries(
        admin.layerReadiness.value.map((item) => [item.analysis_type, item.state])
      );
      expect(byType.functional_clusters).toBe('available');
      expect(byType.phenotype_clusters).toBe('missing');
      expect(byType.phenotype_functional_correlations).toBe('missing');
    });
  });

  describe('build', () => {
    it('sets lastBuildOutcome and reloads releases on a created outcome', async () => {
      const release = makeRelease({ status: 'draft' });
      (buildRelease as ReturnType<typeof vi.fn>).mockResolvedValue({
        outcome: 'created',
        release,
      });
      (listAdminReleases as ReturnType<typeof vi.fn>).mockResolvedValue({
        releases: [release],
        pagination: { limit: 50, offset: 0, count: 1 },
      });

      const admin = useAnalysisReleaseAdmin();
      await admin.build({ title: 'My release', publish: false });

      expect(admin.lastBuildOutcome.value).toEqual({ outcome: 'created', release });
      expect(admin.buildError.value).toBeNull();
      expect(listAdminReleases).toHaveBeenCalledTimes(1);
      expect(admin.releases.value).toEqual([release]);
    });

    it('reloads releases on an exists outcome too', async () => {
      const release = makeRelease({ status: 'published' });
      (buildRelease as ReturnType<typeof vi.fn>).mockResolvedValue({
        outcome: 'exists',
        release,
      });
      (listAdminReleases as ReturnType<typeof vi.fn>).mockResolvedValue({
        releases: [release],
        pagination: { limit: 50, offset: 0, count: 1 },
      });

      const admin = useAnalysisReleaseAdmin();
      await admin.build({});

      expect(admin.lastBuildOutcome.value?.outcome).toBe('exists');
      expect(listAdminReleases).toHaveBeenCalledTimes(1);
    });

    it('sets a locked outcome with retryAfter and does NOT set buildError or reload', async () => {
      (buildRelease as ReturnType<typeof vi.fn>).mockResolvedValue({
        outcome: 'locked',
        retryAfter: 7,
        message: 'Snapshot sources are refreshing.',
      });

      const admin = useAnalysisReleaseAdmin();
      await admin.build({});

      expect(admin.lastBuildOutcome.value).toEqual({
        outcome: 'locked',
        retryAfter: 7,
        message: 'Snapshot sources are refreshing.',
      });
      expect(admin.buildError.value).toBeNull();
      expect(listAdminReleases).not.toHaveBeenCalled();
    });

    it('sets buildError to the extracted message on a thrown 400 gate failure', async () => {
      (buildRelease as ReturnType<typeof vi.fn>).mockRejectedValue({
        response: { data: { detail: 'release_snapshot_not_available: functional_clusters' } },
      });

      const admin = useAnalysisReleaseAdmin();
      await admin.build({});

      expect(admin.buildError.value).toBe(
        'release_snapshot_not_available: functional_clusters'
      );
      expect(admin.lastBuildOutcome.value).toBeNull();
    });

    it('clears a prior buildError when a new build call starts', async () => {
      (buildRelease as ReturnType<typeof vi.fn>).mockRejectedValueOnce({
        response: { data: { detail: 'first failure' } },
      });
      const admin = useAnalysisReleaseAdmin();
      await admin.build({});
      expect(admin.buildError.value).toBe('first failure');

      const release = makeRelease();
      (buildRelease as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
        outcome: 'created',
        release,
      });
      (listAdminReleases as ReturnType<typeof vi.fn>).mockResolvedValue({
        releases: [release],
        pagination: { limit: 50, offset: 0, count: 1 },
      });
      await admin.build({});
      expect(admin.buildError.value).toBeNull();
    });
  });

  describe('publish / recordDoi / deleteDraft', () => {
    it('publish calls publishRelease with the release id and reloads', async () => {
      const release = makeRelease({ status: 'published' });
      (publishRelease as ReturnType<typeof vi.fn>).mockResolvedValue(release);
      (listAdminReleases as ReturnType<typeof vi.fn>).mockResolvedValue({
        releases: [release],
        pagination: { limit: 50, offset: 0, count: 1 },
      });

      const admin = useAnalysisReleaseAdmin();
      await admin.publish('asr_abc123');

      expect(publishRelease).toHaveBeenCalledWith('asr_abc123');
      expect(listAdminReleases).toHaveBeenCalledTimes(1);
    });

    it('publish surfaces the extracted error message on failure', async () => {
      (publishRelease as ReturnType<typeof vi.fn>).mockRejectedValue({
        response: { data: { detail: 'release not found' } },
      });
      const admin = useAnalysisReleaseAdmin();
      await admin.publish('asr_missing');
      expect(admin.actionError.value).toBe('release not found');
    });

    it('recordDoi calls recordReleaseDoi with only the filled fields', async () => {
      const release = makeRelease({ version_doi: '10.5281/zenodo.1' });
      (recordReleaseDoi as ReturnType<typeof vi.fn>).mockResolvedValue(release);
      (listAdminReleases as ReturnType<typeof vi.fn>).mockResolvedValue({
        releases: [release],
        pagination: { limit: 50, offset: 0, count: 1 },
      });

      const admin = useAnalysisReleaseAdmin();
      await admin.recordDoi('asr_abc123', {
        version_doi: '10.5281/zenodo.1',
        concept_doi: '',
        zenodo_record_id: undefined,
        zenodo_record_url: '',
      });

      expect(recordReleaseDoi).toHaveBeenCalledWith('asr_abc123', {
        version_doi: '10.5281/zenodo.1',
      });
    });

    it('deleteDraft calls deleteDraftRelease with the release id and reloads', async () => {
      (deleteDraftRelease as ReturnType<typeof vi.fn>).mockResolvedValue(undefined);
      (listAdminReleases as ReturnType<typeof vi.fn>).mockResolvedValue({
        releases: [],
        pagination: { limit: 50, offset: 0, count: 0 },
      });

      const admin = useAnalysisReleaseAdmin();
      await admin.deleteDraft('asr_draft1');

      expect(deleteDraftRelease).toHaveBeenCalledWith('asr_draft1');
      expect(listAdminReleases).toHaveBeenCalledTimes(1);
    });
  });

  describe('refreshAll', () => {
    it('loads both releases and status, toggling loading', async () => {
      (listAdminReleases as ReturnType<typeof vi.fn>).mockResolvedValue({
        releases: [makeRelease()],
        pagination: { limit: 50, offset: 0, count: 1 },
      });
      (fetchSnapshotStatus as ReturnType<typeof vi.fn>).mockResolvedValue(ALL_AVAILABLE);

      const admin = useAnalysisReleaseAdmin();
      expect(admin.loading.value).toBe(false);
      const promise = admin.refreshAll();
      expect(admin.loading.value).toBe(true);
      await promise;
      expect(admin.loading.value).toBe(false);
      expect(admin.releases.value).toHaveLength(1);
      expect(admin.canBuild.value).toBe(true);
    });
  });
});
