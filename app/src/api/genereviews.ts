// app/src/api/genereviews.ts
//
// GeneReviews coverage + attach resource helpers (issues #14, #46).
//
// Mirrors api/endpoints/genereviews_endpoints.R (mounted at /api/genereviews).
// All endpoints are Curator+ gated; the Authorization header is injected by the
// shared request interceptor in @/api/client.

import type { AxiosRequestConfig } from 'axios';
import { apiClient } from './client';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/** Single-gene availability payload from GET /api/genereviews/availability/<symbol>. */
export interface GeneReviewAvailability {
  source: string;
  gene_symbol: string;
  has_genereview: boolean;
  nbk_id: string | null;
  url: string | null;
  title: string | null;
  chapter_count: number;
}

/** One row of the coverage table (GET /api/genereviews/coverage). */
export interface GeneReviewCoverageRow {
  entity_id: number;
  hgnc_id: string;
  symbol: string;
  disease_ontology_name: string | null;
  /** TRUE when a GeneReviews reference is already linked to the entity. */
  already_linked: boolean;
  linked_pmid: string | null;
  linked_nbk_id: string | null;
  /** Live (cached) upstream availability; null when include_live is false. */
  genereview_available: boolean | null;
  available_nbk_id: string | null;
  available_url: string | null;
  available_title: string | null;
  lookup_error: boolean;
  /**
   * TRUE when a GeneReviews chapter is available upstream but not yet linked
   * (the #46 "flag genes lacking an entry" signal). null when include_live is
   * false.
   */
  needs_attention: boolean | null;
}

export interface GeneReviewCoverageMeta {
  include_live: boolean;
  total: number;
  already_linked: number;
  needs_attention: number | null;
}

export interface GeneReviewCoverageResponse {
  meta: GeneReviewCoverageMeta;
  data: GeneReviewCoverageRow[];
}

export interface GeneReviewCoverageParams {
  /** Include live (cached) NCBI availability + the needs_attention flag. */
  include_live?: boolean;
}

/** Request body for POST /api/genereviews/attach. */
export interface AttachGeneReviewRequest {
  entity_id: number;
  /** GeneReviews chapter PMID (with or without the "PMID:" prefix). */
  pmid: string;
}

export interface AttachGeneReviewResponse {
  status: number;
  message: string;
  entity_id?: number;
  review_id?: number;
  publication_id?: string;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * GET /api/genereviews/availability/<symbol>
 * Curator+ only. Returns whether a GeneReviews chapter exists for a gene.
 */
export async function getGeneReviewAvailability(
  symbol: string,
  config?: AxiosRequestConfig
): Promise<GeneReviewAvailability> {
  const path = `/api/genereviews/availability/${encodeURIComponent(symbol)}`;
  return apiClient.get<GeneReviewAvailability>(path, config);
}

/**
 * GET /api/genereviews/coverage
 * Curator+ only. Lists entities with GeneReviews availability. Pass
 * `include_live: true` to also fetch (cached) upstream availability.
 */
export async function getGeneReviewsCoverage(
  params: GeneReviewCoverageParams = {},
  config?: AxiosRequestConfig
): Promise<GeneReviewCoverageResponse> {
  return apiClient.get<GeneReviewCoverageResponse>('/api/genereviews/coverage', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * GET /api/genereviews/coverage/export
 * Curator+ only. Returns the coverage table as a CSV Blob for download.
 */
export async function exportGeneReviewsCoverageCsv(
  params: GeneReviewCoverageParams = {},
  config?: AxiosRequestConfig
): Promise<Blob> {
  const response = await apiClient.raw.get<Blob>('/api/genereviews/coverage/export', {
    ...config,
    responseType: 'blob',
    params: { ...(config?.params as object | undefined), ...params },
  });
  return response.data;
}

/**
 * POST /api/genereviews/attach
 * Curator+ only. Attaches a GeneReviews chapter (by PMID) to an entity's
 * primary review. Idempotent: re-attaching an already-linked PMID succeeds.
 *
 * Throws AxiosError on non-2xx (400 invalid input / not a GeneReviews chapter,
 * 403 not Curator, 404 entity has no review).
 */
export async function attachGeneReview(
  body: AttachGeneReviewRequest,
  config?: AxiosRequestConfig
): Promise<AttachGeneReviewResponse> {
  return apiClient.post<AttachGeneReviewResponse, AttachGeneReviewRequest>(
    '/api/genereviews/attach',
    body,
    config
  );
}
