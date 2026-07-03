// app/src/api/analysis.ts
//
// Analysis resource helpers (clustering, correlation, network).
//
// Mirrors api/endpoints/analysis_endpoints.R (mounted at /api/analysis).
// Phase E.E2: filled during v11.1 Wave 1a (W3).
//
// Most analysis endpoints are heavy synchronous tibble-shaped responses. The
// async equivalents (`POST /api/jobs/clustering/submit`,
// `POST /api/jobs/phenotype_clustering/submit`) live in `jobs.ts`.

import type { AxiosRequestConfig } from 'axios';
import { apiClient } from './client';

// ---------------------------------------------------------------------------
// Snapshot "being prepared" classification
// ---------------------------------------------------------------------------

/**
 * Problem codes the analysis-snapshot endpoints return (HTTP 503) while a
 * snapshot is being (re)built rather than on a hard failure. The frontend shows
 * a friendly "being prepared" state for these instead of a raw error. (#420)
 */
export const SNAPSHOT_PREPARING_CODES = [
  'snapshot_missing',
  'snapshot_stale',
  'source_version_mismatch',
  'schema_version_mismatch',
] as const;

/**
 * Returns true when an error is an analysis-snapshot "being prepared" 503
 * (snapshot missing/stale/mismatch), false for any other error.
 *
 * The API rejects with a raw AxiosError (the typed `apiClient` only unwraps
 * `response.data` on success), so the status code lives at
 * `err.response.status` and the RFC 9457 problem code at
 * `err.response.data.code` — the same access path `networkDataError()` already
 * uses in `useNetworkData.ts`.
 */
export function isSnapshotPreparingError(err: unknown): boolean {
  const problem = (err as { response?: { status?: number; data?: { code?: string | string[] } } })
    ?.response;
  if (!problem || problem.status !== 503) return false;
  // R/Plumber serialises a bare scalar as a 1-element array, so the problem
  // `code` arrives as either "snapshot_missing" or ["snapshot_missing"] over
  // the wire (see `unwrapScalar` in @/api/client). Accept both shapes so the
  // "being prepared" state actually triggers against the real API (#440).
  const raw = problem.data?.code;
  const code = Array.isArray(raw) ? raw[0] : raw;
  return typeof code === 'string'
    && (SNAPSHOT_PREPARING_CODES as readonly string[]).includes(code);
}

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type ClusteringAlgorithm = 'leiden';

export interface FunctionalClusteringParams {
  page_after?: string;
  page_size?: string;
  algorithm?: ClusteringAlgorithm;
}

export interface ClusterCategory {
  value: string;
  text: string;
  link?: string;
}

/**
 * One cluster row from `gen_string_clust_obj_mem()`. The full shape includes
 * nested tibbles (`identifiers`, `term_enrichment`) that round-trip via JSON
 * as nested arrays/objects — we surface them as `unknown` so consumers can
 * narrow as needed.
 */
export interface FunctionalCluster {
  cluster: string | number;
  hash_filter: string;
  identifiers?: unknown;
  term_enrichment?: unknown;
  // Per-cluster stability joined in by the snapshot builder (scalar-or-array).
  cluster_size?: number | number[];
  jaccard_mean?: number | number[];
  jaccard_n_resamples?: number | number[];
  [key: string]: unknown;
}

export interface PaginationMeta {
  page_size: number;
  page_after: string;
  next_cursor: string | null;
  total_count: number;
  has_more: boolean;
}

/**
 * Partition-level cluster-validation metrics persisted on the snapshot manifest
 * (#457–459). The functional (Leiden) and phenotype (MCA/HCPC) presets populate
 * different subsets; all fields are optional. Values arrive as Plumber
 * scalar-arrays, so read them through the unwrap helpers in
 * `components/analyses/clusterValidation.ts`.
 */
