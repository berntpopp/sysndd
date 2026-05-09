// app/src/api/phenotype.ts
//
// Phenotype resource helpers (browse + correlation + count).
//
// Mirrors api/endpoints/phenotype_endpoints.R (mounted at /api/phenotype).
// Phase E.E2: filled during v11.1 Wave 1a (W3).
//
// Used by W5 (analyses components) and W7 (TablesPhenotypes view).

import type { AxiosRequestConfig } from 'axios';
import { apiClient } from './client';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type PhenotypeBrowseFormat = 'json' | 'xlsx';

export interface BrowsePhenotypeEntitiesParams {
  sort?: string;
  filter?: string;
  fields?: string;
  page_after?: string | number;
  page_size?: string;
  fspec?: string;
  format?: PhenotypeBrowseFormat;
}

/**
 * One row of the phenotype-entities listing. Keys are dynamic (driven by
 * `fields`), common columns: `entity_id`, `symbol`, `disease_ontology_name`,
 * `hpo_mode_of_inheritance_term_name`, `category`, `ndd_phenotype_word`,
 * `details`, `modifier_phenotype_id`.
 */
export type PhenotypeEntityRow = Record<string, unknown>;

export interface BrowsePhenotypeEntitiesResponse {
  links?: unknown;
  meta?: unknown;
  data: PhenotypeEntityRow[];
}

export interface PhenotypeCorrelationParams {
  filter?: string;
}

/**
 * One row of the phenotype-correlation matrix in melted form.
 */
export interface PhenotypeCorrelationCell {
  x: string;
  x_id: string;
  y: string;
  y_id: string;
  value: number;
}

export interface PhenotypeCountParams {
  filter?: string;
}

export interface PhenotypeCountRow {
  HPO_term: string;
  phenotype_id: string;
  count: number;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * GET /api/phenotype/entities/browse
 * Mirrors api/endpoints/phenotype_endpoints.R:34 (handler `@get entities/browse`).
 *
 * Cursor-paginated list of entities filtered by phenotypes. `format=json`
 * returns the envelope; `format=xlsx` returns a binary attachment — for
 * the xlsx path use `browsePhenotypeEntitiesXlsx()`.
 */
export async function browsePhenotypeEntities(
  params: BrowsePhenotypeEntitiesParams = {},
  config?: AxiosRequestConfig
): Promise<BrowsePhenotypeEntitiesResponse> {
  return apiClient.get<BrowsePhenotypeEntitiesResponse>('/api/phenotype/entities/browse', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params, format: 'json' },
  });
}

/**
 * GET /api/phenotype/entities/browse?format=xlsx
 *
 * Same handler as `browsePhenotypeEntities`, but surfaces the XLSX byte
 * stream as a `Blob`.
 */
export async function browsePhenotypeEntitiesXlsx(
  params: Omit<BrowsePhenotypeEntitiesParams, 'format'> = {},
  config?: AxiosRequestConfig
): Promise<Blob> {
  const response = await apiClient.raw.get<Blob>('/api/phenotype/entities/browse', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params, format: 'xlsx' },
    responseType: 'blob',
  });
  return response.data;
}

/**
 * GET /api/phenotype/correlation
 * Mirrors api/endpoints/phenotype_endpoints.R:109 (handler `@get correlation`).
 *
 * Returns the melted phenotype-phenotype correlation matrix with both
 * `HPO_term` labels (`x`/`y`) and ids (`x_id`/`y_id`).
 */
export async function getPhenotypeCorrelation(
  params: PhenotypeCorrelationParams = {},
  config?: AxiosRequestConfig
): Promise<PhenotypeCorrelationCell[]> {
  return apiClient.get<PhenotypeCorrelationCell[]>('/api/phenotype/correlation', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * GET /api/phenotype/count
 * Mirrors api/endpoints/phenotype_endpoints.R:172 (handler `@get count`).
 *
 * Returns the per-phenotype count tally (`HPO_term`, `phenotype_id`, `count`).
 */
export async function getPhenotypeCount(
  params: PhenotypeCountParams = {},
  config?: AxiosRequestConfig
): Promise<PhenotypeCountRow[]> {
  return apiClient.get<PhenotypeCountRow[]>('/api/phenotype/count', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}
