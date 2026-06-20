// app/src/api/disease-mappings.ts
//
// Typed API client for disease cross-ontology mappings.
//
// Mirrors api/endpoints/disease_endpoints.R (mounted at /api/disease).
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
 * R/Plumber may array-wrap scalar fields. Call-sites that need bare scalars
 * should use `unwrapScalar` from `@/api/client`.
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
  return apiClient.get<DiseaseMappingResponse>('/api/disease/mappings', {
    ...config,
    params: {
      ...(config?.params as object | undefined),
      entity_id: entityId,
    },
  });
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
  return apiClient.get<DiseaseMappingResponse>('/api/disease/mappings', {
    ...config,
    params: {
      ...(config?.params as object | undefined),
      disease_ontology_id: diseaseId,
    },
  });
}
