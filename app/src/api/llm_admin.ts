// app/src/api/llm_admin.ts
//
// LLM administration resource helpers.
//
// Mirrors api/endpoints/llm_admin_endpoints.R (mounted at /api/llm).
// Phase E.E2: filled during v11.1 Wave 1a (W3).
//
// All endpoints require Administrator role; auth is supplied by the
// `apiClient` interceptor.

import type { AxiosRequestConfig } from 'axios';
import { apiClient } from './client';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface LlmModelInfo {
  model_id: string;
  display_name: string;
  description: string;
  rpm_limit: number | null;
  rpd_limit: number | null;
  recommended_for: string;
  status?: string;
  allowed?: boolean;
  default?: boolean;
  operator_allowed?: boolean;
  shutdown_date?: string | null;
}

export interface LlmRateLimit {
  capacity?: number;
  fill_time_s?: number;
  [key: string]: unknown;
}

export interface LlmConfig {
  gemini_configured: boolean;
  current_model: string;
  source: 'env' | 'config' | 'default' | string;
  default_model: string;
  valid: boolean;
  operator_allowed: boolean;
  warning: string | null;
  available_models: LlmModelInfo[];
  rate_limit: LlmRateLimit;
}

export interface UpdateLlmModelParams {
  /** Required body field. */
  model: string;
}

export interface UpdateLlmModelResponse {
  success: boolean;
  message: string;
  model: string;
}

export interface LlmCacheStats {
  total_entries: number;
  by_status: { pending?: number; validated?: number; rejected?: number };
  by_type: { functional?: number; phenotype?: number };
  last_generation: string | null;
  total_tokens_input: number;
  total_tokens_output: number;
  estimated_cost_usd: number;
  [key: string]: unknown;
}

export interface CacheSummariesParams {
  cluster_type?: 'functional' | 'phenotype' | '';
  validation_status?: 'pending' | 'validated' | 'rejected' | '';
  page?: number;
  per_page?: number;
  /** D5 alias for `per_page`. */
  limit?: number;
  /** D5 alias for `(page-1) * per_page`. */
  offset?: number;
}

export type CacheSummaryRow = Record<string, unknown>;

export interface PaginatedCacheSummaries {
  data: CacheSummaryRow[];
  total: number;
  page: number;
  per_page: number;
}

export interface ClearLlmCacheParams {
  cluster_type?: 'all' | 'functional' | 'phenotype';
}

export interface ClearLlmCacheResponse {
  success: boolean;
  message: string;
  cleared_count: number;
}

export interface RegenerateLlmParams {
  cluster_type?: 'all' | 'functional' | 'phenotype';
  /** R coerces "true"/"false" via as.logical. */
  force?: boolean | string;
}

export interface RegenerateLlmResponse {
  job_id: string;
  status: 'accepted';
  status_url: string;
  cluster_types: string[];
  results: Record<string, unknown>;
}

export interface LogQueryParams {
  cluster_type?: 'functional' | 'phenotype' | '';
  status?: 'success' | 'validation_failed' | 'api_error' | 'timeout' | '';
  from_date?: string;
  to_date?: string;
  page?: number;
  per_page?: number;
  limit?: number;
  offset?: number;
}

export type LogRow = Record<string, unknown>;

export interface PaginatedLogs {
  data: LogRow[];
  total: number;
  page: number;
  per_page: number;
}

export interface ValidateCacheParams {
  /** Required body or query — `validate` keeps, `reject` flags as bad. */
  action: 'validate' | 'reject';
}

export interface ValidateCacheResponse {
  success: boolean;
  message: string;
  cache_id: number;
  validation_status: 'validated' | 'rejected';
}

export type LlmPromptType =
  | 'functional_generation'
  | 'functional_judge'
  | 'phenotype_generation'
  | 'phenotype_judge';

export interface LlmPromptTemplate {
  template_id: number | null;
  prompt_type: LlmPromptType;
  version: string;
  template_text: string;
  description: string | null;
}

export type LlmPromptTemplateMap = Record<LlmPromptType | string, LlmPromptTemplate>;

export interface UpdateLlmPromptRequest {
  template: string;
  version: string;
  description?: string;
}

