// app/src/api/panels.ts
//
// Panel resource helpers — gene panels (categories, inheritance, browse).
//
// Mirrors api/endpoints/panels_endpoints.R (mounted at /api/panels).
// Phase E.E2: filled during v11.1 Wave 1a (W3).
//
// Used by `PanelsTable.vue` (W7).

import type { AxiosRequestConfig } from 'axios';
import { apiClient } from './client';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface PanelOptionsParams {
  limit?: number;
  offset?: number;
}

/**
 * One option-group row from `GET /api/panels/options`. The handler emits
 * `tibble(lists, options)` — `lists` is one of "categories_list",
 * "inheritance_list", "columns_list", and `options` is the tibble of
 * available values.
 */
export interface PanelOptionGroup {
  lists: string;
  options: Array<{ value: string }>;
}

export type BrowsePanelsFormat = 'json' | 'xlsx';

export interface BrowsePanelsParams {
  sort?: string;
  filter?: string;
  fields?: string;
  page_after?: string | number;
  page_size?: string;
  /** R coerces "TRUE"/"FALSE" via as.logical. */
  max_category?: boolean | string;
  format?: BrowsePanelsFormat;
}

/**
 * One row of the panels browse listing. Keys are dynamic (driven by `fields`),
 * common columns: `category`, `inheritance`, `symbol`, `hgnc_id`, `entrez_id`,
 * `ensembl_gene_id`, `ucsc_id`, `bed_hg19`, `bed_hg38`.
 */
export type PanelRow = Record<string, unknown>;

export interface BrowsePanelsResponse {
  links?: unknown;
  meta?: unknown;
  data: PanelRow[];
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * GET /api/panels/options
 * Mirrors api/endpoints/panels_endpoints.R:31 (handler `@get options`).
 *
 * Returns the per-group filter option lists used by the panels UI.
 */
export async function getPanelOptions(
  params: PanelOptionsParams = {},
  config?: AxiosRequestConfig
): Promise<PanelOptionGroup[]> {
  return apiClient.get<PanelOptionGroup[]>('/api/panels/options', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * GET /api/panels/browse
 * Mirrors api/endpoints/panels_endpoints.R:84 (handler `@get browse`).
 *
 * Cursor-paginated panels listing. `format=json` returns the envelope below;
 * `format=xlsx` returns the binary attachment — for the xlsx path use
 * `browsePanelsXlsx()` below.
 */
export async function browsePanels(
  params: BrowsePanelsParams = {},
  config?: AxiosRequestConfig
): Promise<BrowsePanelsResponse> {
  return apiClient.get<BrowsePanelsResponse>('/api/panels/browse', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params, format: 'json' },
  });
}

/**
 * GET /api/panels/browse?format=xlsx
 *
 * Same handler as `browsePanels`, but surfaces the XLSX byte stream as a
 * `Blob`.
 */
export async function browsePanelsXlsx(
  params: Omit<BrowsePanelsParams, 'format'> = {},
  config?: AxiosRequestConfig
): Promise<Blob> {
  const response = await apiClient.raw.get<Blob>('/api/panels/browse', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params, format: 'xlsx' },
    responseType: 'blob',
  });
  return response.data;
}
