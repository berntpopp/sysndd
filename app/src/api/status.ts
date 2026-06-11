// app/src/api/status.ts
//
// Entity-status resource helpers.
//
// Mirrors api/endpoints/status_endpoints.R (mounted at /api/status).
// Phase E.E2: filled during v11.1 Wave 1a (W3).
//
// Used by W4 (`ApproveStatus.vue`) and the curate views' status workflows.

import type { AxiosRequestConfig } from 'axios';
import { apiClient } from './client';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface ListStatusParams {
  /** R coerces "TRUE"/"FALSE". */
  filter_status_approved?: boolean;
}

export interface StatusListRow {
  status_id: number;
  entity_id: number;
  hgnc_id: string;
  symbol: string;
  disease_ontology_id_version: string;
  disease_ontology_name: string;
  hpo_mode_of_inheritance_term: string;
  hpo_mode_of_inheritance_term_name: string;
  category: string;
  category_id: number;
  is_active: number;
  status_date: string;
  status_user_name: string | null;
  status_user_role: string | null;
  status_approved: number | null;
  approving_user_name: string | null;
  approving_user_role: string | null;
  approving_user_id: number | null;
  comment: string | null;
  problematic: number | string | null;
  duplicate?: 'yes' | 'no';
  active_review?: number | null;
  newest_review?: number | null;
  review_change?: number;
}

export interface StatusByIdRow {
  status_id: number;
  entity_id: number;
  category: string;
  category_id: number;
  is_active: number;
  status_date: string;
  status_user_name: string | null;
  status_user_role: string | null;
  status_approved: number | null;
  approving_user_name: string | null;
  approving_user_role: string | null;
  comment: string | null;
  problematic: number | string | null;
}

export interface StatusCategoriesParams {
  page_after?: string | number;
  page_size?: string;
}

export interface StatusCategoryRow {
  category_id: number;
  category: string;
  [key: string]: unknown;
}

export interface StatusCategoriesResponse {
  links: unknown;
  meta: unknown;
  data: StatusCategoryRow[];
}

export interface StatusMutationParams {
  re_review?: boolean;
  /**
   * Curator+ only. When true the server approves the freshly written status
   * in the same request (mirrors the entity-create `direct_approval` flow in
   * `entity_endpoints.R`). R coerces "TRUE"/"FALSE"; non-Curator callers are
   * rejected with 403 server-side regardless of this flag.
   */
  direct_approval?: boolean | string;
}

export interface StatusMutationRequest {
  status_json: {
    entity_id: number | string;
    category_id: number | string;
    comment?: string | null;
    problematic?: number | string;
    [key: string]: unknown;
  };
}

export interface StatusMutationResponse {
  status: number;
  message?: string;
  entry?: { status_id?: number; [key: string]: unknown };
  error?: string;
}

export interface ApproveStatusParams {
  status_ok?: boolean;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * GET /api/status/
 * Mirrors api/endpoints/status_endpoints.R:27 (handler `@get /`).
 *
 * Returns the entity-status overview list, optionally filtered by approval.
 */
export async function listStatus(
  params: ListStatusParams = {},
  config?: AxiosRequestConfig
): Promise<StatusListRow[]> {
  return apiClient.get<StatusListRow[]>('/api/status/', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * GET /api/status/<status_id_requested>
 * Mirrors api/endpoints/status_endpoints.R:169 (handler `@get /<status_id_requested>`).
 *
 * Returns the status row(s) for the requested ID. Comma-separated IDs are
 * accepted server-side.
 */
export async function getStatusById(
  status_id_requested: number | string,
  config?: AxiosRequestConfig
): Promise<StatusByIdRow[]> {
  const path = `/api/status/${encodeURIComponent(String(status_id_requested))}`;
  return apiClient.get<StatusByIdRow[]>(path, config);
}

/**
 * GET /api/status/_list
 * Mirrors api/endpoints/status_endpoints.R:229 (handler `@get _list`).
 *
 * Returns the paginated status-category list (used by category dropdowns).
 */
export async function listStatusCategories(
  params: StatusCategoriesParams = {},
  config?: AxiosRequestConfig
): Promise<StatusCategoriesResponse> {
  return apiClient.get<StatusCategoriesResponse>('/api/status/_list', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * POST /api/status/create
 * Mirrors api/endpoints/status_endpoints.R:263 (handler `@post /create`).
 *
 * Reviewer+ only. Creates a new status entry for the entity.
 */
export async function createStatus(
  body: StatusMutationRequest,
  params: StatusMutationParams = {},
  config?: AxiosRequestConfig
): Promise<StatusMutationResponse> {
  return apiClient.post<StatusMutationResponse, StatusMutationRequest>('/api/status/create', body, {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * PUT /api/status/update
 * Mirrors api/endpoints/status_endpoints.R:263 (handler `@put /update`, same fn as @post /create).
 *
 * Reviewer+ only. Updates an existing status row.
 */
export async function updateStatus(
  body: StatusMutationRequest,
  params: StatusMutationParams = {},
  config?: AxiosRequestConfig
): Promise<StatusMutationResponse> {
  return apiClient.put<StatusMutationResponse, StatusMutationRequest>('/api/status/update', body, {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * PUT /api/status/approve/<status_id_requested>
 * Mirrors api/endpoints/status_endpoints.R:295 (handler `@put /approve/<status_id_requested>`).
 *
 * Curator+ only. Approves or unapproves a status row.
 */
export async function approveStatus(
  status_id_requested: number | string,
  params: ApproveStatusParams = {},
  config?: AxiosRequestConfig
): Promise<StatusMutationResponse> {
  const path = `/api/status/approve/${encodeURIComponent(String(status_id_requested))}`;
  return apiClient.put<StatusMutationResponse>(path, undefined, {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}
