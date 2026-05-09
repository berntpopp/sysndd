// app/src/api/publication.ts
//
// Publication + PubTator resource helpers.
//
// Mirrors api/endpoints/publication_endpoints.R (mounted at /api/publication).
// Phase E.E2: filled during v11.1 Wave 1a (W3).
//
// Used by W5 (PublicationsNDD components) and admin / pubtator workflows.

import type { AxiosRequestConfig } from 'axios';
import { apiClient } from './client';

// ---------------------------------------------------------------------------
// Types — publication core
// ---------------------------------------------------------------------------

export interface PublicationStatsParams {
  /** ISO date `YYYY-MM-DD` to compute filtered_count of "stale" pubs. */
  not_updated_since?: string;
}

export interface PublicationStats {
  total: number;
  oldest_update: string | null;
  outdated_count: number;
  filtered_count?: number;
  filter_date?: string;
}

export interface PublicationRecord {
  publication_id: string;
  other_publication_id?: string | null;
  Title?: string | null;
  Abstract?: string | null;
  Lastname?: string | null;
  Firstname?: string | null;
  Publication_date?: string | null;
  Journal?: string | null;
  Keywords?: string | null;
}

export type PublicationListFormat = 'json' | 'xlsx';

export interface ListPublicationsParams {
  sort?: string;
  filter?: string;
  fields?: string;
  page_after?: string | number;
  page_size?: string;
  fspec?: string;
  format?: PublicationListFormat;
}

export interface PublicationListResponse {
  links?: unknown;
  meta?: unknown;
  data: PublicationRecord[];
}

// ---------------------------------------------------------------------------
// Types — PubTator
// ---------------------------------------------------------------------------

export interface PubtatorSearchParams {
  current_page?: number | string;
}

export interface PubtatorSearchPmidsItem {
  pmid: string;
  title?: string;
  [key: string]: unknown;
}

export interface PubtatorSearchResponse {
  meta: {
    perPage: number;
    currentPage: number;
    totalPages: number;
  };
  data: PubtatorSearchPmidsItem[];
}

export type PubtatorTableFormat = 'json' | 'xlsx';

export interface PubtatorTableParams {
  sort?: string;
  filter?: string;
  fields?: string;
  page_after?: string | number;
  page_size?: string;
  fspec?: string;
  format?: PubtatorTableFormat;
}

/**
 * One row of `pubtator_search_cache` — keys are dynamic.
 */
export type PubtatorTableRow = Record<string, unknown>;

export interface PubtatorTableResponse {
  links?: unknown;
  meta?: unknown;
  data: PubtatorTableRow[];
}

export type PubtatorGenesFormat = 'json' | 'xlsx';

export interface PubtatorGenesParams {
  sort?: string;
  filter?: string;
  fields?: string;
  page_after?: string | number;
  page_size?: string;
  fspec?: string;
  format?: PubtatorGenesFormat;
}

export type PubtatorGeneRow = Record<string, unknown>;

export interface PubtatorGenesResponse {
  links?: unknown;
  meta?: unknown;
  data: PubtatorGeneRow[];
}

export interface PubtatorBackfillResponse {
  updated: number;
  total_null?: number;
  execution_time?: string;
  message: string;
}

export interface PubtatorCacheStatusParams {
  query: string;
}

export interface PubtatorCacheStatus {
  query: string;
  cached: boolean;
  query_id?: string;
  pages_cached: number;
  publications_cached?: number;
  total_pages_available: number;
  total_results_available: number;
  pages_remaining?: number;
  cache_date: string | null;
  estimated_fetch_time_minutes: number;
  message: string;
}

export interface PubtatorUpdateParams {
  query: string;
  max_pages?: number;
  /** R coerces "true"/"false". */
  clear_old?: boolean | string;
}

export interface PubtatorUpdateResponse {
  success: boolean;
  message?: string;
  query_id?: string | null;
  pages_cached?: number;
  pages_total?: number;
  publications_count?: number;
  execution_time?: string;
  [key: string]: unknown;
}

