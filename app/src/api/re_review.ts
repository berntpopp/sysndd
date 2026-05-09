// app/src/api/re_review.ts
//
// Re-review resource helpers (batched re-review workflow + assignment).
//
// Mirrors api/endpoints/re_review_endpoints.R (mounted at /api/re_review).
// Phase E.E2: filled during v11.1 Wave 1a (W3).
//
// Used by `ManageReReview.vue` and the curator-side re-review flows.

import type { AxiosRequestConfig } from 'axios';
import { apiClient } from './client';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface SubmitReReviewRequest {
  submit_json: {
    re_review_entity_id: number | string;
    [field: string]: unknown;
  };
}

export interface ApproveReReviewParams {
  /** R coerces "TRUE"/"FALSE". */
  status_ok?: boolean;
  review_ok?: boolean;
}

export interface ApproveReReviewResponse {
  message: string;
}

export interface ReReviewTableParams {
  filter?: string;
  curate?: boolean;
  page_after?: string | number;
  page_size?: string;
}

/**
 * One row of the re-review overview table. Keys are dynamic — common columns
 * include `re_review_entity_id`, `re_review_batch`, `entity_id`, `symbol`,
 * `disease_ontology_name`, `category`, `synopsis`, `comment`,
 * `re_review_submitted`, `re_review_approved`.
 */
export type ReReviewTableRow = Record<string, unknown>;

export interface AssignBatchParams {
  user_id: number | string;
}

export interface AssignBatchResponse {
  message: string;
  batch_number: number;
  entity_count: number;
  error?: string;
}

export interface UnassignBatchParams {
  re_review_batch: number | string;
}

export interface AssignmentTableParams {
  limit?: number;
  offset?: number;
}

export interface AssignmentRow {
  assignment_id: number;
  user_id: number;
  user_name: string;
  re_review_batch: number;
  re_review_review_saved: number;
  re_review_status_saved: number;
  re_review_submitted: number;
  re_review_approved: number;
  entity_count: number;
}

// Batch management types

export interface BatchCriteria {
  date_range?: { start: string; end: string };
  gene_list?: number[];
  status_filter?: number;
  disease_id?: string;
  /** Defaults to 20 server-side. */
  batch_size?: number;
  entity_ids?: number[];
}

export interface CreateBatchRequest extends BatchCriteria {
  assigned_user_id?: number;
  batch_name?: string;
}

/**
 * Service-layer envelope used by `batch_*` repository functions:
 * `{ status, message, entry?, ... }`.
 */
export interface BatchServiceResponse {
  status: number;
  message?: string;
  entry?: Record<string, unknown>;
  error?: string;
  [key: string]: unknown;
}

export interface ReassignBatchParams {
  re_review_batch: number | string;
  user_id: number | string;
}

export interface ArchiveBatchParams {
  re_review_batch: number | string;
}

export interface AssignEntitiesRequest {
  entity_ids: number[];
  user_id: number;
  batch_name?: string;
}

