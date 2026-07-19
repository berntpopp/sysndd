// app/src/api/admin_analysis_release.ts
//
// Administrator-only typed API client for analysis-snapshot RELEASE
// management (#573 Slice B, Task B4a).
//
// Mirrors api/endpoints/admin_analysis_snapshot_endpoints.R (mounted at
// /api/admin/analysis) — the release-management routes appended by #573
// Slice A / Task A7. Every route here requires the Administrator role
// (enforced server-side; `apiClient`'s interceptor supplies the bearer
// token) and uses `@serializer unboxedJSON`, so response scalars are
// plain JSON values, NOT array-wrapped — `unwrapScalar` is not needed here
// (contrast `nddscore_admin.ts`, which reads a default-serialized route).
//
// The admin `/DataReleases` management VIEW that consumes this client is a
// separate task (B4b) — this file is client-only, no view/composable/route.

import type { AxiosRequestConfig } from 'axios';
import { apiClient } from './client';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/**
 * Light per-layer identity, as it appears in `layers[]` on each head from
 * the admin LIST route (`GET /releases`) — mirrors `ReleaseHeadLayer` in the
 * public `analysis_releases.ts`, duplicated here so this file has no
 * dependency on that public-only module (see the `AdminReleaseHead` note
 * below for why the two head shapes are intentionally separate types).
 */
export interface AdminReleaseLayer {
  analysis_type: string;
  snapshot_id: number;
  payload_hash: string;
}

/**
 * RAW `analysis_snapshot_release` head, as returned by the admin routes
 * (`analysis_release_list()` / `analysis_release_get()`,
 * api/functions/analysis-snapshot-release-repository.R). This is
 * DELIBERATELY a SEPARATE type from the public `ReleaseHead` in
 * `analysis_releases.ts` — the public projection nests DOI fields under
 * `zenodo` and omits `created_by_user_id`/`last_error_message`; the admin
 * surface returns the flat DOI columns plus those two operational fields.
 * Do not import or reuse the public type here.
 */
export interface AdminReleaseHead {
  release_id: string;
  /**
   * Reserved string column (`VARCHAR(32)`, migration 045) — always `null`
   * today; the builder never populates it (`api/functions/analysis-snapshot-
   * release.R`). Not a number, and not guaranteed non-null.
   */
  release_version: string | null;
  title: string | null;
  status: string;
  manifest_schema_version: string;
  content_digest: string;
  source_data_version: string;
  db_release_version: string | null;
  db_release_commit: string | null;
  manifest_sha256: string;
  bundle_sha256: string;
  license: string;
  file_count: number;
  total_bytes: number;
  created_by_user_id: number | null;
  created_at: string;
  published_at: string | null;
  updated_at: string;
  zenodo_record_id: string | null;
  zenodo_record_url: string | null;
  version_doi: string | null;
  concept_doi: string | null;
  last_error_message: string | null;
  /** Light per-layer summary (list route only). */
  layers?: AdminReleaseLayer[];
  [key: string]: unknown;
}

export interface AdminReleaseListParams {
  limit?: number;
  offset?: number;
}

export interface AdminReleaseListResponse {
  releases: AdminReleaseHead[];
  pagination: {
    limit: number;
    offset: number;
    count: number;
  };
}

export interface BuildReleaseRequest {
  /** Optional layer-registry override; omit for the fixed default registry. */
  layers?: unknown[];
  title?: string;
  scope_statement?: string;
  /** Defaults server-side to `"CC-BY-4.0"`. */
  license?: string;
  /** Defaults server-side to `true`. */
  publish?: boolean;
}

export interface RecordReleaseDoiFields {
  zenodo_record_id?: string;
  zenodo_record_url?: string;
  version_doi?: string;
  concept_doi?: string;
}

