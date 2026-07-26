import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import ReleaseDeskSummary from './ReleaseDeskSummary.vue';
import type { ReleaseDetail } from '@/api/analysis';

function makeRelease(): ReleaseDetail {
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
    file_count: 2,
    total_bytes: 1258291,
    zenodo: { record_url: null, version_doi: null, concept_doi: null },
    manifest: {
      release_id: 'asr_0123456789abcdef',
      release_version: null,
      title: 'SysNDD analysis-snapshot release',
      created_at: '2026-07-01T00:00:00Z',
      license: 'CC-BY-4.0',
      scope_statement: 'Public derived analysis only.',
      generator: {
        name: 'sysndd-analysis-snapshot-release-build',
        manifest_schema_version: '1.0',
        reproducibility_schema_version: '1.2',
      },
      source: {
        source_data_version: '2026-07-01',
        db_release: { version: '11.4.0', commit: 'deadbeef' },
        snapshots: [{ analysis_type: 'functional_clusters', snapshot_id: 101, parameter_hash: 'fp' }],
      },
      layers: [],
      files: [
        { path: 'functional_clusters/payload.json', sha256: 'd'.repeat(64), bytes: 100 },
        { path: 'README.md', sha256: 'e'.repeat(64), bytes: 25 },
      ],
      content_digest: 'a'.repeat(64),
    },
  };
}

describe('ReleaseDeskSummary', () => {
  it('puts the bundle action first and emits the exact requested download', async () => {
    const wrapper = mount(ReleaseDeskSummary, { props: { release: makeRelease() } });

    expect(wrapper.get('h2').text()).toContain('Latest published release');
    expect(wrapper.text()).toContain('asr_0123456789abcdef');
    expect(wrapper.text()).toContain('2 files');
    expect(wrapper.text()).toContain('1.2 MB');
    expect(wrapper.text()).toContain('CC-BY-4.0');

    await wrapper.get('[data-testid="download-bundle-button"]').trigger('click');
    await wrapper.get('[data-testid="download-manifest-button"]').trigger('click');
    await wrapper.get('[data-testid="download-file-functional_clusters-payload-json"]').trigger('click');

    expect(wrapper.emitted('download-bundle')).toHaveLength(1);
    expect(wrapper.emitted('download-manifest')).toHaveLength(1);
    expect(wrapper.emitted('download-file')).toEqual([['functional_clusters/payload.json']]);
  });
});
