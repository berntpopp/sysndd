// app/src/api/entity.ts
//
// Entity (gene-disease association) resource helpers.
//
// Mirrors api/endpoints/entity_endpoints.R (mounted at /api/entity).
// Phase E.E2: filled during v11.1 Wave 1a (W3).
//
// Big surface — covers list/browse + create/rename/deactivate + per-entity
// nested resources (phenotypes, variation, review, status, publications).
// Used heavily by W4 (curate views) and W7 (pages + tables).

import type { AxiosRequestConfig } from 'axios';
import { apiClient } from './client';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type EntityListFormat = 'json' | 'xlsx';

export interface ListEntitiesParams {
  sort?: string;
  filter?: string;
  fields?: string;
  page_after?: string | number;
  page_size?: string;
  fspec?: string;
  format?: EntityListFormat;
  /**
   * When true, the server pushes the filter to SQL and skips the global-fspec
   * computation (only the filtered-set fspec is returned; count == count_filtered).
   * Use for embedded callers (Genes/Entities detail pages) that don't render
   * the filter dropdowns. ~20–30 ms faster per call. Default false.
   */
  compact?: boolean;
}

/**
 * One entity row in the list response. Keys are dynamic (driven by the
 * `fields` query param and the underlying view), so we surface a generic
 * record. Common columns: `entity_id`, `symbol`, `disease_ontology_name`,
 * `hpo_mode_of_inheritance_term_name`, `category`, `ndd_phenotype_word`,
 * `details`, `synopsis`.
 */
export type EntityRow = Record<string, unknown>;

/**
 * Wire envelope from `GET /api/entity/?format=json` — same shape as other
 * cursor-paginated endpoints (genes, comparisons, panels, etc.).
 */
export interface EntityListResponse {
  links: unknown;
  meta: unknown;
  data: EntityRow[];
}

// ---------------------------------------------------------------------------
// Create / rename / deactivate request types
// ---------------------------------------------------------------------------

/**
 * Body element shape for `POST /api/entity/create` (`create_json`).
 *
 * The R handler accepts a flexible shape — phenotypes/variation can come as
 * either `{value: "modifier-id-rest"}[]` or `{phenotype_id, modifier_id}[]`.
 * The typed client mirrors the R-handler-tolerant union.
 */
export interface EntityCreatePayload {
  entity: Record<string, unknown> & {
    hgnc_id: string;
    disease_ontology_id_version: string;
    hpo_mode_of_inheritance_term: string;
    ndd_phenotype: number | string;
  };
  review: {
    synopsis?: unknown;
    comment?: string | null;
    literature?: {
      additional_references?: Array<{ value: string }>;
      gene_review?: Array<{ value: string }>;
    };
    phenotypes?: Array<{ value?: string; phenotype_id?: string; modifier_id?: string }>;
    variation_ontology?: Array<{ value?: string; vario_id?: string; modifier_id?: string }>;
  };
  status: {
    category_id: number | string;
    problematic?: number | string;
  };
}

export interface EntityCreateRequest {
  create_json: EntityCreatePayload;
}

export interface EntityCreateParams {
  /** R uses a string boolean — `"true"` / `"false"`. */
  direct_approval?: boolean | string;
}

/**
 * Generic mutation envelope used by entity create / rename / deactivate.
 * The handler emits `{ status, message, entry?, error? }`.
 */
export interface EntityMutationResponse {
  status: number;
  message?: string;
  entry?: { entity_id?: number | string;[key: string]: unknown };
  error?: string | null;
}

export interface EntityRenamePayload {
  entity: {
    entity_id: number;
    hgnc_id: string;
    hpo_mode_of_inheritance_term: string;
    ndd_phenotype: number | string;
    disease_ontology_id_version: string;
  };
}

export interface EntityRenameRequest {
  rename_json: EntityRenamePayload;
}

export interface EntityDeactivatePayload {
  entity: {
    entity_id: number;
    hgnc_id: string;
    hpo_mode_of_inheritance_term: string;
    ndd_phenotype: number | string;
    is_active: number | string;
    replaced_by?: number | string | null;
  };
}

export interface EntityDeactivateRequest {
  deactivate_json: EntityDeactivatePayload;
}

