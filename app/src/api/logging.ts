// app/src/api/logging.ts
//
// Logging resource helpers — admin log query / export / purge.
//
// Mirrors api/endpoints/logging_endpoints.R (mounted at /api/logs).
// Phase E.E2: filled during v11.1 Wave 1a (W3).
//
// Both endpoints require Administrator role; auth is supplied by the
// `apiClient` interceptor.

import type { AxiosRequestConfig } from 'axios';
import { apiClient } from './client';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type LoggingFormat = 'json' | 'xlsx';

export interface ListLogsParams {
  /** Default `"id"`. Prefix with `-` for DESC. */
  sort?: string;
  filter?: string;
  fields?: string;
  page_after?: string | number;
  page_size?: string | number;
  fspec?: string;
  format?: LoggingFormat;
}

/**
 * One log row from `GET /api/logs/`. Keys are dynamic (driven by `fields`).
 * Common columns: `id`, `timestamp`, `address`, `agent`, `host`,
 * `request_method`, `path`, `query`, `post`, `status`, `duration`, `file`,
 * `modified`.
 */
export type LogEntry = Record<string, unknown>;

export interface LogListResponse {
  links: unknown;
  meta: unknown;
  data: LogEntry[];
}

export interface DeleteLogsParams {
  /** Optional. 0 / omitted ⇒ delete all logs. */
  older_than_days?: number;
}

export interface DeleteLogsResponse {
  message: string;
  deleted_count: number;
  cutoff_date?: string;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * GET /api/logs/
 * Mirrors api/endpoints/logging_endpoints.R:65 (handler `@get /`).
 *
 * Administrator-only. Returns the cursor-paginated log envelope when
 * `format=json`. Use `listLogsXlsx()` for the binary export path.
 *
 * Throws AxiosError on non-2xx (400 INVALID_FILTER, 403 not Administrator,
 * 500 DB failure).
 */
export async function listLogs(
  params: ListLogsParams = {},
  config?: AxiosRequestConfig
): Promise<LogListResponse> {
  return apiClient.get<LogListResponse>('/api/logs/', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params, format: 'json' },
  });
}

/**
 * GET /api/logs/?format=xlsx
 *
 * Same handler as `listLogs`, but surfaces the XLSX byte stream as a `Blob`.
 */
export async function listLogsXlsx(
  params: Omit<ListLogsParams, 'format'> = {},
  config?: AxiosRequestConfig
): Promise<Blob> {
  const response = await apiClient.raw.get<Blob>('/api/logs/', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params, format: 'xlsx' },
    responseType: 'blob',
  });
  return response.data;
}

/**
 * DELETE /api/logs/
 * Mirrors api/endpoints/logging_endpoints.R:198 (handler `@delete /`).
 *
 * Administrator-only. Purges logs. Pass `older_than_days` to retain recent
 * entries; omit (or 0) to wipe everything.
 *
 * Throws AxiosError on non-2xx (403 not Administrator, 500 DB failure).
 */
export async function deleteLogs(
  params: DeleteLogsParams = {},
  config?: AxiosRequestConfig
): Promise<DeleteLogsResponse> {
  return apiClient.delete<DeleteLogsResponse>('/api/logs/', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}