export interface PubtatorAsyncSubmitResponse {
  job_id: string;
  status: string;
  query: string;
  max_pages: number;
  estimated_seconds: number;
  status_url: string;
}

export interface PubtatorClearCacheResponse {
  success: boolean;
  deleted?: { queries: number; publications: number; annotations: number };
  execution_time?: string;
  message?: string;
  error?: string;
}

// ---------------------------------------------------------------------------
// Helpers — publication core
// ---------------------------------------------------------------------------

/**
 * GET /api/publication/stats
 * Mirrors api/endpoints/publication_endpoints.R:31 (handler `@get /stats`).
 *
 * Returns publication-table summary stats (count, oldest update, outdated),
 * optionally filtered by `?not_updated_since=YYYY-MM-DD`.
 */
export async function getPublicationStats(
  params: PublicationStatsParams = {},
  config?: AxiosRequestConfig
): Promise<PublicationStats> {
  return apiClient.get<PublicationStats>('/api/publication/stats', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * GET /api/publication/<pmid>
 * Mirrors api/endpoints/publication_endpoints.R:99 (handler `@get <pmid>`).
 *
 * Returns the publication metadata array for the PMID. The R handler strips
 * non-digits and prefixes `PMID:` server-side, so callers can pass either
 * `12345` or `PMID:12345`.
 */
export async function getPublicationByPmid(
  pmid: string,
  config?: AxiosRequestConfig
): Promise<PublicationRecord[]> {
  const path = `/api/publication/${encodeURIComponent(pmid)}`;
  return apiClient.get<PublicationRecord[]>(path, config);
}

/**
 * GET /api/publication/
 * Mirrors api/endpoints/publication_endpoints.R:228 (handler `@get /`).
 *
 * Cursor-paginated publication listing. JSON form; xlsx variant below.
 */
export async function listPublications(
  params: ListPublicationsParams = {},
  config?: AxiosRequestConfig
): Promise<PublicationListResponse> {
  return apiClient.get<PublicationListResponse>('/api/publication/', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params, format: 'json' },
  });
}

/**
 * GET /api/publication/?format=xlsx
 *
 * Same handler as `listPublications`, but surfaces the XLSX byte stream.
 */
export async function listPublicationsXlsx(
  params: Omit<ListPublicationsParams, 'format'> = {},
  config?: AxiosRequestConfig
): Promise<Blob> {
  const response = await apiClient.raw.get<Blob>('/api/publication/', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params, format: 'xlsx' },
    responseType: 'blob',
  });
  return response.data;
}

// ---------------------------------------------------------------------------
// Helpers — PubTator
// ---------------------------------------------------------------------------

/**
 * GET /api/publication/pubtator/search
 * Mirrors api/endpoints/publication_endpoints.R:169 (handler `@get pubtator/search`).
 *
 * Queries the PubTator API for the canonical NDD search query (server-side
 * fixed string). Pagination: `current_page` 1-indexed.
 */
export async function searchPubtator(
  params: PubtatorSearchParams = {},
  config?: AxiosRequestConfig
): Promise<PubtatorSearchResponse> {
  return apiClient.get<PubtatorSearchResponse>('/api/publication/pubtator/search', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * GET /api/publication/pubtator/table
 * Mirrors api/endpoints/publication_endpoints.R:396 (handler `@get /pubtator/table`).
 *
 * Cursor-paginated PubTator search-cache table.
 */
export async function listPubtatorTable(
  params: PubtatorTableParams = {},
  config?: AxiosRequestConfig
): Promise<PubtatorTableResponse> {
  return apiClient.get<PubtatorTableResponse>('/api/publication/pubtator/table', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params, format: 'json' },
  });
}

/**
 * GET /api/publication/pubtator/table?format=xlsx
 */
export async function listPubtatorTableXlsx(
  params: Omit<PubtatorTableParams, 'format'> = {},
  config?: AxiosRequestConfig
): Promise<Blob> {
  const response = await apiClient.raw.get<Blob>('/api/publication/pubtator/table', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params, format: 'xlsx' },
    responseType: 'blob',
  });
  return response.data;
}

