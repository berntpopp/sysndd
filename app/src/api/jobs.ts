// app/src/api/jobs.ts
//
// Async job submission + status polling resource helpers.
//
// Mirrors api/endpoints/jobs_endpoints.R (mounted at /api/jobs).
// Phase E.E2: filled during v11.1 Wave 1a (W3).
//
// All submission endpoints follow the same pattern: POST returns 202 with
// `{ job_id, status, estimated_seconds, status_url }` and a `Location`
// header pointing at the status endpoint. Submission may also return 409
// (DUPLICATE_JOB) with the existing job's id, or 503 (capacity exceeded).
//
// `useAsyncJob` (in `app/src/composables/`) consumes these helpers — see
// also `unwrapScalar` in `client.ts` for callers that need to peel the
// `@serializer json list(auto_unbox=TRUE)` shape on the status endpoint.

import type { AxiosRequestConfig } from 'axios';
import { apiClient } from './client';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/**
 * Common 202 response from every submission endpoint.
 */
export interface JobSubmissionResponse {
  job_id: string;
  status: 'accepted' | string;
  estimated_seconds?: number;
  status_url: string;
}

/**
 * Common 409 response when an identical job is already running.
 */
export interface DuplicateJobResponse {
  error: 'DUPLICATE_JOB' | string;
  message: string;
  existing_job_id: string;
  status_url: string;
}

/**
 * Body for `POST /api/jobs/clustering/submit`.
 */
export interface ClusteringSubmissionRequest {
  /** HGNC ids; if omitted the server uses all NDD genes. */
  genes?: string[];
  /** Defaults to "leiden"; "walktrap" is the legacy alternative. */
  algorithm?: 'leiden' | 'walktrap';
}

/**
 * Job-history row from `GET /api/jobs/history`.
 */
export interface JobHistoryEntry {
  job_id: string;
  operation: string;
  status: 'pending' | 'running' | 'completed' | 'failed' | 'blocked' | string;
  submitted_at: string;
  completed_at: string | null;
  duration_seconds: number | null;
  error_message: string | null;
}

export interface JobHistoryResponse {
  data: JobHistoryEntry[];
  meta: { count: number; limit: number };
}

/**
 * Wire shape of `GET /api/jobs/<job_id>/status`. The handler uses
 * `@serializer json list(auto_unbox=TRUE)`, so scalars don't need
 * `unwrapScalar`. `result` is the executor's return value when status is
 * `"completed"`; consult the operation-specific docs for its inner shape.
 */
export interface JobStatusResponse {
  job_id: string;
  status: 'pending' | 'running' | 'completed' | 'failed' | 'blocked' | string;
  operation?: string;
  submitted_at?: string;
  started_at?: string | null;
  completed_at?: string | null;
  progress?: {
    step?: string;
    message?: string;
    current?: number;
    total?: number;
    [key: string]: unknown;
  };
  /** Present only when `status === "completed"`. Shape varies by operation. */
  result?: unknown;
  error?: string;
  error_message?: string;
  retry_after?: number;
  [key: string]: unknown;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * POST /api/jobs/clustering/submit
 * Mirrors api/endpoints/jobs_endpoints.R:28 (handler `@post /clustering/submit`).
 *
 * Submits an async functional-clustering job. Returns 202 on success, 409
 * with `DuplicateJobResponse` if an identical job is already running, 503
 * on capacity exceeded.
 *
 * Throws AxiosError on non-2xx — callers wanting to branch on 409 should
 * `try/catch` and inspect `err.response?.status`.
 */
export async function submitClustering(
  body: ClusteringSubmissionRequest = {},
  config?: AxiosRequestConfig
): Promise<JobSubmissionResponse> {
  return apiClient.post<JobSubmissionResponse, ClusteringSubmissionRequest>(
    '/api/jobs/clustering/submit',
    body,
    config
  );
}

/**
 * POST /api/jobs/phenotype_clustering/submit
 * Mirrors api/endpoints/jobs_endpoints.R:271 (handler `@post /phenotype_clustering/submit`).
 *
 * Submits an async phenotype-clustering (MCA) job. No request body required —
 * the server pulls the relevant data from the DB itself.
 */
export async function submitPhenotypeClustering(
  config?: AxiosRequestConfig
): Promise<JobSubmissionResponse> {
  return apiClient.post<JobSubmissionResponse>(
    '/api/jobs/phenotype_clustering/submit',
    undefined,
    config
  );
}

/**
 * POST /api/jobs/ontology_update/submit
 * Mirrors api/endpoints/jobs_endpoints.R:523 (handler `@post /ontology_update/submit`).
 *
 * Administrator-only. Submits the MONDO+OMIM ontology refresh as an async
 * job. Note the live admin endpoint `PUT /api/admin/update_ontology_async`
 * is the modern replacement which adds the safeguard/blocked workflow —
 * this `/jobs/...` variant remains for parity with the rest of the jobs
 * surface.
 */
export async function submitOntologyUpdate(
  config?: AxiosRequestConfig
): Promise<JobSubmissionResponse> {
  return apiClient.post<JobSubmissionResponse>(
    '/api/jobs/ontology_update/submit',
    undefined,
    config
  );
}

/**
 * POST /api/jobs/hgnc_update/submit
 * Mirrors api/endpoints/jobs_endpoints.R:621 (handler `@post /hgnc_update/submit`).
 *
 * Administrator-only. Submits the HGNC data refresh as an async job.
 */
export async function submitHgncUpdate(
  config?: AxiosRequestConfig
): Promise<JobSubmissionResponse> {
  return apiClient.post<JobSubmissionResponse>('/api/jobs/hgnc_update/submit', undefined, config);
}

/**
 * POST /api/jobs/comparisons_update/submit
 * Mirrors api/endpoints/jobs_endpoints.R:817 (handler `@post /comparisons_update/submit`).
 *
 * Administrator-only. Refreshes the cross-database comparisons table.
 */
export async function submitComparisonsUpdate(
  config?: AxiosRequestConfig
): Promise<JobSubmissionResponse> {
  return apiClient.post<JobSubmissionResponse>(
    '/api/jobs/comparisons_update/submit',
    undefined,
    config
  );
}

export interface JobHistoryParams {
  /** Default 20, clamped to [1, 100]. */
  limit?: number;
}

/**
 * GET /api/jobs/history
 * Mirrors api/endpoints/jobs_endpoints.R:890 (handler `@get /history`).
 *
 * Administrator-only. Returns recent jobs for admin review.
 */
export async function getJobHistory(
  params: JobHistoryParams = {},
  config?: AxiosRequestConfig
): Promise<JobHistoryResponse> {
  return apiClient.get<JobHistoryResponse>('/api/jobs/history', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * GET /api/jobs/<job_id>/status
 * Mirrors api/endpoints/jobs_endpoints.R:942 (handler `@get /<job_id>/status`).
 *
 * Polls the status of an async job. Returns 200 with the status envelope
 * when found, 404 when the job_id is unknown or expired.
 *
 * The handler uses `@serializer json list(auto_unbox=TRUE)` so scalar fields
 * arrive unwrapped. Throws AxiosError on non-2xx; callers map 404 to "expired".
 */
export async function getJobStatus(
  job_id: string,
  config?: AxiosRequestConfig
): Promise<JobStatusResponse> {
  const path = `/api/jobs/${encodeURIComponent(job_id)}/status`;
  return apiClient.get<JobStatusResponse>(path, config);
}
