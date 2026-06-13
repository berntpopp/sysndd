// app/src/api/external.ts
/**
 * External-proxy resource helpers.
 *
 * Phase E.E1 established this module as a stub; Phase E.E3 fills in the
 * first real helper (`getUniprotDomains`) as part of migrating
 * `GeneView.vue` off raw `axios.get`. v11.1 W7 finish-hardening adds the
 * Ensembl gene-structure helper (used by `GeneStructureCard` and
 * `GenomicVisualizationTabs`).
 *
 * Wire shapes mirror `api/endpoints/external_endpoints.R`. The
 * external-proxy endpoints use `@serializer unboxedJSON`, so responses
 * arrive as plain objects (not the R/Plumber 1-element-array scalar
 * wrapping used by tibble collectors elsewhere). Consumers therefore do
 * NOT need `unwrapScalar`.
 */

import type { AxiosRequestConfig } from 'axios';
import { apiClient } from './client';
import type { EnsemblGeneStructure } from '@/types/ensembl';

// Re-export so consumers can import the wire-shape type from the same
// surface as the helper (W7 finish-hardening: kills the doubled
// `as unknown as EnsemblGeneStructure` cast that earlier consumers used
// when this module did not yet expose the type).
export type { EnsemblGeneStructure } from '@/types/ensembl';

// ---------------------------------------------------------------------------
// UniProt domain architecture
// ---------------------------------------------------------------------------

/**
 * A single protein feature emitted by UniProt (domain, region, signal, etc.).
 * Mirrors the shape used by `GeneView.vue` — `begin`/`end` can come back as
 * strings for some UniProt entries, so the type accepts both forms.
 */
export interface UniProtDomainFeature {
  type: string;
  description?: string;
  begin: number | string;
  end: number | string;
}

/**
 * Response body from `GET /api/external/uniprot/domains/<symbol>`.
 * The upstream endpoint memoises for 14 days; 404 is the canonical
 * "gene not in UniProt" branch, and consumers typically surface it as
 * "no data" rather than an error.
 */
export interface UniProtData {
  source: string;
  gene_symbol: string;
  accession: string;
  protein_name: string;
  protein_length: number | string;
  domains: UniProtDomainFeature[];
}

/**
 * GET /api/external/uniprot/domains/<symbol>
 *
 * Returns the protein-domain architecture for the given gene symbol.
 * Throws the underlying `AxiosError` on non-2xx (including the 404
 * "gene not found in UniProt" branch) — callers that want to map 404
 * to "no data, no error" should catch and inspect via `isApiError` +
 * `err.response?.status`. See `GeneView.vue`'s `fetchUniprotData` for
 * the canonical handling pattern.
 */
export async function getUniprotDomains(
  symbol: string,
  config?: AxiosRequestConfig
): Promise<UniProtData> {
  const path = `/api/external/uniprot/domains/${encodeURIComponent(symbol)}`;
  return apiClient.get<UniProtData>(path, config);
}

// ---------------------------------------------------------------------------
// Ensembl gene structure
// ---------------------------------------------------------------------------

/**
 * GET /api/external/ensembl/structure/<symbol>
 * Mirrors `api/endpoints/external_endpoints.R` (`@get ensembl/structure/<symbol>`).
 *
 * Returns gene coordinates, the canonical transcript, and exon array from
 * Ensembl REST (proxied through the SysNDD API, which memoises for 14 days).
 *
 * The R endpoint emits the wire shape with `@serializer unboxedJSON`, so the
 * response arrives as a plain object that aligns structurally with
 * `EnsemblGeneStructure` in `@/types/ensembl`. Throws the underlying
 * `AxiosError` on non-2xx; callers that want to surface "gene not in Ensembl"
 * as an empty state (rather than an error) should catch and inspect
 * `err.response?.status === 404` (mirrors the UniProt helper convention).
 */
export async function getEnsemblStructure(
  symbol: string,
  config?: AxiosRequestConfig
): Promise<EnsemblGeneStructure> {
  const path = `/api/external/ensembl/structure/${encodeURIComponent(symbol)}`;
  return apiClient.get<EnsemblGeneStructure>(path, config);
}
