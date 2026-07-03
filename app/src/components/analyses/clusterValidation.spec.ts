import { describe, it, expect } from 'vitest';
import {
  toScalarNumber,
  toScalarString,
  jaccardBand,
  summarizeValidation,
  perClusterStability,
  hasValidation,
} from './clusterValidation';

describe('scalar unwrapping', () => {
  it('unwraps Plumber scalar-arrays and passes through plain scalars', () => {
    expect(toScalarNumber([0.8525])).toBe(0.8525);
    expect(toScalarNumber(3)).toBe(3);
    expect(toScalarNumber(['x'])).toBeNull();
    expect(toScalarNumber(undefined)).toBeNull();
    expect(toScalarString(['leiden'])).toBe('leiden');
    expect(toScalarString('mca_hcpc')).toBe('mca_hcpc');
    expect(toScalarString([])).toBeNull();
  });
});

describe('jaccardBand — Hennig thresholds', () => {
  it('classifies at each boundary', () => {
    expect(jaccardBand(0.9).key).toBe('highly_stable');
    expect(jaccardBand(0.85).key).toBe('highly_stable');
    expect(jaccardBand(0.8).key).toBe('stable');
    expect(jaccardBand(0.75).key).toBe('stable');
    expect(jaccardBand(0.7).key).toBe('doubtful');
    expect(jaccardBand(0.6).key).toBe('doubtful');
    expect(jaccardBand(0.55).key).toBe('weak');
    expect(jaccardBand(0.5).key).toBe('weak');
    expect(jaccardBand(0.41).key).toBe('dissolved');
    expect(jaccardBand(null).key).toBe('na');
    expect(jaccardBand(Number.NaN).key).toBe('na');
  });
  it('gives every band a human label', () => {
    expect(jaccardBand(0.85).label).toBe('highly stable');
    expect(jaccardBand(0.41).label).toBe('dissolved');
    expect(jaccardBand(null).label).toBe('n/a');
  });
});

describe('summarizeValidation', () => {
  it('functional headline uses weighted modularity', () => {
    const rows = summarizeValidation('functional_clusters', {
      algorithm: ['leiden'],
      modularity: [0.5355],
      n_clusters: [9],
      n_dropped_below_min_size: [7],
      n_resamples_effective: [100],
    });
    const byLabel = Object.fromEntries(rows.map((r) => [r.label, r.value]));
    expect(byLabel['Modularity']).toBe('0.535'); // (0.5355).toFixed(3) === '0.535' (float64)
    expect(byLabel['Clusters']).toBe('9');
    expect(byLabel['Dropped (< min size)']).toBe('7');
    expect(byLabel['Resamples']).toBe('100');
  });
  it('phenotype headline uses mean silhouette + data-driven k', () => {
    const rows = summarizeValidation('phenotype_clusters', {
      algorithm: ['mca_hcpc'],
      mean_silhouette: [0.1944],
      silhouette_status: ['ok'],
      k: [3],
      n_entities_dropped: [0],
      n_resamples_effective: [100],
    });
    const byLabel = Object.fromEntries(rows.map((r) => [r.label, r.value]));
    expect(byLabel['Mean silhouette']).toBe('0.194');
    expect(byLabel['Clusters (k)']).toBe('3');
    expect(byLabel['Dropped entities']).toBe('0');
  });
  it('returns [] when validation is absent', () => {
    expect(summarizeValidation('functional_clusters', null)).toEqual([]);
  });
});

describe('perClusterStability', () => {
  it('maps + sorts by size desc and bands each cluster', () => {
    const rows = perClusterStability([
      { cluster: ['1'], cluster_size: [206], jaccard_mean: [0.686], jaccard_n_resamples: [100] },
      { cluster: ['2'], cluster_size: [1420], jaccard_mean: [0.705], jaccard_n_resamples: [100] },
      {
        cluster: ['3'],
        cluster_size: [306],
        jaccard_mean: [0.456],
        jaccard_n_resamples: [100],
        silhouette_mean: [0.362],
      },
    ]);
    expect(rows.map((r) => r.id)).toEqual(['2', '3', '1']); // size desc
    expect(rows[0].band.key).toBe('doubtful');
    expect(rows[1].band.key).toBe('dissolved');
    expect(rows[1].silhouette).toBe(0.362);
  });
  it('is empty for a non-array input', () => {
    expect(perClusterStability(undefined)).toEqual([]);
  });
});

describe('hasValidation', () => {
  it('is false for empty/absent validation and true for a populated block', () => {
    expect(hasValidation(null)).toBe(false);
    expect(hasValidation([] as unknown as never)).toBe(false);
    expect(hasValidation({} as never)).toBe(false);
    expect(hasValidation({ algorithm: ['leiden'], modularity: [0.5] })).toBe(true);
  });
});
