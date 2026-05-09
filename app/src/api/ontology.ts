// app/src/api/ontology.ts
//
// Ontology resource helpers (disease ontology terms + VariO admin).
//
// Mirrors api/endpoints/ontology_endpoints.R (mounted at /api/ontology).
// Phase E.E2: filled during v11.1 Wave 1a (W3).
//
// Async ontology UPDATEs (the safeguard / blocked workflow described in
// CLAUDE.md / MEMORY.md) live on `admin.ts` (`updateOntologyAsync`,
// `forceApplyOntology`) — the helpers here are the lookup + variant-table
// admin surface only.

import type { AxiosRequestConfig } from 'axios';
import { apiClient } from './client';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type OntologyInputType = 'ontology_id' | string;

export interface GetOntologyParams {
  input_type?: OntologyInputType;
}

/**
 * Wire shape from `GET /api/ontology/<ontology_input>`. The R handler runs a
 * `summarize_all(~ paste(unique(.), collapse = ";"))` followed by a
 * `str_split` on every column, so each scalar arrives as an array of
 * de-duplicated string fragments. We surface that fidelity as `string[]`.
 */
export interface OntologyTerm {
  disease_ontology_id_version: string[];
  disease_ontology_id: string[];
  disease_ontology_name: string[];
  disease_ontology_source: string[];
  disease_ontology_is_specific: string[];
  hgnc_id: string[];
  hpo_mode_of_inheritance_term: string[];
  DOID: string[];
  MONDO: string[];
  Orphanet: string[];
  EFO: string[];
  hpo_mode_of_inheritance_term_name?: string[];
  inheritance_filter?: string[];
}

/**
 * Convenience type for the array shape — the handler returns multiple rows
 * grouped by `disease_ontology_id`.
 */
export type OntologyLookupResponse = OntologyTerm[];

export interface ListVariantOntologyParams {
  filter?: string;
  /** Default `"+vario_id"`. Prefix `+`/`-` for asc/desc. */
  sort?: string;
  page_after?: string | number;
  page_size?: string | number;
  fspec?: string;
}

export interface VariantOntologyRow {
  vario_id: string;
  vario_name: string;
  definition: string | null;
  obsolete: number | string | null;
  is_active: number | string | null;
  sort: number | null;
  update_date: string | null;
}

export interface VariantOntologyListResponse {
  links: unknown;
  meta: unknown;
  data: VariantOntologyRow[];
}

export interface UpdateVariantOntologyRequest {
  ontology_details: {
    vario_id: string;
    [field: string]: unknown;
  };
}

export interface UpdateVariantOntologyResponse {
  message?: string;
  error?: string;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * GET /api/ontology/<ontology_input>
 * Mirrors api/endpoints/ontology_endpoints.R:32 (handler `@get <ontology_input>`).
 *
 * Looks up an ontology term by `disease_ontology_id` or `disease_ontology_name`.
 * Public — no auth filter.
 */
export async function getOntology(
  ontology_input: string,
  params: GetOntologyParams = {},
  config?: AxiosRequestConfig
): Promise<OntologyLookupResponse> {
  const path = `/api/ontology/${encodeURIComponent(ontology_input)}`;
  return apiClient.get<OntologyLookupResponse>(path, {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * GET /api/ontology/variant/table
 * Mirrors api/endpoints/ontology_endpoints.R:101 (handler `@get variant/table`).
 *
 * Administrator-only. Cursor-paginated VariO listing with server-side
 * filtering and sorting.
 */
export async function listVariantOntology(
  params: ListVariantOntologyParams = {},
  config?: AxiosRequestConfig
): Promise<VariantOntologyListResponse> {
  return apiClient.get<VariantOntologyListResponse>('/api/ontology/variant/table', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params },
  });
}

/**
 * PUT /api/ontology/variant/update
 * Mirrors api/endpoints/ontology_endpoints.R:209 (handler `@put variant/update`).
 *
 * Administrator-only. Updates fields of an existing VariO term. The body must
 * include `ontology_details.vario_id`. Returns `{ message }` on success.
 *
 * Throws AxiosError on non-2xx (400 missing vario_id / no fields,
 * 404 vario_id not found, 500 update failed).
 */
export async function updateVariantOntology(
  body: UpdateVariantOntologyRequest,
  config?: AxiosRequestConfig
): Promise<UpdateVariantOntologyResponse> {
  return apiClient.put<UpdateVariantOntologyResponse, UpdateVariantOntologyRequest>(
    '/api/ontology/variant/update',
    body,
    config
  );
}