export interface RecalculateBatchRequest extends BatchCriteria {
  re_review_batch: number;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * PUT /api/re_review/submit
 * Mirrors api/endpoints/re_review_endpoints.R:29 (handler `@put submit`).
 *
 * Reviewer+ only. Updates a re-review entity row dynamically — the body
 * fields under `submit_json` map directly onto column-name=value pairs.
 */
export async function submitReReview(
  body: SubmitReReviewRequest,
  config?: AxiosRequestConfig
): Promise<unknown> {
  return apiClient.put<unknown, SubmitReReviewRequest>('/api/re_review/submit', body, config);
}

/**
 * PUT /api/re_review/unsubmit/<re_review_id>
 * Mirrors api/endpoints/re_review_endpoints.R:62 (handler `@put unsubmit/<re_review_id>`).
 *
 * Curator+ only. Reverts a re-review entry back to the unsubmitted state.
 */
export async function unsubmitReReview(
  re_review_id: number | string,
  config?: AxiosRequestConfig
): Promise<unknown> {
  const path = `/api/re_review/unsubmit/${encodeURIComponent(String(re_review_id))}`;
  return apiClient.put<unknown>(path, undefined, config);
}

/**
 * PUT /api/re_review/approve/<re_review_id>
 * Mirrors api/endpoints/re_review_endpoints.R:93 (handler `@put approve/<re_review_id>`).
 *
 * Curator+ only. Approves the re-review entry's status and/or review halves.
 *
 * Throws AxiosError on non-2xx (404 record not found).
 */
export async function approveReReview(
  re_review_id: number | string,
  params: ApproveReReviewParams = {},
  config?: AxiosRequestConfig
): Promise<ApproveReReviewResponse> {
  const path = `/api/re_review/approve/${encodeURIComponent(String(re_review_id))}`;
  return apiClient.put<ApproveReReviewResponse>(path, undefined, {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * GET /api/re_review/table
 * Mirrors api/endpoints/re_review_endpoints.R:148 (handler `@get table`).
 *
 * Returns the role-scoped re-review overview table. Curators see all batches
 * via `curate=true`; reviewers see only their unsubmitted entries (curate
 * defaults to FALSE).
 */
export async function getReReviewTable(
  params: ReReviewTableParams = {},
  config?: AxiosRequestConfig
): Promise<ReReviewTableRow[]> {
  return apiClient.get<ReReviewTableRow[]>('/api/re_review/table', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * GET /api/re_review/batch/apply
 * Mirrors api/endpoints/re_review_endpoints.R:278 (handler `@get batch/apply`).
 *
 * Reviewer+ only. Sends an email asking for a new re-review batch
 * assignment. Returns the email-send transport result.
 */
export async function applyForReReviewBatch(config?: AxiosRequestConfig): Promise<unknown> {
  return apiClient.get<unknown>('/api/re_review/batch/apply', config);
}

/**
 * PUT /api/re_review/batch/assign
 * Mirrors api/endpoints/re_review_endpoints.R:332 (handler `@put batch/assign`).
 *
 * Curator+ only. Assigns the next available batch to the specified user.
 *
 * Throws AxiosError on non-2xx (409 user does not exist or no batches).
 */
export async function assignReReviewBatch(
  params: AssignBatchParams,
  config?: AxiosRequestConfig
): Promise<AssignBatchResponse> {
  return apiClient.put<AssignBatchResponse>('/api/re_review/batch/assign', undefined, {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * DELETE /api/re_review/batch/unassign
 * Mirrors api/endpoints/re_review_endpoints.R:432 (handler `@delete batch/unassign`).
 *
 * Curator+ only. Removes a batch assignment.
 *
 * Throws AxiosError on non-2xx (409 batch does not exist).
 */
export async function unassignReReviewBatch(
  params: UnassignBatchParams,
  config?: AxiosRequestConfig
): Promise<unknown> {
  return apiClient.delete<unknown>('/api/re_review/batch/unassign', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * GET /api/re_review/assignment_table
 * Mirrors api/endpoints/re_review_endpoints.R:475 (handler `@get assignment_table`).
 *
 * Curator+ only. Returns aggregate batch-assignment statistics.
 */
export async function getAssignmentTable(
  params: AssignmentTableParams = {},
  config?: AxiosRequestConfig
): Promise<AssignmentRow[]> {
  return apiClient.get<AssignmentRow[]>('/api/re_review/assignment_table', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * POST /api/re_review/batch/create
 * Mirrors api/endpoints/re_review_endpoints.R:538 (handler `@post batch/create`).
 *
 * Curator+ only. Creates a batch from arbitrary criteria, optionally
 * assigning to a user.
 */
export async function createReReviewBatch(
  body: CreateBatchRequest,
  config?: AxiosRequestConfig
): Promise<BatchServiceResponse> {
  return apiClient.post<BatchServiceResponse, CreateBatchRequest>(
    '/api/re_review/batch/create',
    body,
    config
  );
}

/**
 * POST /api/re_review/batch/preview
 * Mirrors api/endpoints/re_review_endpoints.R:575 (handler `@post batch/preview`).
 *
 * Curator+ only. Returns the entities that would match the criteria without
 * creating a batch.
 */
export async function previewReReviewBatch(
  body: BatchCriteria,
  config?: AxiosRequestConfig
): Promise<BatchServiceResponse> {
  return apiClient.post<BatchServiceResponse, BatchCriteria>(
    '/api/re_review/batch/preview',
    body,
    config
  );
}

/**
 * PUT /api/re_review/batch/reassign
 * Mirrors api/endpoints/re_review_endpoints.R:610 (handler `@put batch/reassign`).
 *
 * Curator+ only. Reassigns an existing batch to a different user.
 */
export async function reassignReReviewBatch(
  params: ReassignBatchParams,
  config?: AxiosRequestConfig
): Promise<BatchServiceResponse> {
  return apiClient.put<BatchServiceResponse>('/api/re_review/batch/reassign', undefined, {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * PUT /api/re_review/batch/archive
 * Mirrors api/endpoints/re_review_endpoints.R:637 (handler `@put batch/archive`).
 *
 * Curator+ only. Archives (soft-deletes) the batch assignment.
 */
export async function archiveReReviewBatch(
  params: ArchiveBatchParams,
  config?: AxiosRequestConfig
): Promise<BatchServiceResponse> {
  return apiClient.put<BatchServiceResponse>('/api/re_review/batch/archive', undefined, {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * PUT /api/re_review/entities/assign
 * Mirrors api/endpoints/re_review_endpoints.R:661 (handler `@put entities/assign`).
 *
 * Curator+ only. Creates a batch containing only the specified entities and
 * assigns it to a user.
 *
 * Throws AxiosError on non-2xx (400 missing/empty entity_ids or user_id).
 */
export async function assignReReviewEntities(
  body: AssignEntitiesRequest,
  config?: AxiosRequestConfig
): Promise<BatchServiceResponse> {
  return apiClient.put<BatchServiceResponse, AssignEntitiesRequest>(
    '/api/re_review/entities/assign',
    body,
    config
  );
}

/**
 * PUT /api/re_review/batch/recalculate
 * Mirrors api/endpoints/re_review_endpoints.R:699 (handler `@put batch/recalculate`).
 *
 * Curator+ only. Recomputes batch entity membership against new criteria
 * (only allowed for unassigned batches).
 *
 * Throws AxiosError on non-2xx (400 missing re_review_batch).
 */
export async function recalculateReReviewBatch(
  body: RecalculateBatchRequest,
  config?: AxiosRequestConfig
): Promise<BatchServiceResponse> {
  return apiClient.put<BatchServiceResponse, RecalculateBatchRequest>(
    '/api/re_review/batch/recalculate',
    body,
    config
  );
}
