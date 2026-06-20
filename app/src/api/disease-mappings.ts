// app/src/api/disease-mappings.ts
//
// Typed API client for disease cross-ontology mappings.
//
// Mirrors api/endpoints/disease_mapping_endpoints.R (mounted at /api/disease).
// The `/api/disease/mappings` endpoint returns a cross-ontology mapping
// response for a given entity or disease ontology ID.

import type { AxiosRequestConfig } from 'axios';
import { apiClient } from './client';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

/**
 * A single cross-ontology mapping entry within a prefix group.
 */
export interface DiseaseMappingEntry {
  /** The full CURIE id, e.g. "MONDO:0032745", "OMIM:618524". */
  id: string;
  /** Human-readable label from the ontology source, or null when absent. */
  label: string | null;
  /** Mapping predicate, e.g. "exactMatch", "closeMatch", or null. */
  predicate: string | null;
  /** Source of the mapping, e.g. "sysndd_native", "mondo_sssom". */
  source: string;
}

/**
 * Wire shape from `GET /api/disease/mappings`.
 *
 * - `disease_ontology_id`: the SysNDD disease ontology identifier (usually OMIM CURIE).
 * - `disease_ontology_name`: human-readable disease name from SysNDD.
 * - `mondo_id`: the Mondo disease ontology id, or null when no mapping is known.
 * - `release_version`: mapping data release date/version, or null.
 * - `status`: "current" when mappings are populated; "missing" when unavailable.
 * - `mappings`: prefix-keyed groups of mapping entries (MONDO, Orphanet, OMIM, etc.).
 *
 * R/Plumber serialises bare scalars as 1-element arrays and empty objects `{}`
 * for NULL non-array fields. `normalizeDiseaseMappingResponse` normalises the
 * raw API response into this clean shape before it reaches consumers.
 */
export interface DiseaseMappingResponse {
  disease_ontology_id: string;
  disease_ontology_name: string;
  mondo_id: string | null;
  release_version: string | null;
  status: 'current' | 'missing';
  mappings: Record<string, DiseaseMappingEntry[]>;
}

// ---------------------------------------------------------------------------
// Response normalisation
// ---------------------------------------------------------------------------

/**
 * Unwrap a Plumber scalar field.
 *
 * Plumber serialises bare JSON scalars as 1-element arrays (`["x"]` → `"x"`).
 * For NULL scalar columns on the "missing" path it emits an empty object `{}`
 * instead of `null`. This helper collapses all three forms to the clean value:
 *
 *   - `["x"]`  → `"x"`
 *   - `[null]` → `null`
 *   - `{}`     → `null`   (empty-object sentinel)
 *   - `null`   → `null`
 *   - `"x"`    → `"x"`   (already unboxed — pass-through)
 */
function unwrapField(value: unknown): string | null {
  if (Array.isArray(value)) {
    const first = value[0];
    return first == null ? null : String(first);
  }
  if (value == null) {
    return null;
  }
  if (typeof value === 'object') {
    // Empty object `{}` is emitted by Plumber for NULL scalar columns on the
    // missing-entity path. Treat any non-array object as null.
    return null;
  }
  return String(value);
}

/**
 * Normalise the raw R/Plumber response from `GET /api/disease/mappings` into
 * the clean `DiseaseMappingResponse` shape that consumers and the type contract
 * expect.
 *
 * The live endpoint array-wraps every scalar field and uses `{}` for NULL
 * scalars (Plumber behaviour). This function is the single point where the
 * wire quirks are absorbed so no consumer ever sees `["current"]` instead of
 * `"current"`.
 *
 * Exported for unit testing.
 */
export function normalizeDiseaseMappingResponse(raw: unknown): DiseaseMappingResponse {
  const MISSING: DiseaseMappingResponse = {
    disease_ontology_id: '',
    disease_ontology_name: '',
    mondo_id: null,
    release_version: null,
    status: 'missing',
    mappings: {},
  };

  if (raw == null || typeof raw !== 'object') {
    return MISSING;
  }

  const r = raw as Record<string, unknown>;

  // Unwrap top-level scalars.
  const status = unwrapField(r['status']);
  const cleanStatus: 'current' | 'missing' = status === 'current' ? 'current' : 'missing';

  // Normalise mappings.
  // The "missing" path sends `"mappings":[]` (an array); the populated path
  // sends `"mappings":{...}` (a plain object keyed by prefix).
  const cleanMappings: Record<string, DiseaseMappingEntry[]> = {};

  const rawMappings = r['mappings'];
  if (rawMappings != null && typeof rawMappings === 'object' && !Array.isArray(rawMappings)) {
    const mObj = rawMappings as Record<string, unknown>;
    for (const prefix of Object.keys(mObj)) {
      const entries = mObj[prefix];
      if (!Array.isArray(entries)) continue;
      cleanMappings[prefix] = entries.map((entry: unknown): DiseaseMappingEntry => {
        const e = (entry != null && typeof entry === 'object' ? entry : {}) as Record<
          string,
          unknown
        >;
        return {
          id: unwrapField(e['id']) ?? '',
          label: unwrapField(e['label']),
          predicate: unwrapField(e['predicate']),
          source: unwrapField(e['source']) ?? '',
        };
      });
    }
  }

  return {
    disease_ontology_id: unwrapField(r['disease_ontology_id']) ?? '',
    disease_ontology_name: unwrapField(r['disease_ontology_name']) ?? '',
    mondo_id: unwrapField(r['mondo_id']),
    release_version: unwrapField(r['release_version']),
    status: cleanStatus,
    mappings: cleanMappings,
  };
}

// ---------------------------------------------------------------------------
// Client functions
// ---------------------------------------------------------------------------

/**
 * GET /api/disease/mappings?entity_id=<entityId>
 *
 * Fetches cross-ontology disease mappings by SysNDD entity ID.
 */
export async function getEntityMappings(
  entityId: number | string,
  config?: AxiosRequestConfig
): Promise<DiseaseMappingResponse> {
  const raw = await apiClient.get<unknown>('/api/disease/mappings', {
    ...config,
    params: {
      ...(config?.params as object | undefined),
      entity_id: entityId,
    },
  });
  return normalizeDiseaseMappingResponse(raw);
}

/**
 * GET /api/disease/mappings?disease_ontology_id=<diseaseId>
 *
 * Fetches cross-ontology disease mappings by disease ontology ID (e.g. "OMIM:618524").
 */
export async function getDiseaseMappings(
  diseaseId: string,
  config?: AxiosRequestConfig
): Promise<DiseaseMappingResponse> {
  const raw = await apiClient.get<unknown>('/api/disease/mappings', {
    ...config,
    params: {
      ...(config?.params as object | undefined),
      disease_ontology_id: diseaseId,
    },
  });
  return normalizeDiseaseMappingResponse(raw);
}
