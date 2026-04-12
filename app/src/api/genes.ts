// app/src/api/genes.ts
/**
 * Gene resource helpers.
 *
 * Phase E.E1 template: this file and `auth.ts` are the two fully implemented
 * resource modules that set the pattern for v11.1 fill-out of the other 25
 * `api/<family>.ts` stubs.
 *
 * Wire shapes mirror `api/endpoints/gene_endpoints.R`:
 *   - `GET /api/gene` — cursor-paginated listing
 *     (`{ meta, data, links, ... }` envelope)
 *   - `GET /api/gene/<gene_input>?input_type=hgnc|symbol` — single gene lookup
 *     that returns an array (empty when not found, 1-row otherwise).
 *     GeneView.vue dispatches two parallel lookups (hgnc + symbol) and
 *     chooses whichever comes back with rows; see the helpers below.
 */

import { apiClient } from './client';
import type { AxiosRequestConfig } from 'axios';
import type { GeneApiData } from '@/types/gene';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/**
 * Single-gene lookup response. The R endpoint returns a `tibble` collected to
 * JSON, which appears on the wire as an array — empty when the gene does not
 * exist, or a 1-row array when it does. GeneView indexes `[0]` after a length
 * check, so we surface the array form here and let callers handle the lookup
 * semantics themselves.
 */
export type GeneLookupResponse = GeneApiData[];

export type GeneInputType = 'hgnc' | 'symbol';

export interface ListGenesParams {
  sort?: string;
  filter?: string;
  fields?: string;
  page_after?: string;
  page_size?: string;
  fspec?: string;
}

/**
 * Wire envelope for `GET /api/gene` (and the other cursor-paginated list
 * endpoints). `meta` and `links` mirror the plumber convention; `data` is
 * the nested gene tibble.
 */
export interface PaginatedGeneResponse {
  meta: unknown[];
  data: GeneApiData[];
  links?: unknown[];
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * GET /api/gene/<gene_input>
 * Pass `input_type: 'hgnc'` (default) when looking up by `HGNC:` prefix or
 * bare integer id, or `'symbol'` to match by gene symbol (case-insensitive
 * on the server).
 *
 * Returns a possibly-empty array — callers should check `length` before
 * indexing. Parallels `GeneView.vue`'s `loadGeneInfo()` dual-lookup pattern.
 */
export async function getGene(
  gene_input: string | number,
  input_type: GeneInputType = 'hgnc',
  config?: AxiosRequestConfig,
): Promise<GeneLookupResponse> {
  const path = `/api/gene/${encodeURIComponent(String(gene_input))}`;
  return apiClient.get<GeneLookupResponse>(path, {
    ...config,
    params: { ...(config?.params as object | undefined), input_type },
  });
}

/**
 * Convenience wrapper for `getGene(symbol, 'symbol')`. Returns the same
 * possibly-empty array as `getGene`.
 */
export async function getGeneBySymbol(
  symbol: string,
  config?: AxiosRequestConfig,
): Promise<GeneLookupResponse> {
  return getGene(symbol, 'symbol', config);
}

/**
 * GET /api/gene
 * Cursor-paginated listing. All params map directly onto the plumber
 * endpoint's query string (`sort`, `filter`, `fields`, `page_after`,
 * `page_size`, `fspec`).
 */
export async function listGenes(
  params: ListGenesParams = {},
  config?: AxiosRequestConfig,
): Promise<PaginatedGeneResponse> {
  return apiClient.get<PaginatedGeneResponse>('/api/gene', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}