export interface ClusterValidation {
  validation_schema_version?: string | string[];
  algorithm?: string | string[];
  // functional (leiden)
  weighted?: boolean | boolean[];
  modularity?: number | number[];
  modularity_scope?: string | string[];
  resolution_parameter?: number | number[];
  n_iterations?: number | number[];
  n_clusters?: number | number[];
  n_dropped_below_min_size?: number | number[];
  // phenotype (mca_hcpc)
  k?: number | number[];
  k_selection_metric?: string | string[];
  mean_silhouette?: number | number[];
  silhouette_status?: string | string[];
  n_entities_assigned?: number | number[];
  n_entities_dropped?: number | number[];
  // shared
  partition_scope?: string | string[];
  resampling_scheme?: string | string[];
  subsample_fraction?: number | number[];
  n_resamples?: number | number[];
  n_resamples_effective?: number | number[];
  [key: string]: unknown;
}

export interface AnalysisSnapshotMeta {
  snapshot_id?: number;
  analysis_type?: string;
  parameter_hash?: string;
  schema_version?: string;
  data_class?: string;
  generated_at?: string;
  stale_after?: string;
  source_data_version?: string;
  // Cluster-validation surface (#457–459). `validation` is an empty array/object
  // for snapshots built before validation existed; the card hides itself then.
  validation?: ClusterValidation | unknown[];
  validation_hash?: string | string[];
  db_release?: { version?: string | string[]; commit?: string | string[] };
}

export interface ClusteringMeta {
  algorithm: string;
  elapsed_seconds: number;
  gene_count: number;
  cluster_count: number;
  cache_hit?: boolean;
  snapshot?: AnalysisSnapshotMeta;
}

export interface FunctionalClusteringResponse {
  categories: ClusterCategory[];
  clusters: FunctionalCluster[];
  pagination: PaginationMeta;
  meta: ClusteringMeta;
}

/**
 * One phenotype cluster row returned in the `GET /api/analysis/phenotype_clustering`
 * envelope.
 */
export interface PhenotypeCluster {
  cluster: string | number;
  identifiers: Array<{ entity_id: number; hgnc_id: string; symbol: string }>;
  // Per-cluster stability joined in by the snapshot builder (scalar-or-array).
  cluster_size?: number | number[];
  jaccard_mean?: number | number[];
  jaccard_n_resamples?: number | number[];
  silhouette_mean?: number | number[];
  [key: string]: unknown;
}

export interface PhenotypeClusteringResponse {
  clusters: PhenotypeCluster[];
  meta: {
    snapshot?: AnalysisSnapshotMeta;
    [key: string]: unknown;
  };
}

/**
 * One row of the melted correlation matrix.
 */
export interface CorrelationCell {
  x: string;
  y: string;
  value: number;
}

export interface CorrelationResponse {
  /** Square matrix of Pearson correlation coefficients. */
  correlation_matrix: number[][];
  correlation_melted: CorrelationCell[];
}

export type ClusterType = 'clusters';

export interface NetworkEdgesParams {
  cluster_type?: 'clusters';
  min_confidence?: '400';
  max_edges?: '10000';
}

export interface NetworkNode {
  hgnc_id: string;
  symbol: string;
  cluster: string | number;
  degree: number;
  category?: string;
  x?: number;
  y?: number;
  layout_x?: number;
  layout_y?: number;
  igraph_x?: number;
  igraph_y?: number;
  [key: string]: unknown;
}

export interface NetworkEdge {
  source: string;
  target: string;
  confidence: number;
}

export interface NetworkMetadata {
  node_count: number;
  edge_count: number;
  cluster_count: number;
  total_edges: number;
  edges_filtered: boolean;
  string_version?: string;
  min_confidence?: number;
  elapsed_seconds: number;
  category_counts?: Record<string, number>;
  layout_algorithm?: string;
  layout_engine?: string;
  display_layout_status?: 'available' | 'missing' | 'invalid' | 'error';
  display_layout_key?: string;
  display_layout_version?: number;
  display_layout_duration_ms?: number;
  display_layout_node_count?: number;
  display_layout_edge_count?: number;
  layout_time_seconds?: number;
  total_ndd_genes?: number;
  genes_with_string?: number;
  genes_in_clusters?: number;
  snapshot?: AnalysisSnapshotMeta;
  [key: string]: unknown;
}

export interface NetworkEdgesResponse {
  nodes: NetworkNode[];
  edges: NetworkEdge[];
  metadata: NetworkMetadata;
}

export type NetworkResponse = NetworkEdgesResponse;

