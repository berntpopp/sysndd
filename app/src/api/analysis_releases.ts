// app/src/api/analysis_releases.ts
//
// Analysis-snapshot release resource helpers (#573).
//
// Immutable, content-addressed frozen exports of the public-ready analysis
// snapshots (functional clusters, phenotype clusters, phenotype-functional
// correlation) — mirrors the release-specific routes in
// api/endpoints/analysis_endpoints.R (mounted at /api/analysis). Split out
// of `analysis.ts` as a cohesive sub-domain to keep that file under the
// repo's 600-line soft ceiling; re-exported from `analysis.ts` so
// `@/api/analysis` stays the single import surface for analysis resources.
//
// All routes here are public/unauthenticated, DB-only, published-releases-only
// (draft releases are never served). See
// api/functions/analysis-snapshot-release-repository.R
// (`analysis_release_public_head()`) for the exact PUBLIC allowlist these
// types mirror.

import type { AxiosRequestConfig } from 'axios';
import { apiClient } from './client';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/**
 * Zenodo DOI metadata attached to a release head. Additive-only (#573):
 * fields are `null` until an admin records them via
 * `PATCH /api/admin/analysis/releases/<id>/doi`; they never affect
 * `content_digest`.
 */
export interface ReleaseZenodo {
  record_url: string | null;
  version_doi: string | null;
  concept_doi: string | null;
}

/**
 * Correlation-layer dependency lineage: pinned source cluster snapshots.
 *
 * The phenotype-functional correlation layer is derived FROM the functional
 * + phenotype cluster layers, so its manifest entry pins exactly which
 * snapshot (by id + payload hash) it was built against (#571/#572 dependency
 * gate) — this is what a consumer cross-checks to confirm the correlation
 * layer is internally consistent with its two source layers.
 */
export interface ReleaseLayerDependency {
  snapshot_id: number;
  payload_hash: string;
}

export interface ReleaseLayerDependencies {
  functional_clusters?: ReleaseLayerDependency;
  phenotype_clusters?: ReleaseLayerDependency;
}

/**
 * Full per-layer identity, as it appears in `manifest.layers[]` on the
 * detail (`GET /releases/<id>`) and `latest` routes. `reproducibility_hash`
 * is `null` for the `phenotype_functional_correlations` layer (that layer
 * has no reproducibility bundle); `dependencies` is non-null ONLY for that
 * same layer.
 */
export interface ReleaseManifestLayer {
  analysis_type: string;
  parameter_hash: string;
  snapshot_id: number;
  input_hash: string | null;
  payload_hash: string | null;
  schema_version: string;
  reproducibility_hash: string | null;
  dependencies: ReleaseLayerDependencies | null;
}

/**
 * Light per-layer summary, as it appears in `layers[]` on each head from the
 * LIST route (`GET /releases`) only — the list route intentionally omits the
 * full manifest (and therefore the fuller `ReleaseManifestLayer` shape) to
 * keep the listing payload cheap.
 */
export interface ReleaseHeadLayer {
  analysis_type: string;
  snapshot_id: number;
  payload_hash: string;
}

/**
 * PUBLIC projection of an `analysis_snapshot_release` head, as returned by
 * `analysis_release_public_head()` (api/functions/analysis-snapshot-release-repository.R).
 *
 * This is a FIXED 14-field allowlist + `zenodo` + conditional `layers`
 * (list route) / `manifest` (detail + latest routes). Admin-only columns
 * (`created_by_user_id`, `last_error_message`, `updated_at`) are NEVER part
 * of this type — do not widen it to match the raw admin head shape in
 * `admin_analysis_release.ts` (a separate, intentionally different type).
 */
export interface ReleaseHead {
  release_id: string;
  /**
   * Reserved string column (`VARCHAR(32)`, migration 045) — always `null`
   * today; the builder never populates it (`api/functions/analysis-snapshot-
   * release.R`). Not a number, and not guaranteed non-null.
   */
  release_version: string | null;
  title: string | null;
  status: string;
  content_digest: string;
  created_at: string;
  published_at: string | null;
  source_data_version: string;
  db_release_version: string | null;
  db_release_commit: string | null;
  manifest_sha256: string;
  bundle_sha256: string;
  license: string;
  file_count: number;
  total_bytes: number;
  zenodo: ReleaseZenodo;
  /** Light per-layer identity (list route only): analysis_type, snapshot_id, payload_hash. */
  layers?: ReleaseHeadLayer[];
}

export interface ReleaseManifestFile {
  path: string;
  sha256: string;
  bytes: number;
}

/**
 * The release `manifest.json` shape, built by
 * `analysis_release_build_manifest()` (api/functions/analysis-snapshot-release-manifest.R).
 * Present on the detail (`GET /releases/<id>`) and `latest` routes only —
 * NOT on the list route, which carries the lighter `layers` array on each
 * head instead.
 */