// ---------------------------------------------------------------------------
// Per-entity nested resource types
// ---------------------------------------------------------------------------

export interface NestedQueryParams {
  /** R uses uppercase TRUE/FALSE; the helper accepts boolean and stringifies. */
  current_review?: boolean | 'TRUE' | 'FALSE';
}

export interface EntityPhenotypeRow {
  entity_id: number;
  phenotype_id: string;
  HPO_term: string;
  modifier_id: number | string | null;
}

export interface EntityVariationRow {
  entity_id: number;
  vario_id: string;
  vario_name: string;
  modifier_id: number | string | null;
}

export interface EntityReviewRow {
  entity_id: number;
  review_id: number | null;
  synopsis: string | null;
  review_date: string | null;
  comment: string | null;
}

export interface EntityStatusRow {
  status_id: number;
  entity_id: number;
  category: string;
  category_id: number;
  status_date: string;
  comment: string | null;
  problematic: number | string | null;
}

export interface EntityPublicationRow {
  entity_id: number;
  publication_id: string;
  publication_type: string | null;
  is_reviewed: number | string | null;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * GET /api/entity/
 * Mirrors api/endpoints/entity_endpoints.R:44 (handler `@get /`).
 *
 * Cursor-paginated entity listing. `format=json` (default) returns the
 * envelope below; `format=xlsx` returns a binary attachment — for that path
 * use `listEntitiesXlsx()`.
 */
export async function listEntities(
  params: ListEntitiesParams = {},
  config?: AxiosRequestConfig,
): Promise<EntityListResponse> {
  return apiClient.get<EntityListResponse>('/api/entity/', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params, format: 'json' },
  });
}

/**
 * GET /api/entity/?format=xlsx
 * Same handler as `listEntities`, but surfaces the XLSX byte stream as a
 * `Blob` for download.
 */
export async function listEntitiesXlsx(
  params: Omit<ListEntitiesParams, 'format'> = {},
  config?: AxiosRequestConfig,
): Promise<Blob> {
  const response = await apiClient.raw.get<Blob>('/api/entity/', {
    ...config,
    params: { ...(config?.params as object | undefined), ...params, format: 'xlsx' },
    responseType: 'blob',
  });
  return response.data;
}

/**
 * POST /api/entity/create
 * Mirrors api/endpoints/entity_endpoints.R:219 (handler `@post /create`).
 *
 * Curator-only. Creates a new entity with review, status, optional
 * publications/phenotypes/variation. Returns 201 on success, otherwise the
 * service-layer error status (4xx/5xx).
 *
 * Throws AxiosError on non-2xx (the success case is 201, which axios treats
 * as 2xx and resolves normally).
 */
export async function createEntity(
  body: EntityCreateRequest,
  params: EntityCreateParams = {},
  config?: AxiosRequestConfig,
): Promise<EntityMutationResponse> {
  return apiClient.post<EntityMutationResponse, EntityCreateRequest>(
    '/api/entity/create',
    body,
    {
      ...config,
      params: { ...(config?.params as object | undefined), ...params },
    },
  );
}

/**
 * POST /api/entity/rename
 * Mirrors api/endpoints/entity_endpoints.R:409 (handler `@post /rename`).
 *
 * Curator-only. Replaces an entity's `disease_ontology_id_version`. Only
 * accepts disease-ontology renames; any other field change returns 400.
 */
export async function renameEntity(
  body: EntityRenameRequest,
  config?: AxiosRequestConfig,
): Promise<EntityMutationResponse> {
  return apiClient.post<EntityMutationResponse, EntityRenameRequest>(
    '/api/entity/rename',
    body,
    config,
  );
}

/**
 * POST /api/entity/deactivate
 * Mirrors api/endpoints/entity_endpoints.R:616 (handler `@post /deactivate`).
 *
 * Curator-only. Deactivates an entity (sets `is_active = 0` and optional
 * `replaced_by`). Any other entity-field mutation returns 400.
 */
export async function deactivateEntity(
  body: EntityDeactivateRequest,
  config?: AxiosRequestConfig,
): Promise<EntityMutationResponse> {
  return apiClient.post<EntityMutationResponse, EntityDeactivateRequest>(
    '/api/entity/deactivate',
    body,
    config,
  );
}

