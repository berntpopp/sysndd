// app/src/api/comparisons.ts
//
// Cross-database comparisons resource helpers.
//
// Mirrors api/endpoints/comparisons_endpoints.R (mounted at /api/comparisons).
// Phase E.E2: filled during v11.1 Wave 1a (W3).
//
// Used by `CurationComparisons.vue` and the analyses cluster components
// (`AnalysesCurationUpset`, `AnalysesCurationMatrixPlot`,
// `AnalysesCurationComparisonsTable`).

import type { AxiosRequestConfig } from 'axios';
import { apiClient } from './client';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface ComparisonsOptionsParams {
  limit?: number;
  offset?: number;
}

/**
 * Wire shape from `GET /api/comparisons/options`. Each value is a tibble
 * collected to JSON — comes back as an array of single-key objects, e.g.
 * `[{ list: 'SysNDD' }, { list: 'panelapp' }, ...]`.
 */
export interface ComparisonsOptions {
  list: Array<{ list: string }>;
  inheritance: Array<{ inheritance: string | null }>;
  category: Array<{ category: string | null }>;
  pathogenicity_mode: Array<{ pathogenicity_mode: string | null }>;
}

export interface UpsetParams {
  fields?: string;
  /** Server expects "true"/"false" string. */
  definitive_only?: string;
  limit?: number;
  offset?: number;
}

/**
 * One row in the UpSet response. `name` is the gene HGNC id; `sets` is the
 * list of databases the gene belongs to (the R handler runs `strsplit(...)`
 * server-side, so the wire shape is already an array of strings).
 */
export interface UpsetRow {
  name: string;
  sets: string[];
}

export interface SimilarityParams {
  limit?: number;
  offset?: number;
}

/**
 * One cell of the melted cosine-similarity matrix.
 */
export interface SimilarityCell {
  x: string;
  y: string;
  value: number;
}

export type ComparisonsBrowseFormat = 'json' | 'xlsx';

export interface BrowseComparisonsParams {
  sort?: string;
  filter?: string;
  fields?: string;
  page_after?: string;
  page_size?: string;
  fspec?: string;
  definitive_only?: string;
  format?: ComparisonsBrowseFormat;
}

/**
 * One row of the browse listing — keys are dynamic (driven by `fspec`), so we
 * surface a generic record. The header columns mirror `ndd_database_comparison_view`.
 */
export type BrowseComparisonsRow = Record<string, unknown>;

/**
 * Wire envelope for `GET /api/comparisons/browse?format=json`. Same shape as
 * other paginated endpoints (`PaginatedGeneResponse` in `genes.ts`).
 */
export interface BrowseComparisonsResponse {
  meta: unknown[];
  data: BrowseComparisonsRow[];
  links?: unknown[];
}

/**
 * Wire shape from `GET /api/comparisons/metadata`. Reports the last refresh
 * status of the comparisons data ingest pipeline.
 */