/**
 * GET /api/publication/pubtator/genes
 * Mirrors api/endpoints/publication_endpoints.R:526 (handler `@get /pubtator/genes`).
 *
 * Cursor-paginated nested gene + publication view (one row per gene with
 * nested publications/entities arrays).
 */
export async function listPubtatorGenes(
  params: PubtatorGenesParams = {},
  config?: AxiosRequestConfig
): Promise<PubtatorGenesResponse> {
  return apiClient.get<PubtatorGenesResponse>('/api/publication/pubtator/genes', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params, format: 'json' },
  });
}

/**
 * GET /api/publication/pubtator/genes?format=xlsx
 */
export async function listPubtatorGenesXlsx(
  params: Omit<PubtatorGenesParams, 'format'> = {},
  config?: AxiosRequestConfig
): Promise<Blob> {
  const response = await apiClient.raw.get<Blob>('/api/publication/pubtator/genes', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params, format: 'xlsx' },
    responseType: 'blob',
  });
  return response.data;
}

/**
 * POST /api/publication/pubtator/backfill-genes
 * Mirrors api/endpoints/publication_endpoints.R:686 (handler `@post /pubtator/backfill-genes`).
 *
 * Recomputes `gene_symbols` for cached PubTator rows where it is NULL.
 */
export async function backfillPubtatorGenes(
  config?: AxiosRequestConfig
): Promise<PubtatorBackfillResponse> {
  return apiClient.post<PubtatorBackfillResponse>(
    '/api/publication/pubtator/backfill-genes',
    undefined,
    config
  );
}

/**
 * GET /api/publication/pubtator/cache-status
 * Mirrors api/endpoints/publication_endpoints.R:763 (handler `@get /pubtator/cache-status`).
 *
 * Inspects the PubTator cache for the given query.
 *
 * Throws AxiosError on non-2xx (400 missing query).
 */
export async function getPubtatorCacheStatus(
  params: PubtatorCacheStatusParams,
  config?: AxiosRequestConfig
): Promise<PubtatorCacheStatus> {
  return apiClient.get<PubtatorCacheStatus>('/api/publication/pubtator/cache-status', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * POST /api/publication/pubtator/update
 * Mirrors api/endpoints/publication_endpoints.R:852 (handler `@post /pubtator/update`).
 *
 * Synchronous PubTator update (admin). For long queries, prefer the async
 * variant `submitPubtatorUpdate()` below.
 *
 * Throws AxiosError on non-2xx (400 missing query).
 */
export async function updatePubtator(
  params: PubtatorUpdateParams,
  config?: AxiosRequestConfig
): Promise<PubtatorUpdateResponse> {
  return apiClient.post<PubtatorUpdateResponse>('/api/publication/pubtator/update', undefined, {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * POST /api/publication/pubtator/update/submit
 * Mirrors api/endpoints/publication_endpoints.R:988 (handler `@post /pubtator/update/submit`).
 *
 * Async PubTator update — submits a job and returns 202 with the job_id.
 *
 * Throws AxiosError on non-2xx (400 missing query, 409 dup, 503 capacity).
 */
export async function submitPubtatorUpdate(
  params: PubtatorUpdateParams,
  config?: AxiosRequestConfig
): Promise<PubtatorAsyncSubmitResponse> {
  return apiClient.post<PubtatorAsyncSubmitResponse>(
    '/api/publication/pubtator/update/submit',
    undefined,
    {
      ...config,
      params: { ...(config?.params as object | undefined), ...params },
    }
  );
}

/**
 * POST /api/publication/pubtator/clear-cache
 * Mirrors api/endpoints/publication_endpoints.R:1115 (handler `@post /pubtator/clear-cache`).
 *
 * Wipes the entire PubTator cache (queries + publications + annotations).
 */
export async function clearPubtatorCache(
  config?: AxiosRequestConfig
): Promise<PubtatorClearCacheResponse> {
  return apiClient.post<PubtatorClearCacheResponse>(
    '/api/publication/pubtator/clear-cache',
    undefined,
    config
  );
}
