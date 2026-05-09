// app/src/api/admin.ts
//
// Administrator-only resource helpers.
//
// Mirrors api/endpoints/admin_endpoints.R (mounted at /api/admin).
// Phase E.E2: filled during v11.1 Wave 1a (W3).
//
// Most endpoints are gated by `require_role(req, res, "Administrator")`. The
// typed client does not model auth — `apiClient` injects the bearer token via
// the request interceptor. Callers see 401/403 as `AxiosError` and route them
// through `useAuth.handle401()` (W2).
//
// Async endpoints (`update_ontology_async`, `force_apply_ontology`,
// `publications/refresh`) accept the request and return `{ job_id, status,
// message? }` — callers poll `GET /api/jobs/<job_id>/status` (see `jobs.ts`)
// to consume the result.

import type { AxiosRequestConfig } from 'axios';
import { apiClient } from './client';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/**
 * Common envelope returned by async-job submission endpoints.
 * `status` discriminates between fresh submissions (`"accepted"`) and
 * de-duplication hits (`"already_running"`).
 */
export interface AsyncJobAccepted {
  job_id: string;
  status: 'accepted' | 'already_running';
  message?: string;
  estimated_seconds?: number;
}

/**
 * Response from `GET /api/admin/api_version`.
 */
export interface AdminApiVersion {
  api_version: string;
}

/**
 * Response from `GET /api/admin/annotation_dates`. Each field is the most
 * recent successful run timestamp (ISO 8601) or `null` when the source has
 * never been run.
 */
export interface AnnotationDates {
  omim_update: string | null;
  mondo_update: string | null;
  hgnc_update: string | null;
  disease_ontology_update: string | null;
}

/**
 * One entity in the `deprecated_entities` response. Mirrors the columns
 * `affected_enriched` selects in the R handler.
 */
export interface DeprecatedEntity {
  entity_id: number;
  symbol: string;
  hgnc_id: string;
  disease_ontology_id: string;
  disease_ontology_id_version: string;
  disease_ontology_name: string;
  category: string;
  ndd_phenotype: number | string | null;
  mondo_id: string | null;
  mondo_label: string | null;
  deprecation_reason: string | null;
  replacement_mondo_id: string | null;
  replacement_mondo_label: string | null;
  replacement_omim_id: string | null;
}

/**
 * Response from `GET /api/admin/deprecated_entities`.
 */
export interface DeprecatedEntitiesResponse {
  deprecated_count: number;
  affected_entity_count: number;
  affected_entities: DeprecatedEntity[];
  mim2gene_date: string | null;
  message?: string;
}

/**
 * Response from `GET /api/admin/smtp/test`.
 */
export interface SmtpTestResponse {
  success: boolean;
  host: string;
  port: number;
  error: string | null;
}

/**
 * Body for `POST /api/admin/publications/refresh`.
 *
 * - `pmids`: explicit list to refresh.
 * - `not_updated_since`: ISO date (`YYYY-MM-DD`) to refresh everything older than that timestamp.
 *
 * If both are omitted the endpoint returns 400.
 */
export interface PublicationRefreshRequest {
  pmids?: string[];
  not_updated_since?: string;
}

/**
 * Response from `POST /api/admin/publications/refresh` when there is nothing
 * to refresh — the handler short-circuits with 200 and a `{ message, count }`
 * shape instead of returning a job envelope.
 */
export interface PublicationRefreshNoop {
  message: string;
  filter_date?: string;
  count: 0;
}

/**
 * Body for `PUT /api/admin/force_apply_ontology`.
 *
 * `blocked_job_id` is mandatory; `assigned_user_id` defaults to the requester
 * when omitted.
 */
