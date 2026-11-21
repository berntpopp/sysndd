import { mount, flushPromises } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';
import ManageNDDScore from './ManageNDDScore.vue';

vi.mock('@/api/nddscore_admin', () => ({
  fetchNddScoreStatus: vi.fn().mockResolvedValue({
    active_release: { release_id: 'nddscore_20260517_public', import_status: 'active' },
    recent_jobs: [],
  }),
  fetchNddScoreZenodo: vi.fn(),
  submitNddScoreImport: vi.fn().mockResolvedValue({ jobId: 'job-1', status: 'accepted' }),
}));

describe('ManageNDDScore.vue', () => {
  it('renders the active release and an import confirmation gate', async () => {
    const wrapper = mount(ManageNDDScore, {
      global: { stubs: { AdminOperationPanel: false, BModal: true } },
    });
    await flushPromises();
    expect(wrapper.text()).toContain('nddscore_20260517_public');
    const importBtn = wrapper.find('[data-testid="ndd-import-btn"]');
    expect(importBtn.exists()).toBe(true);
    const { submitNddScoreImport } = await import('@/api/nddscore_admin');
    expect(submitNddScoreImport).not.toHaveBeenCalled();
  });

  it('renders the release layout as a skeleton while the first status loads (no spinner swap)', async () => {
    const api = await import('@/api/nddscore_admin');
    let resolve: (v: unknown) => void = () => {};
    vi.mocked(api.fetchNddScoreStatus).mockReturnValueOnce(
      new Promise((r) => (resolve = r)) as ReturnType<typeof api.fetchNddScoreStatus>
    );
    const wrapper = mount(ManageNDDScore, {
      global: { stubs: { AdminOperationPanel: false, BModal: true } },
    });
    await flushPromises();
    const skeleton = wrapper.find('.ndd-release--loading');
    expect(skeleton.exists()).toBe(true);
    expect(skeleton.findAll('.ndd-kpi')).toHaveLength(3);
    expect(wrapper.text()).not.toContain('Loading NDDScore status...');

    resolve({
      active_release: {
        release_id: 'nddscore_20260517_public',
        import_status: 'active',
        ndd_performance_json: '{"val": {"auc_roc": 0.903366886497744}}',
      },
      recent_jobs: [],
    });
    await flushPromises();
    expect(wrapper.find('.ndd-release--loading').exists()).toBe(false);
    expect(wrapper.text()).toContain('AUC ROC 0.903');
    expect(wrapper.text()).not.toContain('{"');
  });

  it('submits the import job only after confirmation', async () => {
    const wrapper = mount(ManageNDDScore, {
      global: { stubs: { AdminOperationPanel: false } },
    });
    await flushPromises();
    await wrapper.find('[data-testid="ndd-import-btn"]').trigger('click');
    await (wrapper.vm as unknown as { confirmImport: () => Promise<void> }).confirmImport();
    await flushPromises();
    const { submitNddScoreImport } = await import('@/api/nddscore_admin');
    expect(submitNddScoreImport).toHaveBeenCalledWith({ validateOnly: false });
  });

  it('shows a distinct message when an import is already running (409)', async () => {
    const { submitNddScoreImport } = await import('@/api/nddscore_admin');
    (submitNddScoreImport as ReturnType<typeof vi.fn>).mockResolvedValueOnce({
      jobId: 'job-existing',
      status: 'already_running',
    });
    const wrapper = mount(ManageNDDScore, {
      global: { stubs: { AdminOperationPanel: false } },
    });
    await flushPromises();
    await (wrapper.vm as unknown as { confirmImport: () => Promise<void> }).confirmImport();
    await flushPromises();
    expect(wrapper.text()).toContain('An import is already running.');
    expect(wrapper.text()).not.toContain('Import and activation job submitted.');
  });

  it('surfaces the extracted API error message on submit failure', async () => {
    const { submitNddScoreImport } = await import('@/api/nddscore_admin');
    (submitNddScoreImport as ReturnType<typeof vi.fn>).mockRejectedValueOnce({
      response: { data: { detail: 'Zenodo archive checksum mismatch' } },
    });
    const wrapper = mount(ManageNDDScore, {
      global: { stubs: { AdminOperationPanel: false } },
    });
    await flushPromises();
    await (wrapper.vm as unknown as { confirmImport: () => Promise<void> }).confirmImport();
    await flushPromises();
    expect(wrapper.text()).toContain('Zenodo archive checksum mismatch');
    expect(wrapper.text()).not.toContain('Failed to submit import job.');
  });
});
