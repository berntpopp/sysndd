// app/src/api/review.ts
//
// Review (clinical synopsis) resource helpers.
//
// Mirrors api/endpoints/review_endpoints.R (mounted at /api/review).
// Phase E.E2: filled during v11.1 Wave 1a (W3).
//
// Used by W6 (`Review.vue`) and W4 (`ApproveReview.vue`).

import type { AxiosRequestConfig } from 'axios';
import { apiClient } from './client';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface ListReviewsParams {
  /** R coerces "TRUE"/"FALSE". */
  filter_review_approved?: boolean;
}

/**
 * One row of the review-list response. Includes joined entity, gene,
 * disease, inheritance, and status data.
 */
export interface ReviewListRow {
  review_id: number;
  entity_id: number;
  hgnc_id: string;
  symbol: string;
  disease_ontology_id_version: string;
  disease_ontology_name: string;
  hpo_mode_of_inheritance_term: string;
  hpo_mode_of_inheritance_term_name: string;
  synopsis: string | null;
  is_primary: number;
  review_date: string;
  review_user_name: string | null;
  review_user_role: string | null;
  review_approved: number | null;
  approving_user_name: string | null;
  approving_user_role: string | null;
  approving_user_id: number | null;
  comment: string | null;
  duplicate?: 'yes' | 'no';
  active_status?: number | null;
  active_category?: number | null;
  newest_status?: number | null;
  newest_category?: number | null;
  status_change?: number;
}

export interface ReviewMutationParams {
  /** R coerces "TRUE"/"FALSE". */
  re_review?: boolean;
}

/**
 * Body shape for `POST /api/review/create` and `PUT /api/review/update`.
 */
export interface ReviewMutationRequest {
  review_json: {
    entity_id: number | string;
    synopsis: string;
    comment?: string | null;
    literature?: {
      additional_references?: Array<{ value: string }>;
      gene_review?: Array<{ value: string }>;
    };
    phenotypes?: unknown;
    variation_ontology?: unknown;
    [key: string]: unknown;
  };
}

/**
 * Generic mutation envelope used by review create/update + approval.
 */
export interface ReviewMutationResponse {
  status: number;
  message?: string;
  entry?: { review_id?: number; [key: string]: unknown };
  error?: string;
}

export interface ReviewByIdRow {
  review_id: number;
  entity_id: number;
  synopsis: string | null;
  is_primary: number;
  review_date: string;
  review_user_name: string | null;
  review_user_role: string | null;
  review_approved: number | null;
  approving_user_name: string | null;
  approving_user_role: string | null;
  comment: string | null;
}

export interface ReviewPhenotypeRow {
  review_id: number;
  entity_id: number;
  phenotype_id: string;
  HPO_term: string;
  modifier_id: number | string | null;
}

export interface ReviewVariationRow {
  review_id: number;
  entity_id: number;
  vario_id: string;
  vario_name: string;
  modifier_id: number | string | null;
}

export interface ReviewPublicationRow {
  review_id: number;
  entity_id: number;
  publication_id: string;
  publication_type?: string | null;
  is_reviewed?: number | string | null;
}

