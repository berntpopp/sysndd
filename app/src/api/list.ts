// app/src/api/list.ts
//
// Lookup-list resource helpers (status categories, phenotypes, inheritance,
// variation ontology).
//
// Mirrors api/endpoints/list_endpoints.R (mounted at /api/list).
// Phase E.E2: filled during v11.1 Wave 1a (W3).
//
// Each endpoint accepts `?tree=TRUE|FALSE` to toggle between a tree-shaped
// response (used by treeselect dropdowns) and a paginated raw-data envelope.
// The two shapes are surfaced as a discriminated union so callers can pick
// the variant they need at the type level.

import type { AxiosRequestConfig } from 'axios';
import { apiClient } from './client';

// ---------------------------------------------------------------------------
// Common types
// ---------------------------------------------------------------------------

/**
 * Common pagination params used by every list endpoint when `tree=FALSE`.
 * `page_size` accepts the literal string `"all"` for "no pagination".
 */
export interface ListPaginationParams {
  page_after?: string | number;
  page_size?: string;
}

/**
 * Tree-shaped node returned by the `?tree=TRUE` variants. Some endpoints
 * (`phenotype`, `variation_ontology`) nest a `children` array of secondary
 * nodes; flat endpoints (`status`, `inheritance`) omit it.
 */
export interface TreeNode {
  id: string | number;
  label: string;
  children?: Array<{ id: string | number; label: string }>;
}

/**
 * Generic paginated envelope used by the `?tree=FALSE` variants. The data
 * shape is endpoint-specific (typed below).
 */
export interface PaginatedListResponse<T> {
  links: unknown;
  meta: unknown;
  data: T[];
}

// ---------------------------------------------------------------------------
// Per-endpoint row types (paginated form)
// ---------------------------------------------------------------------------

export interface StatusCategoryRow {
  category_id: number;
  category: string;
  [key: string]: unknown;
}

export interface PhenotypeRow {
  phenotype_id: string;
  HPO_term: string;
  HPO_term_definition?: string | null;
  HPO_term_synonyms?: string | null;
}

export interface InheritanceRow {
  hpo_mode_of_inheritance_term: string;
  /** R nests grouped values under this key — opaque to the client. */
  values?: unknown;
  [key: string]: unknown;
}

export interface VariationOntologyRow {
  vario_id: string;
  vario_name: string;
  definition?: string | null;
}

// ---------------------------------------------------------------------------
// Helpers — paginated form
// ---------------------------------------------------------------------------

/**
 * Convert the boolean `tree` flag into the literal `"TRUE"`/`"FALSE"` strings
 * the R server expects (the same convention used by `entity.ts`).
 */
function treeQuery(tree: boolean): { tree: 'TRUE' | 'FALSE' } {
  return { tree: tree ? 'TRUE' : 'FALSE' };
}

/**
 * GET /api/list/status?tree=FALSE
 * Mirrors api/endpoints/list_endpoints.R:32 (handler `@get status`).
 *
 * Paginated raw status-category list.
 */
export async function listStatusCategories(
  params: ListPaginationParams = {},
  config?: AxiosRequestConfig
): Promise<PaginatedListResponse<StatusCategoryRow>> {
  return apiClient.get<PaginatedListResponse<StatusCategoryRow>>('/api/list/status', {
    ...config,
    params: { ...(config?.params as object | undefined), ...treeQuery(false), ...params },
  });
}

/**
 * GET /api/list/status?tree=TRUE
 *
 * Tree-formatted status categories for treeselect components.
 */
export async function listStatusCategoriesTree(config?: AxiosRequestConfig): Promise<TreeNode[]> {
  return apiClient.get<TreeNode[]>('/api/list/status', {
    ...config,
    params: { ...(config?.params as object | undefined), ...treeQuery(true) },
  });
}

/**
 * GET /api/list/phenotype?tree=FALSE
 * Mirrors api/endpoints/list_endpoints.R:84 (handler `@get phenotype`).
 *
 * Paginated raw phenotype list (HPO terms).
 */
export async function listPhenotypes(
  params: ListPaginationParams = {},
  config?: AxiosRequestConfig
): Promise<PaginatedListResponse<PhenotypeRow>> {
  return apiClient.get<PaginatedListResponse<PhenotypeRow>>('/api/list/phenotype', {
    ...config,
    params: { ...(config?.params as object | undefined), ...treeQuery(false), ...params },
  });
}

/**
 * GET /api/list/phenotype?tree=TRUE
 *
 * Tree-formatted phenotype list with modifier children (treeselect input).
 */
export async function listPhenotypesTree(config?: AxiosRequestConfig): Promise<TreeNode[]> {
  return apiClient.get<TreeNode[]>('/api/list/phenotype', {
    ...config,
    params: { ...(config?.params as object | undefined), ...treeQuery(true) },
  });
}

/**
 * GET /api/list/inheritance?tree=FALSE
 * Mirrors api/endpoints/list_endpoints.R:156 (handler `@get inheritance`).
 *
 * Paginated raw mode-of-inheritance list.
 */
export async function listInheritance(
  params: ListPaginationParams = {},
  config?: AxiosRequestConfig
): Promise<PaginatedListResponse<InheritanceRow>> {
  return apiClient.get<PaginatedListResponse<InheritanceRow>>('/api/list/inheritance', {
    ...config,
    params: { ...(config?.params as object | undefined), ...treeQuery(false), ...params },
  });
}

/**
 * GET /api/list/inheritance?tree=TRUE
 *
 * Tree-formatted inheritance terms (id + label only).
 */
export async function listInheritanceTree(config?: AxiosRequestConfig): Promise<TreeNode[]> {
  return apiClient.get<TreeNode[]>('/api/list/inheritance', {
    ...config,
    params: { ...(config?.params as object | undefined), ...treeQuery(true) },
  });
}

/**
 * GET /api/list/variation_ontology?tree=FALSE
 * Mirrors api/endpoints/list_endpoints.R:221 (handler `@get variation_ontology`).
 *
 * Paginated raw variation-ontology list.
 */
export async function listVariationOntology(
  params: ListPaginationParams = {},
  config?: AxiosRequestConfig
): Promise<PaginatedListResponse<VariationOntologyRow>> {
  return apiClient.get<PaginatedListResponse<VariationOntologyRow>>(
    '/api/list/variation_ontology',
    {
      ...config,
      params: { ...(config?.params as object | undefined), ...treeQuery(false), ...params },
    }
  );
}

/**
 * GET /api/list/variation_ontology?tree=TRUE
 *
 * Tree-formatted VariO terms with modifier children.
 */
export async function listVariationOntologyTree(config?: AxiosRequestConfig): Promise<TreeNode[]> {
  return apiClient.get<TreeNode[]>('/api/list/variation_ontology', {
    ...config,
    params: { ...(config?.params as object | undefined), ...treeQuery(true) },
  });
}
