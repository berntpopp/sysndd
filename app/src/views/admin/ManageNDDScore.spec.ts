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
});