export interface ApproveReviewParams {
  /** R coerces "TRUE"/"FALSE". */
  review_ok?: boolean;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * GET /api/review/
 * Mirrors api/endpoints/review_endpoints.R:34 (handler `@get /`).
 *
 * Returns the review-overview list. `filter_review_approved=TRUE` returns
 * only approved reviews; `FALSE` (default) returns unapproved + unreviewed.
 */
export async function listReviews(
  params: ListReviewsParams = {},
  config?: AxiosRequestConfig,
): Promise<ReviewListRow[]> {
  return apiClient.get<ReviewListRow[]>('/api/review/', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * POST /api/review/create
 * Mirrors api/endpoints/review_endpoints.R:199 (handler `@post /create`).
 *
 * Reviewer+ only. Creates a new clinical synopsis with optional
 * publications/phenotypes/variation.
 *
 * Throws AxiosError on non-2xx (400 empty synopsis, 403 not Reviewer).
 */
export async function createReview(
  body: ReviewMutationRequest,
  params: ReviewMutationParams = {},
  config?: AxiosRequestConfig,
): Promise<ReviewMutationResponse> {
  return apiClient.post<ReviewMutationResponse, ReviewMutationRequest>(
    '/api/review/create',
    body,
    {
      ...config,
      params: { ...(config?.params as object | undefined), ...params },
    },
  );
}

/**
 * PUT /api/review/update
 * Mirrors api/endpoints/review_endpoints.R:199 (handler `@put /update`, same fn as @post /create).
 *
 * Reviewer+ only. Updates an existing review.
 */
export async function updateReview(
  body: ReviewMutationRequest,
  params: ReviewMutationParams = {},
  config?: AxiosRequestConfig,
): Promise<ReviewMutationResponse> {
  return apiClient.put<ReviewMutationResponse, ReviewMutationRequest>(
    '/api/review/update',
    body,
    {
      ...config,
      params: { ...(config?.params as object | undefined), ...params },
    },
  );
}

/**
 * GET /api/review/<review_id_requested>
 * Mirrors api/endpoints/review_endpoints.R:410 (handler `@get /<review_id_requested>`).
 *
 * Returns the review row(s) for the requested ID. The R handler accepts
 * comma-separated IDs and returns all matching rows.
 */
export async function getReviewById(
  review_id_requested: number | string,
  config?: AxiosRequestConfig,
): Promise<ReviewByIdRow[]> {
  const path = `/api/review/${encodeURIComponent(String(review_id_requested))}`;
  return apiClient.get<ReviewByIdRow[]>(path, config);
}

/**
 * GET /api/review/<review_id_requested>/phenotypes
 * Mirrors api/endpoints/review_endpoints.R:464 (handler `@get /<review_id_requested>/phenotypes`).
 */
export async function getReviewPhenotypes(
  review_id_requested: number | string,
  config?: AxiosRequestConfig,
): Promise<ReviewPhenotypeRow[]> {
  const path = `/api/review/${encodeURIComponent(String(review_id_requested))}/phenotypes`;
  return apiClient.get<ReviewPhenotypeRow[]>(path, config);
}

/**
 * GET /api/review/<review_id_requested>/variation
 * Mirrors api/endpoints/review_endpoints.R:506 (handler `@get /<review_id_requested>/variation`).
 */
export async function getReviewVariation(
  review_id_requested: number | string,
  config?: AxiosRequestConfig,
): Promise<ReviewVariationRow[]> {
  const path = `/api/review/${encodeURIComponent(String(review_id_requested))}/variation`;
  return apiClient.get<ReviewVariationRow[]>(path, config);
}

/**
 * GET /api/review/<review_id_requested>/publications
 * Mirrors api/endpoints/review_endpoints.R:548 (handler `@get /<review_id_requested>/publications`).
 */
export async function getReviewPublications(
  review_id_requested: number | string,
  config?: AxiosRequestConfig,
): Promise<ReviewPublicationRow[]> {
  const path = `/api/review/${encodeURIComponent(String(review_id_requested))}/publications`;
  return apiClient.get<ReviewPublicationRow[]>(path, config);
}

/**
 * PUT /api/review/approve/<review_id_requested>
 * Mirrors api/endpoints/review_endpoints.R:587 (handler `@put /approve/<review_id_requested>`).
 *
 * Curator+ only. Approves or unapproves a review.
 */
export async function approveReview(
  review_id_requested: number | string,
  params: ApproveReviewParams = {},
  config?: AxiosRequestConfig,
): Promise<ReviewMutationResponse> {
  const path = `/api/review/approve/${encodeURIComponent(String(review_id_requested))}`;
  return apiClient.put<ReviewMutationResponse>(path, undefined, {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}