/**
 * Discriminated build outcome so a caller (B4b's view) can distinguish a
 * genuinely-new release (201), a content-identical idempotent dup (200),
 * and a transient "sources are mid-refresh" lock (503) — three DIFFERENT
 * non-error outcomes the backend deliberately does not throw for. A 400
 * gate failure (`release_snapshot_not_available`,
 * `release_source_incoherent`, `release_reproducibility_missing`,
 * `release_source_version_mismatch`, `release_dependency_lineage_mismatch`)
 * still rejects as an `ApiError`; the caller reads its message via
 * `extractApiErrorMessage`.
 */
export type BuildReleaseResult =
  | { outcome: 'created'; release: AdminReleaseHead }
  | { outcome: 'exists'; release: AdminReleaseHead }
  | { outcome: 'locked'; retryAfter: number; message: string };

interface ReleaseLockUnavailableBody {
  error: 'release_lock_unavailable';
  message: string;
}

/**
 * Per-preset manifest state, as returned by `GET /snapshots/status`
 * (`service_analysis_snapshot_status()`). The endpoint reports every
 * supported analysis preset — including `phenotype_correlations` and
 * `gene_network_edges`, which are NOT analysis-snapshot-release layers.
 * `RELEASE_LAYER_TYPES` below is the single source of truth for the subset
 * a release build actually consumes.
 */
export interface SnapshotPresetState {
  analysis_type: string;
  parameter_hash: string;
  state: 'available' | 'stale' | 'source_version_mismatch' | 'missing';
  generated_at: string | null;
  activated_at: string | null;
  stale_after: string | null;
  source_data_version: string | null;
  row_counts: Record<string, unknown> | null;
  [key: string]: unknown;
}

export interface SnapshotStatusSummary {
  total: number;
  available: number;
  missing: number;
  stale: number;
  mismatch: number;
}

export interface SnapshotStatusResponse {
  presets: SnapshotPresetState[];
  summary: SnapshotStatusSummary;
}

/**
 * The three analysis types an analysis-snapshot release actually freezes
 * (`analysis_snapshot_release_layers()`, api/functions/analysis-snapshot-
 * release.R). Single source of truth for filtering `GET /snapshots/status`'s
 * broader preset list down to the layers B4b's "disable Build" gate cares
 * about.
 */
export const RELEASE_LAYER_TYPES = [
  'functional_clusters',
  'phenotype_clusters',
  'phenotype_functional_correlations',
] as const;

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * POST /api/admin/analysis/releases
 * Mirrors api/endpoints/admin_analysis_snapshot_endpoints.R (handler `@post /releases`).
 *
 * Administrator-only. Loads the currently active public-ready snapshots,
 * gates them, and persists an immutable, content-addressed release. Uses
 * `apiClient.raw.post` with a widened `validateStatus` so 200 (idempotent
 * dup), 201 (new content), and 503 (`release_lock_unavailable`, sources
 * mid-refresh) all resolve instead of throwing — only those three plus any
 * 4xx/5xx the caller opts into are distinguishable from a throw. 400 (any
 * of the 5 gate-failure classes) and 404 (never actually returned by this
 * route) still throw as `AxiosError`; the caller reads the message via
 * `extractApiErrorMessage`.
 */
export async function buildRelease(
  body: BuildReleaseRequest,
  config?: AxiosRequestConfig
): Promise<BuildReleaseResult> {
  const response = await apiClient.raw.post<AdminReleaseHead | ReleaseLockUnavailableBody>(
    '/api/admin/analysis/releases',
    body,
    {
      ...config,
      validateStatus: (status) => (status >= 200 && status < 300) || status === 503,
    }
  );

  if (response.status === 503) {
    const locked = response.data as ReleaseLockUnavailableBody;
    const retryAfterHeader = response.headers?.['retry-after'];
    const retryAfter = Number.parseInt(String(retryAfterHeader ?? '5'), 10);
    return {
      outcome: 'locked',
      retryAfter: Number.isFinite(retryAfter) ? retryAfter : 5,
      message: locked.message,
    };
  }

  const release = response.data as AdminReleaseHead;
  return {
    outcome: response.status === 201 ? 'created' : 'exists',
    release,
  };
}

