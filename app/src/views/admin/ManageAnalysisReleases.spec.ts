// app/src/views/admin/ManageAnalysisReleases.spec.ts
//
// Component tests for the Administrator analysis-snapshot-release page
// (#573 Slice B, Task B4b). Mocks the typed admin client
// (`@/api/admin_analysis_release`) directly so these exercise the real
// composable + view wiring end-to-end (mirrors DataReleases.spec.ts).
//
// `GenericTable` is stubbed with a tiny hand-rolled template that forwards
// the same slot names/props the real `GenericDesktopTable`/BTable wiring
// exposes (`cell-status`, `cell-actions` with `expansion-showing`/
// `toggle-expansion`, `row-expansion` with `toggle`) — the same technique
// `ApprovalTableView.spec.ts`/`PubtatorNDDGenes.spec.ts` use to test
// row-expansion consumers deterministically without depending on
// BootstrapVueNext's internal BTable expansion implementation.

import { mount, flushPromises } from '@vue/test-utils';
import { defineComponent } from 'vue';
import { describe, expect, it, vi, beforeEach } from 'vitest';
import type { AdminReleaseHead, SnapshotStatusResponse } from '@/api/admin_analysis_release';

vi.mock('@unhead/vue', () => ({
  useHead: vi.fn(),
}));

const buildReleaseMock = vi.fn();
const listAdminReleasesMock = vi.fn();
const publishReleaseMock = vi.fn();
const recordReleaseDoiMock = vi.fn();
const deleteDraftReleaseMock = vi.fn();
const fetchSnapshotStatusMock = vi.fn();

vi.mock('@/api/admin_analysis_release', async () => {
  const actual = await vi.importActual<typeof import('@/api/admin_analysis_release')>(
    '@/api/admin_analysis_release'
  );
  return {
    ...actual,
    buildRelease: (...args: unknown[]) => buildReleaseMock(...args),
    listAdminReleases: (...args: unknown[]) => listAdminReleasesMock(...args),
    getAdminRelease: vi.fn(),
    publishRelease: (...args: unknown[]) => publishReleaseMock(...args),
    recordReleaseDoi: (...args: unknown[]) => recordReleaseDoiMock(...args),
    deleteDraftRelease: (...args: unknown[]) => deleteDraftReleaseMock(...args),
    fetchSnapshotStatus: (...args: unknown[]) => fetchSnapshotStatusMock(...args),
  };
});

import ManageAnalysisReleases from './ManageAnalysisReleases.vue';

const GenericTableStub = defineComponent({
  props: ['items', 'fields', 'isBusy'],
  data() {
    return { expanded: {} as Record<string, boolean> };
  },
  methods: {
    toggleRow(id: string) {
      this.expanded[id] = !this.expanded[id];
    },
  },
  template: `
    <div data-testid="generic-table-stub">
      <div v-for="item in items" :key="item.release_id" class="stub-row">
        <span>{{ item.release_id }}</span>
        <slot name="cell-status" :row="item" />
        <slot
          name="cell-actions"
          :row="item"
          :expansion-showing="!!expanded[item.release_id]"
          :toggle-expansion="() => toggleRow(item.release_id)"
        />
        <div v-if="expanded[item.release_id]">
          <slot name="row-expansion" :row="item" :toggle="() => toggleRow(item.release_id)" />
        </div>
      </div>
    </div>
  `,
});

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
});

function mountView() {
  return mount(ManageAnalysisReleases, {
    global: {
      stubs: { AdminOperationPanel: false, GenericTable: GenericTableStub },
    },
  });
}

