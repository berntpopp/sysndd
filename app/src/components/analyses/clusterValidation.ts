// app/src/components/analyses/clusterValidation.ts
//
// Pure helpers for ClusterValidationCard: unwrap Plumber scalar-arrays, classify
// bootstrap-Jaccard stability into Hennig bands, and shape the partition summary +
// per-cluster stability rows. No Vue imports — unit-tested in isolation.

import type { ClusterValidation } from '@/api/analysis';

export type ClusterAnalysisType = 'functional_clusters' | 'phenotype_clusters';

export type StabilityBandKey =
  | 'highly_stable'
  | 'stable'
  | 'doubtful'
  | 'weak'
  | 'dissolved'
  | 'na';

export interface StabilityBand {
  key: StabilityBandKey;
  label: string;
}

export interface ValidationMetric {
  label: string;
  value: string;
  hint?: string;
}

export interface ClusterStabilityRow {
  id: string;
  size: number | null;
  jaccard: number | null;
  jaccardN: number | null;
  silhouette: number | null;
  band: StabilityBand;
}

export function toScalar(value: unknown): unknown {
  return Array.isArray(value) ? value[0] : value;
}

export function toScalarNumber(value: unknown): number | null {
  const v = toScalar(value);
  if (v == null || v === '') return null;
  const n = typeof v === 'number' ? v : Number(v);
  return Number.isFinite(n) ? n : null;
}

export function toScalarString(value: unknown): string | null {
  const v = toScalar(value);
  if (v == null) return null;
  const s = typeof v === 'string' ? v : String(v);
  return s.length > 0 ? s : null;
}

// Hennig clusterboot bands (api/functions/analysis-cluster-validation.R).
export function jaccardBand(value: number | null): StabilityBand {
  if (value == null || Number.isNaN(value)) return { key: 'na', label: 'n/a' };
  if (value >= 0.85) return { key: 'highly_stable', label: 'highly stable' };
  if (value >= 0.75) return { key: 'stable', label: 'stable' };
  if (value >= 0.6) return { key: 'doubtful', label: 'doubtful' };
  if (value >= 0.5) return { key: 'weak', label: 'weak' };
  return { key: 'dissolved', label: 'dissolved' };
}

function fmtDecimal(value: number | null, digits = 3): string {
  return value == null ? 'n/a' : value.toFixed(digits);
}

function fmtInt(value: number | null): string {
  return value == null ? 'n/a' : String(Math.trunc(value));
}

export function hasValidation(
  validation: ClusterValidation | unknown[] | null | undefined,
): boolean {
  if (!validation || Array.isArray(validation)) return false;
  return toScalarString((validation as ClusterValidation).algorithm) != null;
}

export function summarizeValidation(
  analysisType: ClusterAnalysisType,
  validation: ClusterValidation | unknown[] | null | undefined,
): ValidationMetric[] {
  if (!hasValidation(validation)) return [];
  const v = validation as ClusterValidation;
  const algorithm = toScalarString(v.algorithm);
  const resamples = {
    label: 'Resamples',
    value: fmtInt(toScalarNumber(v.n_resamples_effective)),
  };

  if (analysisType === 'phenotype_clusters' || algorithm === 'mca_hcpc') {
    const status = toScalarString(v.silhouette_status);
    return [
      {
        label: 'Mean silhouette',
        value: fmtDecimal(toScalarNumber(v.mean_silhouette)),
        hint: status ?? undefined,
      },
      { label: 'Clusters (k)', value: fmtInt(toScalarNumber(v.k)), hint: 'data-driven' },
      { label: 'Dropped entities', value: fmtInt(toScalarNumber(v.n_entities_dropped)) },
      resamples,
    ];
  }
  return [
    {
      label: 'Modularity',
      value: fmtDecimal(toScalarNumber(v.modularity)),
      hint: 'weighted, full partition',
    },
    { label: 'Clusters', value: fmtInt(toScalarNumber(v.n_clusters)) },
    {
      label: 'Dropped (< min size)',
      value: fmtInt(toScalarNumber(v.n_dropped_below_min_size)),
    },
    resamples,
  ];
}

interface RawClusterRow {
  cluster?: unknown;
  cluster_size?: unknown;
  jaccard_mean?: unknown;
  jaccard_n_resamples?: unknown;
  silhouette_mean?: unknown;
  [key: string]: unknown;
}

export function perClusterStability(
  clusters: RawClusterRow[] | null | undefined,
): ClusterStabilityRow[] {
  if (!Array.isArray(clusters)) return [];
  return clusters
    .map((c) => {
      const jaccard = toScalarNumber(c.jaccard_mean);
      return {
        id: toScalarString(c.cluster) ?? '?',
        size: toScalarNumber(c.cluster_size),
        jaccard,
        jaccardN: toScalarNumber(c.jaccard_n_resamples),
        silhouette: toScalarNumber(c.silhouette_mean),
        band: jaccardBand(jaccard),
      };
    })
    .sort((a, b) => (b.size ?? 0) - (a.size ?? 0));
}