export interface ComparisonsMetadata {
  last_full_refresh: string | null;
  last_refresh_status: 'never' | 'success' | 'failed' | string;
  last_refresh_error: string | null;
  sources_count: number;
  rows_imported: number;
  message?: string;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * GET /api/comparisons/options
 * Mirrors api/endpoints/comparisons_endpoints.R:35 (handler `@get options`).
 *
 * Returns the filter-option lists used by the comparison dropdowns.
 * `limit`/`offset` are accepted by the handler for the pagination contract
 * but are not applied (response is a fixed-shape named-keys object).
 */
export async function getComparisonsOptions(
  params: ComparisonsOptionsParams = {},
  config?: AxiosRequestConfig
): Promise<ComparisonsOptions> {
  return apiClient.get<ComparisonsOptions>('/api/comparisons/options', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * GET /api/comparisons/upset
 * Mirrors api/endpoints/comparisons_endpoints.R:108 (handler `@get upset`).
 *
 * Returns the UpSet plot data — one row per HGNC id with the array of
 * databases the gene belongs to.
 */
export async function getUpsetData(
  params: UpsetParams = {},
  config?: AxiosRequestConfig
): Promise<UpsetRow[]> {
  return apiClient.get<UpsetRow[]>('/api/comparisons/upset', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * GET /api/comparisons/similarity
 * Mirrors api/endpoints/comparisons_endpoints.R:176 (handler `@get similarity`).
 *
 * Returns the melted cosine-similarity matrix between databases.
 */
export async function getSimilarity(
  params: SimilarityParams = {},
  config?: AxiosRequestConfig
): Promise<SimilarityCell[]> {
  return apiClient.get<SimilarityCell[]>('/api/comparisons/similarity', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * GET /api/comparisons/browse
 * Mirrors api/endpoints/comparisons_endpoints.R:226 (handler `@get browse`).
 *
 * Cursor-paginated comparison listing. `format=json` returns the cursor
 * envelope; `format=xlsx` returns a binary attachment — for the xlsx form
 * use `browseComparisonsXlsx()` below which surfaces a `Blob`.
 */
export async function browseComparisons(
  params: BrowseComparisonsParams = {},
  config?: AxiosRequestConfig
): Promise<BrowseComparisonsResponse> {
  return apiClient.get<BrowseComparisonsResponse>('/api/comparisons/browse', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params, format: 'json' },
  });
}

/**
 * GET /api/comparisons/browse?format=xlsx
 * Same handler as `browseComparisons`, but returns a binary `Blob` for the
 * XLSX export path. Use this when the caller wants to trigger a file download.
 */
export async function browseComparisonsXlsx(
  params: Omit<BrowseComparisonsParams, 'format'> = {},
  config?: AxiosRequestConfig
): Promise<Blob> {
  const response = await apiClient.raw.get<Blob>('/api/comparisons/browse', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params, format: 'xlsx' },
    responseType: 'blob',
  });
  return response.data;
}

/**
 * GET /api/comparisons/metadata
 * Mirrors api/endpoints/comparisons_endpoints.R:283 (handler `@get /metadata`).
 *
 * Returns the last comparisons-data refresh metadata (admin UI). The handler
 * gracefully returns a `"never"` state when the metadata table is empty or
 * its migration hasn't run yet.
 */
export async function getComparisonsMetadata(
  config?: AxiosRequestConfig
): Promise<ComparisonsMetadata> {
  return apiClient.get<ComparisonsMetadata>('/api/comparisons/metadata', config);
}

/**
 * A single external comparison source, as advertised by the live source
 * registry (`comparisons_config` + the derived OMIM-NDD source).
 */
export interface ComparisonsSource {
  name: string;
  label: string;
  url: string | null;
  format: string | null;
  last_updated: string | null;
  description: string | null;
}

export interface ComparisonsSourcesResponse {
  last_full_refresh: string | null;
  sources: ComparisonsSource[];
}

/** Plumber serializes scalars as single-element arrays; unwrap them. */
function unwrapScalar(value: unknown): unknown {
  return Array.isArray(value) ? value[0] : value;
}

function toStr(value: unknown): string {
  return String(unwrapScalar(value) ?? '');
}

/** Unwrap + normalize the `na="string"` serializer's `"NA"`/empty to null. */
function toStrOrNull(value: unknown): string | null {
  const scalar = unwrapScalar(value);
  if (scalar === null || scalar === undefined) return null;
  const str = String(scalar);
  return str === 'NA' || str === '' ? null : str;
}

/**
 * GET /api/comparisons/sources
 * Mirrors api/endpoints/comparisons_endpoints.R (handler `@get /sources`).
 *
 * Returns the live comparison-source registry (current download URLs and
 * per-source last-updated timestamps) plus the last full-refresh time, so the
 * provenance panel stays in sync with the API instead of hardcoded text.
 * Plumber array-wrapping is unwrapped here so callers get clean scalars.
 */
export async function getComparisonsSources(
  config?: AxiosRequestConfig
): Promise<ComparisonsSourcesResponse> {
  const raw = await apiClient.get<Record<string, unknown>>('/api/comparisons/sources', config);
  const rawSources = Array.isArray(raw?.sources)
    ? (raw.sources as Array<Record<string, unknown>>)
    : [];
  const sources: ComparisonsSource[] = rawSources.map((s) => ({
    name: toStr(s.name),
    label: toStr(s.label),
    url: toStrOrNull(s.url),
    format: toStrOrNull(s.format),
    last_updated: toStrOrNull(s.last_updated),
    description: toStrOrNull(s.description),
  }));
  return {
    last_full_refresh: toStrOrNull(raw?.last_full_refresh),
    sources,
  };
}
