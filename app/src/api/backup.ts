// app/src/api/backup.ts
//
// Backup management resource helpers.
//
// Mirrors api/endpoints/backup_endpoints.R (mounted at /api/backup).
// Phase E.E2: filled during v11.1 Wave 1a (W3).
//
// All endpoints require Administrator role; the typed client does not model
// auth — the bearer token is injected by `apiClient`.
//
// `GET /api/backup/download/<filename>` returns a binary stream — the helper
// uses `apiClient.raw.get<Blob>` and surfaces the underlying `Blob` so callers
// can wire up `file-saver` (or equivalent) without re-fetching.

import type { AxiosRequestConfig } from 'axios';
import { apiClient } from './client';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type BackupSortOrder = 'newest' | 'oldest';

export interface ListBackupsParams {
  /** Legacy page-based pagination (default 1). Ignored when `limit` is set. */
  page?: number;
  sort?: BackupSortOrder;
  /** New offset-based pagination (default 50, max 500). */
  limit?: number;
  /** Rows to skip with offset-based pagination (default 0). */
  offset?: number;
}

export interface BackupFile {
  filename: string;
  size_bytes: number;
  created_at: string;
  table_count?: number;
}

export interface BackupDirectoryMeta {
  total_count: number;
  total_size_bytes: number;
  [key: string]: unknown;
}

/**
 * Wire shape from `GET /api/backup/list`. Carries both legacy page-based
 * fields (`page`, `page_size`) and new offset-based fields (`limit`, `offset`).
 */
export interface BackupListResponse {
  data: BackupFile[];
  total: number;
  page: number;
  page_size: number;
  limit: number;
  offset: number;
  links: { next: string | null };
  meta: BackupDirectoryMeta;
}

export interface AsyncBackupJobAccepted {
  job_id: string;
  status: 'accepted';
  estimated_seconds: number;
  status_url: string;
}

export interface RestoreBackupRequest {
  filename: string;
}

export interface DeleteBackupRequest {
  /** Must be the literal string `"DELETE"`. */
  confirm: 'DELETE' | string;
}

export interface DeleteBackupResponse {
  success: boolean;
  message: string;
  deleted_file: string;
  deleted_size_bytes: number;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * GET /api/backup/list
 * Mirrors api/endpoints/backup_endpoints.R:50 (handler `@get /list`).
 *
 * Administrator-only. Returns a paginated list of backup files.
 * Throws AxiosError on non-2xx (400 invalid sort, 500 read failure).
 */
export async function listBackups(
  params: ListBackupsParams = {},
  config?: AxiosRequestConfig,
): Promise<BackupListResponse> {
  return apiClient.get<BackupListResponse>('/api/backup/list', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * POST /api/backup/create
 * Mirrors api/endpoints/backup_endpoints.R:168 (handler `@post /create`).
 *
 * Administrator-only. Submits an async backup job. Returns 202 with
 * `{ job_id, status: "accepted", estimated_seconds, status_url }`.
 *
 * Throws AxiosError on non-2xx (409 if a backup is already running,
 * 503 capacity exceeded).
 */
export async function createBackup(
  config?: AxiosRequestConfig,
): Promise<AsyncBackupJobAccepted> {
  return apiClient.post<AsyncBackupJobAccepted>('/api/backup/create', undefined, config);
}

/**
 * POST /api/backup/restore
 * Mirrors api/endpoints/backup_endpoints.R:285 (handler `@post /restore`).
 *
 * Administrator-only. Submits an async restore job (auto-creates a
 * pre-restore safety backup). Returns 202.
 *
 * Throws AxiosError on non-2xx (400 missing filename, 404 file not found,
 * 409 already running, 503 capacity).
 */
export async function restoreBackup(
  body: RestoreBackupRequest,
  config?: AxiosRequestConfig,
): Promise<AsyncBackupJobAccepted> {
  return apiClient.post<AsyncBackupJobAccepted, RestoreBackupRequest>(
    '/api/backup/restore',
    body,
    config,
  );
}

/**
 * GET /api/backup/download/<filename>
 * Mirrors api/endpoints/backup_endpoints.R:455 (handler `@get /download/<filename>`).
 *
 * Administrator-only. Returns the raw backup file as a `Blob` (the R handler
 * uses `@serializer octet`). Callers typically pipe this through
 * `file-saver`. The path param is `encodeURIComponent`-ed; the server still
 * rejects names with path separators (400) and invalid extensions (400).
 *
 * Throws AxiosError on non-2xx.
 */
export async function downloadBackup(
  filename: string,
  config?: AxiosRequestConfig,
): Promise<Blob> {
  const path = `/api/backup/download/${encodeURIComponent(filename)}`;
  const response = await apiClient.raw.get<Blob>(path, {
    ...config,
    responseType: 'blob',
  });
  return response.data;
}

/**
 * DELETE /api/backup/delete/<filename>
 * Mirrors api/endpoints/backup_endpoints.R:555 (handler `@delete /delete/<filename>`).
 *
 * Administrator-only. Deletes the named backup. Requires `confirm: "DELETE"`
 * in the request body to prevent accidents. Refuses to delete `latest.*`
 * symlinks.
 *
 * Throws AxiosError on non-2xx (400 missing/invalid confirmation,
 * 404 file not found, 500 delete failed).
 */
export async function deleteBackup(
  filename: string,
  body: DeleteBackupRequest = { confirm: 'DELETE' },
  config?: AxiosRequestConfig,
): Promise<DeleteBackupResponse> {
  const path = `/api/backup/delete/${encodeURIComponent(filename)}`;
  return apiClient.delete<DeleteBackupResponse>(path, {
    ...config,
    data: body,
  });
}
