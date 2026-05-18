import { mount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';
import NDDScore from './NDDScore.vue';

vi.mock('@/api/nddscore', () => ({
  fetchCurrentRelease: vi.fn().mockResolvedValue({
    release_id: 'nddscore_20260517_public',
    version_doi: '10.5281/zenodo.20258027',
    ndd_performance_json: JSON.stringify({ test: { auc_roc: 0.8877, bss: 0.4438 } }),
  }),
}));

describe('NDDScore.vue', () => {
  it('renders the ML-vs-curated separation subtitle and prediction card', async () => {
    const wrapper = mount(NDDScore, {
      global: {
        stubs: { RouterView: true, AnalysisShell: false, RouterLink: true },
      },
    });
    await new Promise((r) => setTimeout(r, 0));
    const text = wrapper.text();
    expect(text).toContain('separate from curated SysNDD evidence');
    expect(wrapper.findComponent({ name: 'NddScorePredictionCard' }).exists()).toBe(true);
  });
});