export interface ReleaseManifest {
  release_id: string;
  /** Reserved, currently-unpopulated string column — always `null` today (see `ReleaseHead.release_version`). */
  release_version: string | null;
  title: string | null;
  created_at: string;
  license: string;
  scope_statement: string;
  generator: string;
  source: string;
  layers: ReleaseManifestLayer[];
  files: ReleaseManifestFile[];
  content_digest: string;
}

/** `GET /releases/<id>` and `GET /releases/latest`: head + parsed manifest. */
export interface ReleaseDetail extends ReleaseHead {
  manifest: ReleaseManifest;
}

export interface ListReleasesParams {
  limit?: number;
  offset?: number;
}

export interface ListReleasesResponse {
  releases: ReleaseHead[];
  pagination: {
    limit: number;
    offset: number;
    count: number;
  };
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * GET /api/analysis/releases
 * Mirrors api/endpoints/analysis_endpoints.R (handler `@get releases`).
 *
 * Public, unauthenticated. Lists published analysis-snapshot releases
 * (newest first). `pagination` echoes the CLAMPED effective `limit`/`offset`
 * the service actually queried, not necessarily the caller's raw values.
 */
export async function listReleases(
  params: ListReleasesParams = {},
  config?: AxiosRequestConfig
): Promise<ListReleasesResponse> {
  return apiClient.get<ListReleasesResponse>('/api/analysis/releases', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * GET /api/analysis/releases/latest
 * Mirrors api/endpoints/analysis_endpoints.R (handler `@get releases/latest`).
 *
 * Public, unauthenticated. Returns the newest published release's head +
 * manifest (same shape as the detail route).
 *
 * Throws AxiosError 404 when no published release exists yet.
 */
export async function getLatestRelease(config?: AxiosRequestConfig): Promise<ReleaseDetail> {
  return apiClient.get<ReleaseDetail>('/api/analysis/releases/latest', config);
}

/**
 * GET /api/analysis/releases/<release_id>
 * Mirrors api/endpoints/analysis_endpoints.R (handler `@get releases/<release_id>`).
 *
 * Public, unauthenticated. Returns the release head + manifest. An unknown
 * id and a draft id are indistinguishable — both 404 (drafts are never
 * public).
 */
export async function getRelease(
  releaseId: string,
  config?: AxiosRequestConfig
): Promise<ReleaseDetail> {
  const path = `/api/analysis/releases/${encodeURIComponent(releaseId)}`;
  return apiClient.get<ReleaseDetail>(path, config);
}

/**
 * GET /api/analysis/releases/<release_id>/manifest.json
 * Mirrors api/endpoints/analysis_endpoints.R (handler `@get releases/<release_id>/manifest.json`).
 *
 * Public, unauthenticated. Returns the EXACT stored `manifest.json` bytes
 * verbatim (never re-serialized), so `sha256(bytes) == manifest_sha256` on
 * the release head. Returned as a `Blob` (the R handler uses `@serializer
 * octet application/json`).
 */
export async function downloadReleaseManifest(
  releaseId: string,
  config?: AxiosRequestConfig
): Promise<Blob> {
  const path = `/api/analysis/releases/${encodeURIComponent(releaseId)}/manifest.json`;
  const response = await apiClient.raw.get<Blob>(path, {
    ...config,
    responseType: 'blob',
  });
  return response.data;
}

/**
 * GET /api/analysis/releases/<release_id>/file?path=<file_path>
 * Mirrors api/endpoints/analysis_endpoints.R (handler `@get releases/<release_id>/file`).
 *
 * Public, unauthenticated. `path` is a QUERY param, not a URL path segment —
 * Plumber 1.3.2 has no `<path:.*>` wildcard, so a nested archive path (e.g.
 * `functional_clusters/payload.json`) cannot be expressed as a path segment.
 * Resolved by an exact `(release_id, file_path)` primary-key lookup; an
 * unknown path is a 404 (there is no filesystem access, so no path-traversal
 * surface). Returned as a `Blob`.
 */
export async function downloadReleaseFile(
  releaseId: string,
  path: string,
  config?: AxiosRequestConfig
): Promise<Blob> {
  const url = `/api/analysis/releases/${encodeURIComponent(releaseId)}/file`;
  const response = await apiClient.raw.get<Blob>(url, {
    ...config,
    params: { ...(config?.params as object | undefined), path },
    responseType: 'blob',
  });
  return response.data;
}

/**
 * GET /api/analysis/releases/<release_id>/bundle
 * Mirrors api/endpoints/analysis_endpoints.R (handler `@get releases/<release_id>/bundle`).
 *
 * Public, unauthenticated. Returns the release's pre-built `bundle.tar.gz`
 * verbatim (the R handler uses `@serializer octet application/gzip` and sets
 * `Content-Disposition: attachment`). Returned as a `Blob`.
 */
export async function downloadReleaseBundle(
  releaseId: string,
  config?: AxiosRequestConfig
): Promise<Blob> {
  const path = `/api/analysis/releases/${encodeURIComponent(releaseId)}/bundle`;
  const response = await apiClient.raw.get<Blob>(path, {
    ...config,
    responseType: 'blob',
  });
  return response.data;
}
