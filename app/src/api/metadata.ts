// Administrator-only client for the curation metadata vocabulary CRUD surface
// (issue #32). Backed by /api/metadata; all writes are JSON bodies.
//
// Editability tiers (mirrors the API descriptor):
//   - editable === true        -> full CRUD (create / update / delete)
//   - editable === 'anchored'  -> update curated fields + activate only
//
// Goes through the typed apiClient so the Bearer token + 401 interceptor apply.
import { apiClient } from './client';

/** A single column value coming back from a vocabulary row. */
export type MetadataCellValue = string | number | boolean | null;

/** A vocabulary row is a flat record of column -> value. */
export type MetadataRow = Record<string, MetadataCellValue>;

/** Editability classification of a vocabulary. */
export type MetadataEditable = boolean | 'anchored';

/** Descriptor for one managed vocabulary (from GET /api/metadata). */
export interface MetadataVocabulary {
  slug: string;
  label: string;
  table: string;
  pk: string;
  pk_type: 'integer' | 'character';
  editable: MetadataEditable;
  managed: string;
  fields: string[];
  has_is_active?: boolean;
  has_sort?: boolean;
}

/** Metadata returned alongside a vocabulary's rows (GET /api/metadata/:slug). */
export interface MetadataListMeta {
  slug: string;
  label: string;
  table: string;
  pk: string;
  editable: MetadataEditable;
  managed: string;
  fields: string[];
}

export interface MetadataListResponse {
  meta: MetadataListMeta;
  data: MetadataRow[];
}

export interface MetadataMutationResult {
  status: number;
  message: string;
  entry?: { pk: number | string };
}

/** R/Plumber wraps scalars in 1-element arrays; the catalog endpoint returns a
 * `data` array of descriptors. The fields below are normalised by the caller
 * only where a scalar shape is required. */
interface MetadataCatalogResponse {
  data: MetadataVocabulary[];
}

/**
 * Fetch the catalog of managed vocabularies and their editability tiers.
 * GET /api/metadata
 */
export async function fetchMetadataCatalog(): Promise<MetadataVocabulary[]> {
  const response = await apiClient.get<MetadataCatalogResponse>('/api/metadata');
  return response.data;
}

/**
 * List all rows of a vocabulary, including inactive entries (admin view).
 * GET /api/metadata/:slug
 */
export async function fetchMetadataRows(slug: string): Promise<MetadataListResponse> {
  return apiClient.get<MetadataListResponse>(`/api/metadata/${encodeURIComponent(slug)}`);
}

/**
 * Create a new entry in a SysNDD-managed vocabulary.
 * POST /api/metadata/:slug
 */
export async function createMetadataRow(
  slug: string,
  payload: Record<string, MetadataCellValue>
): Promise<MetadataMutationResult> {
  return apiClient.post<MetadataMutationResult>(
    `/api/metadata/${encodeURIComponent(slug)}`,
    payload
  );
}

/**
 * Update an existing vocabulary entry.
 * PUT /api/metadata/:slug/:id
 */
export async function updateMetadataRow(
  slug: string,
  id: string | number,
  payload: Record<string, MetadataCellValue>
): Promise<MetadataMutationResult> {
  return apiClient.put<MetadataMutationResult>(
    `/api/metadata/${encodeURIComponent(slug)}/${encodeURIComponent(String(id))}`,
    payload
  );
}

/**
 * Soft-delete (deactivate) a vocabulary entry. The API returns a 400 when the
 * value is still referenced by curation data; callers should surface that
 * message via extractApiErrorMessage rather than treating it as success.
 * DELETE /api/metadata/:slug/:id
 */
export async function deleteMetadataRow(
  slug: string,
  id: string | number
): Promise<MetadataMutationResult> {
  return apiClient.delete<MetadataMutationResult>(
    `/api/metadata/${encodeURIComponent(slug)}/${encodeURIComponent(String(id))}`
  );
}
