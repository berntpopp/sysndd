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
// Types
// ---------------------------------------------------------------------------

export type ClusteringAlgorithm = 'leiden' | 'walktrap';

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
  [key: string]: unknown;
}

export interface PaginationMeta {
  page_size: number;
  page_after: string;
  next_cursor: string | null;
  total_count: number;
  has_more: boolean;
}

export interface ClusteringMeta {
  algorithm: string;
  elapsed_seconds: number;
  gene_count: number;
  cluster_count: number;
  cache_hit?: boolean;
}

export interface FunctionalClusteringResponse {
  categories: ClusterCategory[];
  clusters: FunctionalCluster[];
  pagination: PaginationMeta;
  meta: ClusteringMeta;
}

/**
 * One element returned by `GET /api/analysis/phenotype_clustering` — a
 * cluster + the nested entity identifiers belonging to it.
 */
export interface PhenotypeCluster {
  cluster: string | number;
  identifiers: Array<{ entity_id: number; hgnc_id: string; symbol: string }>;
  [key: string]: unknown;
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

export type ClusterType = 'clusters' | 'subclusters';

export interface NetworkEdgesParams {
  cluster_type?: ClusterType;
  min_confidence?: string;
  /** "0" returns all edges; default "10000". */
  max_edges?: string;
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
  [key: string]: unknown;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * GET /api/analysis/functional_clustering
 * Mirrors api/endpoints/analysis_endpoints.R:51 (handler `@get functional_clustering`).
 *
 * Cursor-paginated functional clusters (STRINGdb + Leiden/Walktrap).
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
): Promise<PhenotypeCluster[]> {
  return apiClient.get<PhenotypeCluster[]>('/api/analysis/phenotype_clustering', config);
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
 * interaction network. Uses `@serializer json list(auto_unbox=TRUE)`, so no
 * scalar-array wrapping.
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
