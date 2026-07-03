import { describe, it, expect } from 'vitest';
import { mount } from '@vue/test-utils';
import ClusterValidationCard from './ClusterValidationCard.vue';

const functionalMeta = {
  generated_at: '2026-07-03T06:50:00Z',
  db_release: { version: ['1.0.0'], commit: ['unknown'] },
  validation_hash: ['56a29d312f93e37c4d3ec9ed6eff975c6bab6c5fa0c0fcb90579beb62822f748'],
  validation: {
    algorithm: ['leiden'],
    modularity: [0.5355],
    n_clusters: [9],
    n_dropped_below_min_size: [7],
    n_resamples_effective: [100],
  },
};
const functionalClusters = [
  { cluster: ['1'], cluster_size: [464], jaccard_mean: [0.853], jaccard_n_resamples: [100] },
  { cluster: ['3'], cluster_size: [202], jaccard_mean: [0.41], jaccard_n_resamples: [100] },
];

describe('ClusterValidationCard', () => {
  it('renders the functional (modularity) headline + per-cluster bands with text labels', () => {
    const wrapper = mount(ClusterValidationCard, {
      props: {
        analysisType: 'functional_clusters',
        snapshotMeta: functionalMeta,
        clusters: functionalClusters,
      },
    });
    const text = wrapper.text();
    expect(text).toContain('Modularity');
    expect(text).toContain('0.535');
    expect(text).toContain('1.0.0'); // db release badge
    // per-cluster band labels present as TEXT (not color-only)
    expect(text).toContain('stable');
    expect(text).toContain('dissolved');
  });

  it('renders the phenotype (silhouette + k) headline', () => {
    const wrapper = mount(ClusterValidationCard, {
      props: {
        analysisType: 'phenotype_clusters',
        snapshotMeta: {
          db_release: { version: ['1.0.0'] },
          validation: {
            algorithm: ['mca_hcpc'],
            mean_silhouette: [0.1944],
            k: [3],
            n_entities_dropped: [0],
            n_resamples_effective: [100],
          },
        },
        clusters: [
          { cluster: ['2'], cluster_size: [1420], jaccard_mean: [0.705], silhouette_mean: [0.213] },
        ],
      },
    });
    const text = wrapper.text();
    expect(text).toContain('Mean silhouette');
    expect(text).toContain('0.194');
    expect(text).toContain('Clusters (k)');
    expect(text).toContain('3');
  });

  it('renders nothing when validation is absent (old snapshot)', () => {
    const wrapper = mount(ClusterValidationCard, {
      props: {
        analysisType: 'functional_clusters',
        snapshotMeta: { db_release: { version: ['1.0.0'] }, validation: [] },
        clusters: [],
      },
    });
    expect(wrapper.find('.cluster-validation-card').exists()).toBe(false);
  });

  it('renders nothing when snapshotMeta is null', () => {
    const wrapper = mount(ClusterValidationCard, {
      props: { analysisType: 'functional_clusters', snapshotMeta: null, clusters: [] },
    });
    expect(wrapper.find('.cluster-validation-card').exists()).toBe(false);
  });
});
