import { mount, flushPromises } from '@vue/test-utils';
import { describe, expect, it, vi } from 'vitest';
import NddScoreModelCard from './NddScoreModelCard.vue';

vi.mock('@/api/nddscore', () => ({
  fetchCurrentRelease: vi.fn().mockResolvedValue({
    release_id: 'nddscore_20260517_public',
    version: '2026.05.17',
    version_doi: '10.5281/zenodo.20258027',
    concept_doi: '10.5281/zenodo.20258026',
    zenodo_record_url: 'https://zenodo.org/records/20258027',
    n_genes: 19296,
    n_hpo_predictions: 44360,
    n_hpo_terms: 37,
    n_features: 48,
    ndd_performance_json: JSON.stringify({
      test: { auc_roc: 0.8877, auc_pr: 0.8965, brier: 0.1388, bss: 0.4438 },
    }),
  }),
}));

describe('NddScoreModelCard', () => {
  it('renders the performance grid, counts, and DOIs', async () => {
    const wrapper = mount(NddScoreModelCard);
    await flushPromises();
    const text = wrapper.text();
    expect(text).toContain('0.888');
    expect(text).toContain('19296');
    expect(text).toContain('10.5281/zenodo.20258026');
    expect(text).toContain('ML prediction');
  });
});
