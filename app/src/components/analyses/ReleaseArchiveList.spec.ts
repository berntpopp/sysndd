import { mount } from '@vue/test-utils';
import { describe, expect, it } from 'vitest';
import ReleaseArchiveList from './ReleaseArchiveList.vue';
import type { ReleaseTableRow } from './dataReleaseTable';

const releases: ReleaseTableRow[] = [
  {
    release_id: 'asr_newest',
    title: 'Newest analysis release',
    status: 'published',
    published_at: '2026-07-26T09:00:00Z',
    source_data_version: 'source-a',
    file_count: 8,
    total_bytes: 3145728,
    total_bytes_display: '3 MB',
    license: 'CC-BY-4.0',
    zenodo_version_doi: '—',
    zenodo_concept_doi: '—',
    zenodo_record_url: '—',
  },
  {
    release_id: 'asr_previous',
    title: 'Previous analysis release',
    status: 'published',
    published_at: '2026-06-30T09:00:00Z',
    source_data_version: 'source-b',
    file_count: 6,
    total_bytes: 1048576,
    total_bytes_display: '1 MB',
    license: 'CC-BY-4.0',
    zenodo_version_doi: '—',
    zenodo_concept_doi: '—',
    zenodo_record_url: '—',
  },
];

describe('ReleaseArchiveList', () => {
  it('marks the chosen release current and emits the selected release id', async () => {
    const wrapper = mount(ReleaseArchiveList, {
      props: { releases, selectedReleaseId: 'asr_newest' },
    });

    const current = wrapper.get('button[aria-current="true"]');
    expect(current.text()).toContain('asr_newest');
    expect(current.text()).toContain('8 files');
    expect(current.text()).not.toContain('source-a');

    await wrapper.get('button[aria-label="Select release asr_previous"]').trigger('click');
    expect(wrapper.emitted('select')).toEqual([['asr_previous']]);
  });
});