export interface ClusterSummaryParams {
  cluster_hash: string;
  cluster_number: string;
}

/**
 * Response shape from `get_cluster_summary()` (functional + phenotype). The
 * `summary_json` field is an opaque structured blob produced by the LLM.
 */
export interface ClusterSummary {
  cluster_hash: string;
  cluster_number: number | string;
  summary_json: Record<string, unknown>;
  validation_status?: string;
  generated_at?: string;
  /**
   * Terminal "could not be validated" state (#490). When the judge rejected the
   * cluster's summary the API returns HTTP 200 with `summary_available = false`,
   * `validation_status = 'rejected'`, and a `reason` — distinct from a 404 "not
   * yet generated". Plumber may array-wrap these scalars.
   */
  summary_available?: boolean | boolean[];
  reason?: string | string[];
  [key: string]: unknown;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * GET /api/analysis/functional_clustering
 * Mirrors api/endpoints/analysis_endpoints.R:51 (handler `@get functional_clustering`).
 *
 * Cursor-paginated public functional clusters (STRINGdb + Leiden preset).
 * Public — no auth.
 */
export async function getFunctionalClustering(
  params: FunctionalClusteringParams = {},
  config?: AxiosRequestConfig
): Promise<FunctionalClusteringResponse> {
  return apiClient.get<FunctionalClusteringResponse>('/api/analysis/functional_clustering', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * GET /api/analysis/phenotype_clustering
 * Mirrors api/endpoints/analysis_endpoints.R:236 (handler `@get phenotype_clustering`).
 *
 * MCA + hierarchical clustering of entities by phenotype.
 */
export async function getPhenotypeClustering(
  config?: AxiosRequestConfig
): Promise<PhenotypeClusteringResponse> {
  return apiClient.get<PhenotypeClusteringResponse>('/api/analysis/phenotype_clustering', config);
}

/**
 * GET /api/analysis/phenotype_functional_cluster_correlation
 * Mirrors api/endpoints/analysis_endpoints.R:356 (handler `@get phenotype_functional_cluster_correlation`).
 *
 * Returns Pearson correlation between phenotype + functional cluster
 * presence/absence matrices, as both raw matrix and melted form.
 */
export async function getPhenotypeFunctionalCorrelation(
  config?: AxiosRequestConfig
): Promise<CorrelationResponse> {
  return apiClient.get<CorrelationResponse>(
    '/api/analysis/phenotype_functional_cluster_correlation',
    config
  );
}

/**
 * GET /api/analysis/network_edges
 * Mirrors api/endpoints/analysis_endpoints.R:612 (handler `@get network_edges`).
 *
 * Returns Cytoscape.js-shaped node/edge payload for the protein-protein
 * interaction network for the fixed public preset:
 * cluster_type="clusters", min_confidence="400", max_edges="10000".
 */
export async function getNetworkEdges(
  params: NetworkEdgesParams = {},
  config?: AxiosRequestConfig
): Promise<NetworkEdgesResponse> {
  return apiClient.get<NetworkEdgesResponse>('/api/analysis/network_edges', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * GET /api/analysis/functional_cluster_summary
 * Mirrors api/endpoints/analysis_endpoints.R:713 (handler `@get functional_cluster_summary`).
 *
 * Retrieves or generates the LLM summary for a functional cluster.
 *
 * Throws AxiosError on non-2xx (400 missing params, 404 cluster not found,
 * 500 generation failure, 503 LLM not configured).
 */
export async function getFunctionalClusterSummary(
  params: ClusterSummaryParams,
  config?: AxiosRequestConfig
): Promise<ClusterSummary> {
  return apiClient.get<ClusterSummary>('/api/analysis/functional_cluster_summary', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * GET /api/analysis/phenotype_cluster_summary
 * Mirrors api/endpoints/analysis_endpoints.R:744 (handler `@get phenotype_cluster_summary`).
 *
 * Retrieves or generates the LLM summary for a phenotype cluster.
 */
export async function getPhenotypeClusterSummary(
  params: ClusterSummaryParams,
  config?: AxiosRequestConfig
): Promise<ClusterSummary> {
  return apiClient.get<ClusterSummary>('/api/analysis/phenotype_cluster_summary', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}
