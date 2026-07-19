import { mount, flushPromises } from '@vue/test-utils';
import { describe, expect, it, vi, beforeEach } from 'vitest';
import type { ReleaseDetail, ReleaseHead } from '@/api/analysis_releases';

vi.mock('@unhead/vue', () => ({
  useHead: vi.fn(),
}));

vi.mock('@/composables/useToast', () => ({
  default: () => ({ makeToast: vi.fn() }),
}));

const listReleasesMock = vi.fn();
const getLatestReleaseMock = vi.fn();
const getReleaseMock = vi.fn();
const downloadReleaseBundleMock = vi.fn();
const downloadReleaseManifestMock = vi.fn();
const downloadReleaseFileMock = vi.fn();

vi.mock('@/api/analysis', () => ({
  listReleases: (...args: unknown[]) => listReleasesMock(...args),
  getLatestRelease: (...args: unknown[]) => getLatestReleaseMock(...args),
  getRelease: (...args: unknown[]) => getReleaseMock(...args),
  downloadReleaseBundle: (...args: unknown[]) => downloadReleaseBundleMock(...args),
  downloadReleaseManifest: (...args: unknown[]) => downloadReleaseManifestMock(...args),
  downloadReleaseFile: (...args: unknown[]) => downloadReleaseFileMock(...args),
}));

import DataReleases from './DataReleases.vue';

function makeReleaseHead(overrides: Partial<ReleaseHead> = {}): ReleaseHead {
  return {
    release_id: 'asr_0123456789abcdef',
    release_version: null,
    title: 'SysNDD analysis-snapshot release',
    status: 'published',
    content_digest: 'a'.repeat(64),
    created_at: '2026-07-01T00:00:00Z',
    published_at: '2026-07-01T00:05:00Z',
    source_data_version: '2026-07-01',
    db_release_version: '11.4.0',
    db_release_commit: 'deadbeef',
    manifest_sha256: 'b'.repeat(64),
    bundle_sha256: 'c'.repeat(64),
    license: 'CC-BY-4.0',
    file_count: 1,
    total_bytes: 1258291,
    zenodo: { record_url: null, version_doi: null, concept_doi: null },
    ...overrides,
  };
}

function makeReleaseDetail(overrides: Partial<ReleaseHead> = {}): ReleaseDetail {
  return {
    ...makeReleaseHead(overrides),
    manifest: {
      release_id: 'asr_0123456789abcdef',
      release_version: null,
      title: 'SysNDD analysis-snapshot release',
      created_at: '2026-07-01T00:00:00Z',
      license: 'CC-BY-4.0',
      scope_statement: 'Public derived analysis only.',
      generator: 'sysndd-api',
      source: 'sysndd',
      layers: [
        {
          analysis_type: 'functional_clusters',
          parameter_hash: 'fp-hash',
          snapshot_id: 101,
          input_hash: 'in-func',
          payload_hash: 'pay-func',
          schema_version: '1.2',
          reproducibility_hash: 'repro-func',
          dependencies: null,
        },
      ],
      files: [{ path: 'functional_clusters/payload.json', sha256: 'd'.repeat(64), bytes: 100 }],
      content_digest: 'a'.repeat(64),
    },
  };
}

function notFoundError() {
  return Object.assign(new Error('Not found'), {
    isAxiosError: true,
    response: { status: 404, data: { message: 'No published analysis-snapshot release exists yet' } },
  });
}

describe('DataReleases', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    // jsdom has no real object-URL / anchor-download support.
    window.URL.createObjectURL = vi.fn(() => 'blob:mock-url');
    window.URL.revokeObjectURL = vi.fn();
  });

  it('renders the release table row and the manifest panel for the latest release', async () => {
    listReleasesMock.mockResolvedValue({
      releases: [makeReleaseHead()],
      pagination: { limit: 50, offset: 0, count: 1 },
    });
    getLatestReleaseMock.mockResolvedValue(makeReleaseDetail());

    const wrapper = mount(DataReleases);
    await flushPromises();

    expect(listReleasesMock).toHaveBeenCalled();
    expect(getLatestReleaseMock).toHaveBeenCalled();
    const text = wrapper.text();
    expect(text).toContain('asr_0123456789abcdef');
    expect(text).toContain('Integrity hashes');
    expect(text).toContain('a'.repeat(64));
  });

  it('re-fetches the detail for a different release when its "View manifest" button is clicked', async () => {
    listReleasesMock.mockResolvedValue({
      releases: [makeReleaseHead({ release_id: 'asr_other' })],
      pagination: { limit: 50, offset: 0, count: 1 },
    });
    getLatestReleaseMock.mockResolvedValue(makeReleaseDetail());
    getReleaseMock.mockResolvedValue(makeReleaseDetail({ release_id: 'asr_other' }));

    const wrapper = mount(DataReleases);
    await flushPromises();

    const button = wrapper
      .findAll('button')
      .find((btn) => btn.text().includes('View manifest'));
    expect(button).toBeTruthy();
    await button!.trigger('click');
    await flushPromises();

    expect(getReleaseMock).toHaveBeenCalledWith('asr_other');
  });

  it('downloads the bundle when the download-bundle button is clicked', async () => {
    listReleasesMock.mockResolvedValue({
      releases: [makeReleaseHead()],
      pagination: { limit: 50, offset: 0, count: 1 },
    });
    getLatestReleaseMock.mockResolvedValue(makeReleaseDetail());
    downloadReleaseBundleMock.mockResolvedValue(new Blob(['bundle-bytes']));

    const wrapper = mount(DataReleases);
    await flushPromises();

    await wrapper.find('[data-testid="download-bundle-button"]').trigger('click');
    await flushPromises();

    expect(downloadReleaseBundleMock).toHaveBeenCalledWith('asr_0123456789abcdef');
  });

  it('shows the "No releases published yet" empty state on a 404 from getLatestRelease, not a raw error', async () => {
    listReleasesMock.mockResolvedValue({
      releases: [],
      pagination: { limit: 50, offset: 0, count: 0 },
    });
    getLatestReleaseMock.mockRejectedValue(notFoundError());

    const wrapper = mount(DataReleases);
    await flushPromises();

    expect(wrapper.text()).toContain('No releases published yet');
    expect(wrapper.find('[data-testid="section-card-error"]').exists()).toBe(false);
  });
});