export interface UpdateLlmPromptResponse {
  success: boolean;
  message: string;
  type: string;
  version: string;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * GET /api/llm/config
 * Mirrors api/endpoints/llm_admin_endpoints.R:44 (handler `@get /config`).
 *
 * Administrator-only. Returns the current LLM configuration including
 * available models and rate-limit settings.
 */
export async function getLlmConfig(config?: AxiosRequestConfig): Promise<LlmConfig> {
  return apiClient.get<LlmConfig>('/api/llm/config', config);
}

/**
 * PUT /api/llm/config
 * Mirrors api/endpoints/llm_admin_endpoints.R:138 (handler `@put /config`).
 *
 * Administrator-only. Switches the active Gemini model. The handler reads
 * `model` as a query parameter (R signature: `function(req, res, model)`),
 * so the helper passes it via `config.params`.
 *
 * Throws AxiosError on non-2xx (400 invalid model).
 */
export async function updateLlmModel(
  params: UpdateLlmModelParams,
  config?: AxiosRequestConfig
): Promise<UpdateLlmModelResponse> {
  return apiClient.put<UpdateLlmModelResponse>('/api/llm/config', undefined, {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * GET /api/llm/cache/stats
 * Mirrors api/endpoints/llm_admin_endpoints.R:188 (handler `@get /cache/stats`).
 *
 * Administrator-only. Aggregate cache statistics for the admin dashboard.
 */
export async function getLlmCacheStats(config?: AxiosRequestConfig): Promise<LlmCacheStats> {
  return apiClient.get<LlmCacheStats>('/api/llm/cache/stats', config);
}

/**
 * GET /api/llm/cache/summaries
 * Mirrors api/endpoints/llm_admin_endpoints.R:223 (handler `@get /cache/summaries`).
 *
 * Administrator-only. Paginated browse of cached summaries.
 */
export async function getLlmCacheSummaries(
  params: CacheSummariesParams = {},
  config?: AxiosRequestConfig
): Promise<PaginatedCacheSummaries> {
  return apiClient.get<PaginatedCacheSummaries>('/api/llm/cache/summaries', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * DELETE /api/llm/cache
 * Mirrors api/endpoints/llm_admin_endpoints.R:298 (handler `@delete /cache`).
 *
 * Administrator-only. Clears cached summaries (default `cluster_type: "all"`).
 *
 * Throws AxiosError on non-2xx (400 invalid cluster_type).
 */
export async function clearLlmCache(
  params: ClearLlmCacheParams = {},
  config?: AxiosRequestConfig
): Promise<ClearLlmCacheResponse> {
  return apiClient.delete<ClearLlmCacheResponse>('/api/llm/cache', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * POST /api/llm/regenerate
 * Mirrors api/endpoints/llm_admin_endpoints.R:351 (handler `@post /regenerate`).
 *
 * Administrator-only. Triggers async batch regeneration. Returns 202 with
 * a parent `job_id` plus per-type sub-results.
 *
 * Throws AxiosError on non-2xx (400 invalid cluster_type, 503 GEMINI_NOT_CONFIGURED).
 */
export async function regenerateLlm(
  params: RegenerateLlmParams = {},
  config?: AxiosRequestConfig
): Promise<RegenerateLlmResponse> {
  return apiClient.post<RegenerateLlmResponse>('/api/llm/regenerate', undefined, {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * GET /api/llm/logs
 * Mirrors api/endpoints/llm_admin_endpoints.R:550 (handler `@get /logs`).
 *
 * Administrator-only. Paginated generation logs with optional filters.
 */
export async function getLlmLogs(
  params: LogQueryParams = {},
  config?: AxiosRequestConfig
): Promise<PaginatedLogs> {
  return apiClient.get<PaginatedLogs>('/api/llm/logs', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * POST /api/llm/cache/<cache_id>/validate
 * Mirrors api/endpoints/llm_admin_endpoints.R:642 (handler `@post /cache/<cache_id>/validate`).
 *
 * Administrator-only. Marks the cache entry as validated or rejected. The
 * handler accepts `action` as a query param.
 */
export async function validateLlmCacheEntry(
  cache_id: number | string,
  params: ValidateCacheParams,
  config?: AxiosRequestConfig
): Promise<ValidateCacheResponse> {
  const path = `/api/llm/cache/${encodeURIComponent(String(cache_id))}/validate`;
  return apiClient.post<ValidateCacheResponse>(path, undefined, {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * GET /api/llm/prompts
 * Mirrors api/endpoints/llm_admin_endpoints.R:709 (handler `@get /prompts`).
 *
 * Administrator-only. Returns all prompt templates keyed by their type.
 */
export async function getLlmPrompts(config?: AxiosRequestConfig): Promise<LlmPromptTemplateMap> {
  return apiClient.get<LlmPromptTemplateMap>('/api/llm/prompts', config);
}

/**
 * PUT /api/llm/prompts/<type>
 * Mirrors api/endpoints/llm_admin_endpoints.R:746 (handler `@put /prompts/<type>`).
 *
 * Administrator-only. Submits a new version of the named prompt template.
 * The R handler currently logs the update without persisting; the helper
 * surfaces the success envelope it returns.
 *
 * Throws AxiosError on non-2xx (400 invalid type, missing template, missing
 * version).
 */
export async function updateLlmPrompt(
  type: LlmPromptType,
  body: UpdateLlmPromptRequest,
  config?: AxiosRequestConfig
): Promise<UpdateLlmPromptResponse> {
  const path = `/api/llm/prompts/${encodeURIComponent(type)}`;
  return apiClient.put<UpdateLlmPromptResponse, UpdateLlmPromptRequest>(path, body, config);
}
