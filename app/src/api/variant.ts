// app/src/api/variant.ts
//
// Variant resource helpers.
//
// Mirrors api/endpoints/variant_endpoints.R (mounted at /api/variant).
// Phase E.E2: filled during v11.1 Wave 1a (W3).
//
// Used by W5 (`AnalysesVariantCounts.vue`, `AnalysesVariantCorrelogram.vue`)
// and any future variant browse view.

import type { AxiosRequestConfig } from 'axios';
import { apiClient } from './client';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface BrowseVariantEntitiesParams {
  sort?: string;
  filter?: string;
  fields?: string;
  page_after?: string | number;
  page_size?: string;
  fspec?: string;
  /** "json" (default) or "xlsx". The xlsx format streams a binary attachment. */
  format?: 'json' | 'xlsx';
}

/**
 * One row of the cursor-paginated variant browse response. The exact column
 * set is dictated by the `fields` / `fspec` query params; the surface here
 * mirrors the default fspec the R handler ships with.
 */
export interface VariantEntityRow {
  entity_id: number;
  symbol: string;
  disease_ontology_name: string;
  hpo_mode_of_inheritance_term_name: string;
  category: string;
  ndd_phenotype_word: string | null;
  modifier_variant_id: string | null;
  details: string | null;
  [key: string]: unknown;
}

/**
 * Cursor-pagination envelope returned by `GET /api/variant/browse?format=json`.
 */
export interface VariantBrowseResponse {
  links: unknown;
  meta: unknown;
  data: VariantEntityRow[];
}

export interface VariantCorrelationParams {
  filter?: string;
  /** Server caps at 500. */
  limit?: number;
  offset?: number;
}

/**
 * One cell of the variant correlation matrix. The endpoint melts the
 * presence/absence matrix to long form (`x` × `y` → `value`).
 */
export interface VariantCorrelationCell {
  x: string;
  x_vario_id: string;
  y: string;
  y_vario_id: string;
  value: number;
}

export interface VariantCountParams {
  filter?: string;
  /** Server caps at 500. */
  limit?: number;
  offset?: number;
}

/**
 * One row of the variant-count tally. `count` is `n` from the R handler's
 * `dplyr::tally()`.
 */
export interface VariantCountRow {
  vario_id: string;
  variant_name: string;
  count: number;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * GET /api/variant/browse
 * Mirrors api/endpoints/variant_endpoints.R:33 (handler `@get browse`).
 *
 * Returns the cursor-paginated entity list filtered/joined to variant data.
 * Pass `format: "xlsx"` to get an XLSX attachment instead of JSON; in that
 * case callers should use the raw axios response (this helper still resolves
 * with `response.data`, which will be a Blob for XLSX requests).
 *
 * Throws AxiosError on non-2xx.
 */
export async function browseVariantEntities(
  params: BrowseVariantEntitiesParams = {},
  config?: AxiosRequestConfig
): Promise<VariantBrowseResponse> {
  return apiClient.get<VariantBrowseResponse>('/api/variant/browse', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * GET /api/variant/correlation
 * Mirrors api/endpoints/variant_endpoints.R:96 (handler `@get correlation`).
 *
 * Returns the long-form correlation matrix between variants annotated on
 * entities matching `filter`. The R handler defaults `filter` to
 * `"contains(ndd_phenotype_word,Yes),any(category,Definitive)"` when
 * omitted.
 *
 * Throws AxiosError on non-2xx.
 */
export async function getVariantCorrelation(
  params: VariantCorrelationParams = {},
  config?: AxiosRequestConfig
): Promise<VariantCorrelationCell[]> {
  return apiClient.get<VariantCorrelationCell[]>('/api/variant/correlation', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * GET /api/variant/count
 * Mirrors api/endpoints/variant_endpoints.R:192 (handler `@get count`).
 *
 * Returns the count of each variant (vario_id) across entities matching
 * `filter`, sorted by count descending. The R handler defaults `filter` to
 * `"contains(ndd_phenotype_word,Yes),any(category,Definitive)"` when
 * omitted.
 *
 * Throws AxiosError on non-2xx.
 */
export async function getVariantCounts(
  params: VariantCountParams = {},
  config?: AxiosRequestConfig
): Promise<VariantCountRow[]> {
  return apiClient.get<VariantCountRow[]>('/api/variant/count', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}
