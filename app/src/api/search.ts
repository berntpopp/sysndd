// app/src/api/search.ts
//
// Search resource helpers (entity, ontology, gene, inheritance fuzzy search).
//
// Mirrors api/endpoints/search_endpoints.R (mounted at /api/search).
// Phase E.E2: filled during v11.1 Wave 1a (W3).
//
// Used by `SearchView.vue` (W7) and curate views' typeahead inputs.

import type { AxiosRequestConfig } from 'axios';
import { apiClient } from './client';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface SearchEntityParams {
  /** R coerces "TRUE"/"FALSE". TRUE pivots-wide, FALSE returns rows. */
  helper?: boolean;
  limit?: number;
  offset?: number;
}

/**
 * Helper-format response — pivot-wider keyed by `results`. Each value is the
 * nested list of search rows for that result string.
 */
export type EntitySearchHelperResponse = Record<string, unknown>;

/**
 * Row-format response (`helper=false`) — flat list of one row per match.
 */
export interface EntitySearchRow {
  entity_id: number;
  search: string;
  results: string;
  searchdist: number;
  link: string | null;
}

export interface OntologySearchParams {
  tree?: boolean;
  limit?: number;
  offset?: number;
}

export interface OntologyTreeNode {
  id: string;
  label: string;
  disease_ontology_id_version: string;
  disease_ontology_id: string;
  disease_ontology_name: string;
  search: string;
  searchdist: number;
}

export interface GeneSearchParams {
  tree?: boolean;
  limit?: number;
  offset?: number;
}

export interface GeneSearchTreeNode {
  id: string;
  label: string;
  symbol: string;
  name: string;
  search: string;
  searchdist: number;
}

export interface InheritanceSearchParams {
  tree?: boolean;
  limit?: number;
  offset?: number;
}

export interface InheritanceSearchTreeNode {
  id?: string;
  label?: string;
  hpo_mode_of_inheritance_term?: string;
  hpo_mode_of_inheritance_term_name?: string;
  result?: string;
  search?: string;
  searchdist?: number;
  [key: string]: unknown;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * GET /api/search/<searchterm>
 * Mirrors api/endpoints/search_endpoints.R:32 (handler `@get <searchterm>`).
 *
 * Fuzzy entity search across hgnc_id, symbol, disease ontology, etc.
 * `helper=true` (default) returns the pivot-wide shape; `helper=false`
 * returns one row per match.
 */
export async function searchEntities(
  searchterm: string,
  params: SearchEntityParams = {},
  config?: AxiosRequestConfig,
): Promise<EntitySearchHelperResponse | EntitySearchRow[]> {
  const path = `/api/search/${encodeURIComponent(searchterm)}`;
  return apiClient.get<EntitySearchHelperResponse | EntitySearchRow[]>(path, {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * GET /api/search/ontology/<searchterm>
 * Mirrors api/endpoints/search_endpoints.R:122 (handler `@get ontology/<searchterm>`).
 *
 * Fuzzy disease-ontology search. `tree=true` returns tree-formatted nodes
 * for treeselect dropdowns; `tree=false` returns the pivot-wide shape.
 *
 * The overloads narrow the return type when `tree: true` is passed as a
 * literal so callers don't need an `as unknown as` cast at the call site.
 * The boolean-tree variant covers the dynamic case (e.g. when the flag is
 * computed at runtime).
 */
export async function searchOntology(
  searchterm: string,
  params: OntologySearchParams & { tree: true },
  config?: AxiosRequestConfig,
): Promise<OntologyTreeNode[]>;
export async function searchOntology(
  searchterm: string,
  params?: OntologySearchParams,
  config?: AxiosRequestConfig,
): Promise<OntologyTreeNode[] | Record<string, unknown>>;
export async function searchOntology(
  searchterm: string,
  params: OntologySearchParams = {},
  config?: AxiosRequestConfig,
): Promise<OntologyTreeNode[] | Record<string, unknown>> {
  const path = `/api/search/ontology/${encodeURIComponent(searchterm)}`;
  return apiClient.get<OntologyTreeNode[] | Record<string, unknown>>(path, {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * GET /api/search/gene/<searchterm>
 * Mirrors api/endpoints/search_endpoints.R:197 (handler `@get gene/<searchterm>`).
 *
 * Fuzzy gene search. The overloads narrow the return type for the
 * tree-mode call site (`{ tree: true }`) — see the matching pattern in
 * `searchOntology`.
 */
export async function searchGene(
  searchterm: string,
  params: GeneSearchParams & { tree: true },
  config?: AxiosRequestConfig,
): Promise<GeneSearchTreeNode[]>;
export async function searchGene(
  searchterm: string,
  params?: GeneSearchParams,
  config?: AxiosRequestConfig,
): Promise<GeneSearchTreeNode[] | Record<string, unknown>>;
export async function searchGene(
  searchterm: string,
  params: GeneSearchParams = {},
  config?: AxiosRequestConfig,
): Promise<GeneSearchTreeNode[] | Record<string, unknown>> {
  const path = `/api/search/gene/${encodeURIComponent(searchterm)}`;
  return apiClient.get<GeneSearchTreeNode[] | Record<string, unknown>>(path, {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * GET /api/search/inheritance/<searchterm>
 * Mirrors api/endpoints/search_endpoints.R:271 (handler `@get inheritance/<searchterm>`).
 *
 * Fuzzy mode-of-inheritance search.
 */
export async function searchInheritance(
  searchterm: string,
  params: InheritanceSearchParams = {},
  config?: AxiosRequestConfig,
): Promise<InheritanceSearchTreeNode[] | Record<string, unknown>> {
  const path = `/api/search/inheritance/${encodeURIComponent(searchterm)}`;
  return apiClient.get<InheritanceSearchTreeNode[] | Record<string, unknown>>(path, {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}
