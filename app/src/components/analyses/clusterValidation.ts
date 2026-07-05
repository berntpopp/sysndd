// app/src/components/analyses/clusterValidation.ts
//
// Pure helpers for ClusterValidationCard: unwrap Plumber scalar-arrays, classify
// bootstrap-Jaccard stability into Hennig bands, and shape the partition summary +
// per-cluster stability rows. No Vue imports — unit-tested in isolation.

import type { ClusterValidation } from '@/api/analysis';

export type ClusterAnalysisType = 'functional_clusters' | 'phenotype_clusters';

export type StabilityBandKey =
  'highly_stable' | 'stable' | 'doubtful' | 'weak' | 'dissolved' | 'na';

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

// Format an empirical/dip p-value for a metric hint (small p collapses to "<0.001").
function fmtPValue(value: number | null): string {
  if (value == null) return 'n/a';
  return value < 0.001 ? '<0.001' : value.toFixed(3);
}

// Humanize a snake_case token (null-model name, interpretation band) for display.
function humanizeToken(value: string | null): string | null {
  if (value == null) return null;
  return value.replace(/_/g, ' ');
}

// Headline unit-free separation metric shared by both axes (validation schema
// >= 2.0). Hidden entirely when `separation_z` is absent/non-finite so older
// snapshots render unchanged. `pValue` is the axis-specific empirical p.
function separationHeadline(v: ClusterValidation, pValue: number | null): ValidationMetric | null {
  const z = toScalarNumber(v.separation_z);
  if (z == null) return null;
  const nullModel = humanizeToken(toScalarString(v.null_model));
  const parts: string[] = [];
  if (pValue != null) parts.push(`p=${fmtPValue(pValue)}`);
  if (nullModel) parts.push(`vs ${nullModel}`);
  return {
    label: 'Separation z',
    value: fmtDecimal(z),
    hint: parts.length ? parts.join(' ') : undefined,
  };
}

// Functional-only giant-component summary (isolates / component count). Hidden
// when `giant_component` is absent.
function giantComponentMetric(v: ClusterValidation): ValidationMetric | null {
  const gc = v.giant_component;
  if (gc == null || typeof gc !== 'object' || Array.isArray(gc)) return null;
  const isolates = toScalarNumber(gc.n_isolates);
  const components = toScalarNumber(gc.n_components);
  if (isolates == null && components == null) return null;
  return {
    label: 'Isolates / comps',
    value: `${fmtInt(isolates)} / ${fmtInt(components)}`,
  };
}

// Phenotype-only silhouette structure band (humanized). Hidden when absent.
function structureMetric(v: ClusterValidation): ValidationMetric | null {
  const interpretation = humanizeToken(toScalarString(v.silhouette_interpretation));
  if (interpretation == null) return null;
  return { label: 'Structure', value: interpretation };
}

// Functional-only STRING weight-channel provenance. "experimental_database" is the
// clean, text-mining-free graph (#510); "combined_score" means it fell back to the
// STRINGdb combined graph, which INCLUDES text-mining/co-mention — surfaced so a
// contaminated fallback is never invisible. Hidden when absent.
function channelMetric(v: ClusterValidation): ValidationMetric | null {
  const channel = toScalarString(v.weight_channel);
  if (channel == null) return null;
  const clean = channel === 'experimental_database';
  return {
    label: 'STRING channel',
    value: clean ? 'exp + database' : (humanizeToken(channel) ?? channel),
    hint: clean ? 'text-mining excluded' : 'includes text-mining (fallback)',
  };
}

// Dip-of-unimodality interpretation (both axes): discrete/modular vs continuum.
// A corroborating signal, so hidden when undefined/unavailable (diptest absent).
function continuumMetric(v: ClusterValidation): ValidationMetric | null {
  const interp = humanizeToken(toScalarString(v.dip_interpretation));
  if (interp == null || interp === 'undefined' || interp.startsWith('unavailable')) {
    return null;
  }
  return { label: 'Distance shape', value: interp, hint: 'dip test' };
}

export function hasValidation(
  validation: ClusterValidation | unknown[] | null | undefined
): boolean {
  if (!validation || Array.isArray(validation)) return false;
  return toScalarString((validation as ClusterValidation).algorithm) != null;
}

export function summarizeValidation(
  analysisType: ClusterAnalysisType,
  validation: ClusterValidation | unknown[] | null | undefined
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
    const headline = separationHeadline(v, toScalarNumber(v.silhouette_p_empirical));
    const structure = structureMetric(v);
    const continuum = continuumMetric(v);
    return [
      ...(headline ? [headline] : []),
      {
        label: 'Mean silhouette',
        value: fmtDecimal(toScalarNumber(v.mean_silhouette)),
        hint: status ?? undefined,
      },
      { label: 'Clusters (k)', value: fmtInt(toScalarNumber(v.k)), hint: 'data-driven' },
      { label: 'Dropped entities', value: fmtInt(toScalarNumber(v.n_entities_dropped)) },
      resamples,
      ...(structure ? [structure] : []),
      ...(continuum ? [continuum] : []),
    ];
  }
  const headline = separationHeadline(v, toScalarNumber(v.modularity_p_empirical));
  const giantComponent = giantComponentMetric(v);
  const channel = channelMetric(v);
  const continuum = continuumMetric(v);
  return [
    ...(headline ? [headline] : []),
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
    ...(giantComponent ? [giantComponent] : []),
    ...(channel ? [channel] : []),
    ...(continuum ? [continuum] : []),
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
  clusters: RawClusterRow[] | null | undefined
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
