// app/src/api/hash.ts
//
// Hash-link resource helper.
//
// Mirrors api/endpoints/hash_endpoints.R (mounted at /api/hash).
// Phase E.E2: filled during v11.1 Wave 1a (W3).
//
// The hash endpoint takes an arbitrary list of identifiers (gene symbols,
// HGNC ids, entity ids) and stores them keyed by a deterministic hash so a
// shareable shortlink can be produced for the consumer view (`SearchView`,
// `OntologyView`, custom-set workflows).

import type { AxiosRequestConfig } from 'axios';
import { apiClient, unwrapScalar } from './client';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/**
 * Body shape for `POST /api/hash/create`.
 *
 * `json_data` is the raw list to be hashed; the R handler accepts whatever
 * shape the caller posts (typically `string[]` of symbols/ids, but tibble-row
 * arrays are also supported).
 *
 * `endpoint` is the namespace key — defaults to `/api/gene` server-side.
 * Callers pass `/api/entity`, `/api/ontology`, etc. when the shortlink should
 * resolve into a non-gene context.
 */
export interface HashCreateRequest {
  json_data: unknown;
  endpoint?: string;
}

/**
 * Response from `POST /api/hash/create`. The R handler returns the result of
 * `post_db_hash()` which is a list with the persisted hash key. Plumber omits
 * `@serializer unboxedJSON`, so scalar fields arrive as 1-element arrays —
 * `unwrapScalar` collapses them on the way out.
 */
export interface HashLink {
  hash: string;
  endpoint?: string;
  /** Pass-through of any additional fields emitted by `post_db_hash()`. */
  [key: string]: unknown;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/**
 * POST /api/hash/create
 * Mirrors api/endpoints/hash_endpoints.R:34 (handler `@post create`).
 *
 * Creates a hash link for the provided identifier list.
 *
 * The R handler emits the response without `@serializer unboxedJSON`, so
 * scalar fields come back as 1-element arrays. We unwrap the top-level shape
 * so callers receive a flat object.
 *
 * Throws AxiosError on non-2xx (400 if `json_data` is omitted; 500 on DB
 * failures).
 */
export async function createHash(
  body: HashCreateRequest,
  config?: AxiosRequestConfig,
): Promise<HashLink> {
  const response = await apiClient.post<HashLink | [HashLink], HashCreateRequest>(
    '/api/hash/create',
    body,
    config,
  );
  return unwrapScalar(response);
}