/**
 * GET /api/admin/analysis/releases
 * Mirrors api/endpoints/admin_analysis_snapshot_endpoints.R (handler `@get /releases`).
 *
 * Administrator-only. Lists ALL releases (draft + published + failed),
 * newest first — unlike the public `GET /api/analysis/releases`
 * (published-only).
 */
export async function listAdminReleases(
  params: AdminReleaseListParams = {},
  config?: AxiosRequestConfig
): Promise<AdminReleaseListResponse> {
  return apiClient.get<AdminReleaseListResponse>('/api/admin/analysis/releases', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * GET /api/admin/analysis/releases/<release_id>
 * Mirrors api/endpoints/admin_analysis_snapshot_endpoints.R (handler `@get /releases/<release_id>`).
 *
 * Administrator-only. Resolves a draft release too (`include_draft = true`).
 * Throws AxiosError 404 for an unknown id.
 */
export async function getAdminRelease(
  releaseId: string,
  config?: AxiosRequestConfig
): Promise<AdminReleaseHead> {
  const path = `/api/admin/analysis/releases/${encodeURIComponent(releaseId)}`;
  return apiClient.get<AdminReleaseHead>(path, config);
}

/**
 * POST /api/admin/analysis/releases/<release_id>/publish
 * Mirrors api/endpoints/admin_analysis_snapshot_endpoints.R (handler `@post /releases/<release_id>/publish`).
 *
 * Administrator-only. Throws AxiosError 404 for an unknown id; an
 * already-published release is an idempotent no-op that still returns the
 * current head.
 */
export async function publishRelease(
  releaseId: string,
  config?: AxiosRequestConfig
): Promise<AdminReleaseHead> {
  const path = `/api/admin/analysis/releases/${encodeURIComponent(releaseId)}/publish`;
  return apiClient.post<AdminReleaseHead>(path, undefined, config);
}

/**
 * PATCH /api/admin/analysis/releases/<release_id>/doi
 * Mirrors api/endpoints/admin_analysis_snapshot_endpoints.R (handler `@patch /releases/<release_id>/doi`).
 *
 * Administrator-only. The four DOI fields are Plumber named args read from
 * the query string, so ONLY the keys actually present in `fields` are
 * forwarded as `config.params` — an omitted field must stay unchanged
 * server-side, never nulled out by an unfiltered pass-through.
 */
export async function recordReleaseDoi(
  releaseId: string,
  fields: RecordReleaseDoiFields,
  config?: AxiosRequestConfig
): Promise<AdminReleaseHead> {
  const path = `/api/admin/analysis/releases/${encodeURIComponent(releaseId)}/doi`;
  const params: Record<string, string> = {};
  for (const [key, value] of Object.entries(fields)) {
    if (value !== undefined && value !== null && value !== '') {
      params[key] = value;
    }
  }
  return apiClient.patch<AdminReleaseHead>(path, undefined, {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * DELETE /api/admin/analysis/releases/<release_id>
 * Mirrors api/endpoints/admin_analysis_snapshot_endpoints.R (handler `@delete /releases/<release_id>`).
 *
 * Administrator-only. Deletes a DRAFT release only. Throws AxiosError 400
 * if the release is already published, 404 for an unknown id.
 */
export async function deleteDraftRelease(
  releaseId: string,
  config?: AxiosRequestConfig
): Promise<void> {
  const path = `/api/admin/analysis/releases/${encodeURIComponent(releaseId)}`;
  await apiClient.delete<unknown>(path, config);
}

/**
 * GET /api/admin/analysis/snapshots/status
 * Mirrors api/endpoints/admin_analysis_snapshot_endpoints.R (handler `@get /snapshots/status`).
 *
 * Administrator-only. Per-preset manifest state for every supported
 * analysis preset (not just the three release layers — see
 * `RELEASE_LAYER_TYPES`).
 */
export async function fetchSnapshotStatus(
  config?: AxiosRequestConfig
): Promise<SnapshotStatusResponse> {
  return apiClient.get<SnapshotStatusResponse>('/api/admin/analysis/snapshots/status', config);
}