describe('ManageAnalysisReleases.vue', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    listAdminReleasesMock.mockResolvedValue({
      releases: [],
      pagination: { limit: 50, offset: 0, count: 0 },
    });
    fetchSnapshotStatusMock.mockResolvedValue(
      makeStatus({
        functional_clusters: 'missing',
        phenotype_clusters: 'missing',
        phenotype_functional_correlations: 'missing',
      })
    );
  });

  it('disables the Build button when a release layer is not available', async () => {
    const wrapper = mountView();
    await flushPromises();

    const button = wrapper.find('[data-testid="build-release-btn"]');
    expect(button.exists()).toBe(true);
    expect(button.attributes('disabled')).toBeDefined();
  });

  it('enables the Build button and invokes buildRelease when all three release layers are available', async () => {
    fetchSnapshotStatusMock.mockResolvedValue(ALL_AVAILABLE);
    const release = makeRelease({ status: 'draft' });
    buildReleaseMock.mockResolvedValue({ outcome: 'created', release });

    const wrapper = mountView();
    await flushPromises();

    const button = wrapper.find('[data-testid="build-release-btn"]');
    expect(button.attributes('disabled')).toBeUndefined();

    await wrapper.find('form.build-form').trigger('submit');
    await flushPromises();

    expect(buildReleaseMock).toHaveBeenCalledTimes(1);
    expect(wrapper.find('[data-testid="build-success"]').exists()).toBe(true);
  });

  it('shows a distinct retry warning (not a gate error) when the build is locked', async () => {
    fetchSnapshotStatusMock.mockResolvedValue(ALL_AVAILABLE);
    buildReleaseMock.mockResolvedValue({
      outcome: 'locked',
      retryAfter: 9,
      message: 'Snapshot sources are refreshing.',
    });

    const wrapper = mountView();
    await flushPromises();

    await wrapper.find('form.build-form').trigger('submit');
    await flushPromises();

    const locked = wrapper.find('[data-testid="build-locked"]');
    expect(locked.exists()).toBe(true);
    expect(locked.text()).toContain('retry in 9s');
    expect(wrapper.find('[data-testid="build-error"]').exists()).toBe(false);
  });

  it('sets the build error alert (not the locked warning) on a thrown 400 gate failure', async () => {
    fetchSnapshotStatusMock.mockResolvedValue(ALL_AVAILABLE);
    buildReleaseMock.mockRejectedValue({
      response: { data: { detail: 'release_snapshot_not_available: functional_clusters' } },
    });

    const wrapper = mountView();
    await flushPromises();

    await wrapper.find('form.build-form').trigger('submit');
    await flushPromises();

    const errorAlert = wrapper.find('[data-testid="build-error"]');
    expect(errorAlert.exists()).toBe(true);
    expect(errorAlert.text()).toContain('release_snapshot_not_available');
    expect(wrapper.find('[data-testid="build-locked"]').exists()).toBe(false);
  });

  it('renders a mocked draft row with a Publish action that calls publishRelease', async () => {
    const release = makeRelease({ release_id: 'asr_draft1', status: 'draft' });
    listAdminReleasesMock.mockResolvedValue({
      releases: [release],
      pagination: { limit: 50, offset: 0, count: 1 },
    });
    publishReleaseMock.mockResolvedValue({ ...release, status: 'published' });

    const wrapper = mountView();
    await flushPromises();

    expect(wrapper.text()).toContain('asr_draft1');
    const publishBtn = wrapper.find('[data-testid="publish-asr_draft1"]');
    expect(publishBtn.exists()).toBe(true);

    await publishBtn.trigger('click');
    await flushPromises();

    expect(publishReleaseMock).toHaveBeenCalledWith('asr_draft1');
  });

  it('does not render a Publish action for an already-published release', async () => {
    const release = makeRelease({ release_id: 'asr_pub1', status: 'published' });
    listAdminReleasesMock.mockResolvedValue({
      releases: [release],
      pagination: { limit: 50, offset: 0, count: 1 },
    });

    const wrapper = mountView();
    await flushPromises();

    expect(wrapper.find('[data-testid="publish-asr_pub1"]').exists()).toBe(false);
  });

  it('the Record-DOI control calls recordReleaseDoi with only the filled fields', async () => {
    const release = makeRelease({ release_id: 'asr_doi1', status: 'published' });
    listAdminReleasesMock.mockResolvedValue({
      releases: [release],
      pagination: { limit: 50, offset: 0, count: 1 },
    });
    recordReleaseDoiMock.mockResolvedValue({ ...release, version_doi: '10.5281/zenodo.99' });

    const wrapper = mountView();
    await flushPromises();

    await wrapper.find('[data-testid="toggle-doi-asr_doi1"]').trigger('click');
    await flushPromises();

    const versionInput = wrapper.find('[data-testid="doi-version-input-asr_doi1"]');
    expect(versionInput.exists()).toBe(true);
    await versionInput.setValue('10.5281/zenodo.99');

    await wrapper.find('[data-testid="save-doi-asr_doi1"]').trigger('click');
    await flushPromises();

    expect(recordReleaseDoiMock).toHaveBeenCalledWith('asr_doi1', {
      version_doi: '10.5281/zenodo.99',
    });
  });

  it('surfaces a failed Publish action error co-located in the Releases panel, not the readiness panel', async () => {
    const release = makeRelease({ release_id: 'asr_fail1', status: 'draft' });
    listAdminReleasesMock.mockResolvedValue({
      releases: [release],
      pagination: { limit: 50, offset: 0, count: 1 },
    });
    publishReleaseMock.mockRejectedValue({
      response: { data: { detail: 'release not found' } },
    });

    const wrapper = mountView();
    await flushPromises();

    await wrapper.find('[data-testid="publish-asr_fail1"]').trigger('click');
    await flushPromises();

    const panels = wrapper.findAll('[data-testid="admin-operation-panel"]');
    expect(panels).toHaveLength(3);
    const [readinessPanel, , releasesPanel] = panels;

    const errorInReleasesPanel = releasesPanel.find('[data-testid="action-error"]');
    expect(errorInReleasesPanel.exists()).toBe(true);
    expect(errorInReleasesPanel.text()).toContain('release not found');

    // The regression this guards: actionError used to render in the
    // Snapshot-readiness panel, far from the row action that triggered it.
    expect(readinessPanel.find('[data-testid="action-error"]').exists()).toBe(false);
  });

  it('deletes a draft only after the two-step in-page confirm, never via a blocking dialog', async () => {
    const confirmSpy = vi.spyOn(window, 'confirm');
    const release = makeRelease({ release_id: 'asr_draft2', status: 'draft' });
    listAdminReleasesMock.mockResolvedValue({
      releases: [release],
      pagination: { limit: 50, offset: 0, count: 1 },
    });
    deleteDraftReleaseMock.mockResolvedValue(undefined);

    const wrapper = mountView();
    await flushPromises();

    expect(wrapper.find('[data-testid="confirm-delete-asr_draft2"]').exists()).toBe(false);

    await wrapper.find('[data-testid="delete-asr_draft2"]').trigger('click');
    await flushPromises();

    expect(deleteDraftReleaseMock).not.toHaveBeenCalled();
    expect(confirmSpy).not.toHaveBeenCalled();

    await wrapper.find('[data-testid="confirm-delete-asr_draft2"]').trigger('click');
    await flushPromises();

    expect(deleteDraftReleaseMock).toHaveBeenCalledWith('asr_draft2');
    expect(confirmSpy).not.toHaveBeenCalled();
  });
});
