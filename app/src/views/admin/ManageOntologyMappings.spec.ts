import { mount, flushPromises } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';
import ManageOntologyMappings from './ManageOntologyMappings.vue';

vi.mock('@/api/ontology_mapping_admin', () => ({
  fetchOntologyMappingStatus: vi.fn().mockResolvedValue({
    latest: {
      id: 12,
      mondo_release_version: '2026-06-02',
      status: 'success',
      mondo_term_count: 33766,
      mondo_xref_count: 121791,
      mapping_count: 40645,
      disease_covered_count: 6766,
      build_started_at: '2026-06-20 18:00:00',
      build_finished_at: '2026-06-20 18:00:42',
      build_duration_s: 42.1,
    },
    history: [
      {
        id: 12,
        mondo_release_version: '2026-06-02',
        status: 'success',
        mondo_term_count: 33766,
        mondo_xref_count: 121791,
        mapping_count: 40645,
        disease_covered_count: 6766,
        build_started_at: '2026-06-20 18:00:00',
        build_finished_at: '2026-06-20 18:00:42',
        build_duration_s: 42.1,
      },
    ],
    build_exists: true,
  }),
  submitOntologyMappingRefresh: vi.fn().mockResolvedValue({
    submitted: true,
    duplicate: false,
    skipped: false,
    job_id: 'job-ont-1',
    message: 'Mapping refresh job submitted.',
  }),
}));

describe('ManageOntologyMappings.vue', () => {
  it('renders the latest build status with release version and mapping count', async () => {
    const wrapper = mount(ManageOntologyMappings, {
      global: { stubs: { AdminOperationPanel: false } },
    });
    await flushPromises();
    expect(wrapper.text()).toContain('2026-06-02');
    expect(wrapper.find('[data-testid="ont-mapping-count"]').text()).toContain('40,645');
    expect(wrapper.find('[data-testid="ontology-mapping-refresh-btn"]').exists()).toBe(true);
  });

  it('renders the cold-start warning when build_exists is false', async () => {
    const { fetchOntologyMappingStatus } = await import('@/api/ontology_mapping_admin');
    (fetchOntologyMappingStatus as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
      latest: null,
      history: [],
      build_exists: false,
    });
    const wrapper = mount(ManageOntologyMappings, {
      global: { stubs: { AdminOperationPanel: false } },
    });
    await flushPromises();
    expect(wrapper.find('[data-testid="ont-cold-start-warning"]').exists()).toBe(true);
    expect(wrapper.text()).toContain('No disease ontology mappings have been built yet');
  });

  it('calls submitOntologyMappingRefresh(true) when the Refresh now button is clicked', async () => {
    const wrapper = mount(ManageOntologyMappings, {
      global: { stubs: { AdminOperationPanel: false } },
    });
    await flushPromises();
    await wrapper.find('[data-testid="ontology-mapping-refresh-btn"]').trigger('click');
    await flushPromises();
    const { submitOntologyMappingRefresh } = await import('@/api/ontology_mapping_admin');
    expect(submitOntologyMappingRefresh).toHaveBeenCalledWith(true);
  });

  it('starts job polling and shows the job_id and message on submitted result', async () => {
    const wrapper = mount(ManageOntologyMappings, {
      global: { stubs: { AdminOperationPanel: false } },
    });
    await flushPromises();
    await wrapper.find('[data-testid="ontology-mapping-refresh-btn"]').trigger('click');
    await flushPromises();
    expect(wrapper.text()).toContain('Mapping refresh job submitted.');
    expect(wrapper.find('[data-testid="ont-active-job"]').exists()).toBe(true);
    expect(wrapper.find('[data-testid="ont-active-job"]').text()).toContain('job-ont-1');
  });

  it('shows "already running" message and polls the reused job_id on duplicate result', async () => {
    const { submitOntologyMappingRefresh } = await import('@/api/ontology_mapping_admin');
    (submitOntologyMappingRefresh as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
      submitted: false,
      duplicate: true,
      skipped: false,
      job_id: 'job-ont-existing',
      message: 'Duplicate job.',
    });
    const wrapper = mount(ManageOntologyMappings, {
      global: { stubs: { AdminOperationPanel: false } },
    });
    await flushPromises();
    await wrapper.find('[data-testid="ontology-mapping-refresh-btn"]').trigger('click');
    await flushPromises();
    expect(wrapper.text()).toContain('A mapping refresh is already running.');
    expect(wrapper.find('[data-testid="ont-active-job"]').exists()).toBe(true);
    expect(wrapper.find('[data-testid="ont-active-job"]').text()).toContain('job-ont-existing');
  });

  it('surfaces the extracted API error message on submit failure', async () => {
    const { submitOntologyMappingRefresh } = await import('@/api/ontology_mapping_admin');
    (submitOntologyMappingRefresh as ReturnType<typeof vi.fn>).mockRejectedValueOnce({
      response: { data: { detail: 'MONDO release not available' } },
    });
    const wrapper = mount(ManageOntologyMappings, {
      global: { stubs: { AdminOperationPanel: false } },
    });
    await flushPromises();
    await wrapper.find('[data-testid="ontology-mapping-refresh-btn"]').trigger('click');
    await flushPromises();
    expect(wrapper.text()).toContain('MONDO release not available');
    expect(wrapper.text()).not.toContain('Failed to submit disease ontology mapping refresh.');
  });
});
