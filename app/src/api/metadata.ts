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

/** R/Plumber serializes scalars as 1-element arrays. The catalog/list endpoints
 * return descriptor scalars (slug, pk, label, ...) in that wrapped shape, so we
 * normalise them at the client boundary to honour the declared `string` types.
 * Without this, `vocab.pk` reaches `humanizeLabel` as an array and crashes the
 * ManageMetadata view with `field.replace is not a function`. */
interface MetadataCatalogResponse {
  data: unknown[];
}

/** Unwrap a Plumber 1-element array to its scalar; pass scalars through. */
function unwrapScalar<T>(value: T | T[]): T {
  return Array.isArray(value) ? (value[0] as T) : value;
}

/** Normalise a raw catalog/meta descriptor: unwrap scalar fields and coerce
 * `fields` to a `string[]` and optional boolean flags. */
function normalizeVocabulary(raw: Record<string, unknown>): MetadataVocabulary {
  const fields = Array.isArray(raw.fields)
    ? (raw.fields as unknown[]).map((f) => String(unwrapScalar(f as string)))
    : [];
  return {
    slug: String(unwrapScalar(raw.slug as string)),
    label: String(unwrapScalar(raw.label as string)),
    table: String(unwrapScalar(raw.table as string)),
    pk: String(unwrapScalar(raw.pk as string)),
    pk_type: unwrapScalar(raw.pk_type as MetadataVocabulary['pk_type']),
    editable: unwrapScalar(raw.editable as MetadataEditable),
    managed: String(unwrapScalar(raw.managed as string)),
    fields,
    has_is_active:
      raw.has_is_active != null ? Boolean(unwrapScalar(raw.has_is_active as boolean)) : undefined,
    has_sort: raw.has_sort != null ? Boolean(unwrapScalar(raw.has_sort as boolean)) : undefined,
  };
}

/** Unwrap each cell value of a vocabulary row (Plumber wraps scalar cells too). */
function normalizeRow(raw: Record<string, unknown>): MetadataRow {
  const out: MetadataRow = {};
  for (const [key, value] of Object.entries(raw)) {
    out[key] = unwrapScalar(value) as MetadataCellValue;
  }
  return out;
}

/**
 * Fetch the catalog of managed vocabularies and their editability tiers.
 * GET /api/metadata
 */
export async function fetchMetadataCatalog(): Promise<MetadataVocabulary[]> {
  const response = await apiClient.get<MetadataCatalogResponse>('/api/metadata');
  return (response.data ?? []).map((v) => normalizeVocabulary(v as Record<string, unknown>));
}

/**
 * List all rows of a vocabulary, including inactive entries (admin view).
 * GET /api/metadata/:slug
 */
export async function fetchMetadataRows(slug: string): Promise<MetadataListResponse> {
  const response = await apiClient.get<{ meta: Record<string, unknown>; data: unknown[] }>(
    `/api/metadata/${encodeURIComponent(slug)}`
  );
  const meta = normalizeVocabulary(response.meta);
  return {
    meta: {
      slug: meta.slug,
      label: meta.label,
      table: meta.table,
      pk: meta.pk,
      editable: meta.editable,
      managed: meta.managed,
      fields: meta.fields,
    },
    data: (response.data ?? []).map((r) => normalizeRow(r as Record<string, unknown>)),
  };
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