export interface ForceApplyOntologyParams {
  blocked_job_id: string;
  assigned_user_id?: number;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * GET /api/admin/openapi.json
 * Mirrors api/endpoints/admin_endpoints.R:32 (handler `@get /openapi.json`).
 *
 * Returns the enhanced OpenAPI specification used by the Swagger UI.
 */
export async function getOpenApiSpec(config?: AxiosRequestConfig): Promise<unknown> {
  return apiClient.get<unknown>('/api/admin/openapi.json', config);
}

/**
 * PUT /api/admin/update_ontology_async
 * Mirrors api/endpoints/admin_endpoints.R:86 (handler `@put update_ontology_async`).
 *
 * Submits an async OMIM / disease-ontology update. Returns 202 with
 * `{ job_id, status: 'accepted' }` on a fresh submission, or
 * `{ job_id, status: 'already_running' }` on dedup. The job result on
 * `GET /api/jobs/<job_id>/status` may itself be a `"blocked"` outcome —
 * callers handle that via the force-apply flow below.
 *
 * Throws AxiosError on non-2xx (401/403, or 503 worker-pool capacity).
 */
export async function updateOntologyAsync(config?: AxiosRequestConfig): Promise<AsyncJobAccepted> {
  return apiClient.put<AsyncJobAccepted>('/api/admin/update_ontology_async', undefined, config);
}

/**
 * PUT /api/admin/force_apply_ontology
 * Mirrors api/endpoints/admin_endpoints.R:297 (handler `@put force_apply_ontology`).
 *
 * Force-applies a previously-blocked ontology update referenced by
 * `blocked_job_id`. Returns 202 with the new force-apply job's job_id.
 *
 * Throws AxiosError on non-2xx (404 if blocked_job_id unknown, 409 if the
 * referenced job was not blocked, 410 if the pending CSV expired or is
 * older than 48 hours).
 */
export async function forceApplyOntology(
  params: ForceApplyOntologyParams,
  config?: AxiosRequestConfig
): Promise<AsyncJobAccepted> {
  return apiClient.put<AsyncJobAccepted>('/api/admin/force_apply_ontology', undefined, {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * PUT /api/admin/update_hgnc_data
 * Mirrors api/endpoints/admin_endpoints.R:601 (handler `@put update_hgnc_data`).
 *
 * Synchronously updates HGNC data and refreshes the `non_alt_loci_set` table.
 * This is a long-running operation (the handler streams progress to the
 * server but the response only arrives after the whole process completes).
 *
 * Throws AxiosError on non-2xx (500 with `{ error, details }` on transaction
 * failure).
 */
export async function updateHgncData(
  config?: AxiosRequestConfig
): Promise<{ status: string; message: string }> {
  return apiClient.put<{ status: string; message: string }>(
    '/api/admin/update_hgnc_data',
    undefined,
    config
  );
}

/**
 * GET /api/admin/api_version
 * Mirrors api/endpoints/admin_endpoints.R:669 (handler `@get api_version`).
 *
 * Public — no auth. Returns the API version (informational).
 */
export async function getApiVersion(config?: AxiosRequestConfig): Promise<AdminApiVersion> {
  return apiClient.get<AdminApiVersion>('/api/admin/api_version', config);
}

/**
 * GET /api/admin/annotation_dates
 * Mirrors api/endpoints/admin_endpoints.R:686 (handler `@get annotation_dates`).
 *
 * Returns the most recent successful run timestamps for OMIM, MONDO, HGNC,
 * and disease-ontology updates. Falls back to file-modification times on
 * fresh installs.
 */
export async function getAnnotationDates(config?: AxiosRequestConfig): Promise<AnnotationDates> {
  return apiClient.get<AnnotationDates>('/api/admin/annotation_dates', config);
}

/**
 * GET /api/admin/deprecated_entities
 * Mirrors api/endpoints/admin_endpoints.R:786 (handler `@get deprecated_entities`).
 *
 * Returns the entities that reference deprecated OMIM ids (per the latest
 * mim2gene.txt) enriched with MONDO / OLS replacement suggestions.
 */
export async function getDeprecatedEntities(
  config?: AxiosRequestConfig
): Promise<DeprecatedEntitiesResponse> {
  return apiClient.get<DeprecatedEntitiesResponse>('/api/admin/deprecated_entities', config);
}

/**
 * GET /api/admin/smtp/test
 * Mirrors api/endpoints/admin_endpoints.R:940 (handler `@get /smtp/test`).
 *
 * Probes the configured SMTP server with a socket connection. Does not send
 * any email. Returns success/failure plus error message.
 */
export async function testSmtp(config?: AxiosRequestConfig): Promise<SmtpTestResponse> {
  return apiClient.get<SmtpTestResponse>('/api/admin/smtp/test', config);
}

/**
 * POST /api/admin/publications/refresh
 * Mirrors api/endpoints/admin_endpoints.R:1010 (handler `@post /publications/refresh`).
 *
 * Submits an async PubMed refresh job. The response is either:
 *   - 202 + AsyncJobAccepted (fresh submission or dedup hit), or
 *   - 200 + PublicationRefreshNoop when nothing matches the filter.
 *
 * Throws AxiosError on non-2xx (400 missing pmids/date filter; invalid date format).
 */
export async function refreshPublications(
  body: PublicationRefreshRequest,
  config?: AxiosRequestConfig
): Promise<AsyncJobAccepted | PublicationRefreshNoop> {
  return apiClient.post<AsyncJobAccepted | PublicationRefreshNoop, PublicationRefreshRequest>(
    '/api/admin/publications/refresh',
    body,
    config
  );
}