/**
 * Build a normalised query-param record for the nested-resource endpoints
 * which all accept `?current_review=TRUE|FALSE`.
 */
function nestedQuery(
  params: NestedQueryParams = {},
): Record<string, string> | undefined {
  if (params.current_review === undefined) {
    return undefined;
  }
  const value =
    typeof params.current_review === 'boolean'
      ? params.current_review
        ? 'TRUE'
        : 'FALSE'
      : params.current_review;
  return { current_review: value };
}

/**
 * GET /api/entity/<sysndd_id>/phenotypes
 * Mirrors api/endpoints/entity_endpoints.R:695 (handler `@get /<sysndd_id>/phenotypes`).
 *
 * Returns phenotypes for the given entity. By default only phenotypes from
 * the currently-active review (`is_primary = 1`) are returned; pass
 * `current_review: false` for the legacy "all active" view.
 */
export async function getEntityPhenotypes(
  sysndd_id: number | string,
  params: NestedQueryParams = {},
  config?: AxiosRequestConfig,
): Promise<EntityPhenotypeRow[]> {
  const path = `/api/entity/${encodeURIComponent(String(sysndd_id))}/phenotypes`;
  const query = nestedQuery(params);
  return apiClient.get<EntityPhenotypeRow[]>(path, {
    ...config,
    params: { ...(config?.params as object | undefined), ...(query ?? {}) },
  });
}

/**
 * GET /api/entity/<sysndd_id>/variation
 * Mirrors api/endpoints/entity_endpoints.R:764 (handler `@get /<sysndd_id>/variation`).
 *
 * Returns variation-ontology terms for the entity (current review by default).
 */
export async function getEntityVariation(
  sysndd_id: number | string,
  params: NestedQueryParams = {},
  config?: AxiosRequestConfig,
): Promise<EntityVariationRow[]> {
  const path = `/api/entity/${encodeURIComponent(String(sysndd_id))}/variation`;
  const query = nestedQuery(params);
  return apiClient.get<EntityVariationRow[]>(path, {
    ...config,
    params: { ...(config?.params as object | undefined), ...(query ?? {}) },
  });
}

/**
 * GET /api/entity/<sysndd_id>/review
 * Mirrors api/endpoints/entity_endpoints.R:823 (handler `@get /<sysndd_id>/review`).
 *
 * Returns the primary clinical synopsis for the entity. Always returns at
 * least one row (an empty-keys row when the entity has no primary review).
 */
export async function getEntityReview(
  sysndd_id: number | string,
  config?: AxiosRequestConfig,
): Promise<EntityReviewRow[]> {
  const path = `/api/entity/${encodeURIComponent(String(sysndd_id))}/review`;
  return apiClient.get<EntityReviewRow[]>(path, config);
}

/**
 * GET /api/entity/<sysndd_id>/status
 * Mirrors api/endpoints/entity_endpoints.R:863 (handler `@get /<sysndd_id>/status`).
 *
 * Returns the active status rows for the entity ordered by status_date.
 */
export async function getEntityStatus(
  sysndd_id: number | string,
  config?: AxiosRequestConfig,
): Promise<EntityStatusRow[]> {
  const path = `/api/entity/${encodeURIComponent(String(sysndd_id))}/status`;
  return apiClient.get<EntityStatusRow[]>(path, config);
}

/**
 * GET /api/entity/<sysndd_id>/publications
 * Mirrors api/endpoints/entity_endpoints.R:913 (handler `@get /<sysndd_id>/publications`).
 *
 * Returns publications attached to the entity (current review by default).
 */
export async function getEntityPublications(
  sysndd_id: number | string,
  params: NestedQueryParams = {},
  config?: AxiosRequestConfig,
): Promise<EntityPublicationRow[]> {
  const path = `/api/entity/${encodeURIComponent(String(sysndd_id))}/publications`;
  const query = nestedQuery(params);
  return apiClient.get<EntityPublicationRow[]>(path, {
    ...config,
    params: { ...(config?.params as object | undefined), ...(query ?? {}) },
  });
}
