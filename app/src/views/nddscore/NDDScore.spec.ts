import { mount } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';

const route = vi.hoisted(() => ({ name: undefined as string | undefined }));
vi.mock('vue-router', async (importOriginal) => ({
  ...(await importOriginal<typeof import('vue-router')>()),
  useRoute: () => route,
}));
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

  it('does not repeat the ML disclosure card above a gene detail, whose hero already carries it', async () => {
    route.name = 'NDDScoreGeneDetail';
    const wrapper = mount(NDDScore, {
      global: { stubs: { RouterView: true, AnalysisShell: false, RouterLink: true } },
    });
    await new Promise((r) => setTimeout(r, 0));
    expect(wrapper.findComponent({ name: 'NddScorePredictionCard' }).exists()).toBe(false);
    route.name = undefined;
  });
});
