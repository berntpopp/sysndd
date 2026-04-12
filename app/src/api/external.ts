// app/src/api/external.ts
/**
 * External-proxy resource helpers.
 *
 * Phase E.E1 established this module as a stub; Phase E.E3 fills in the
 * first real helper (`getUniprotDomains`) as part of migrating
 * `GeneView.vue` off raw `axios.get`. Additional external-proxy helpers
 * (Ensembl, AlphaFold metadata, ClinVar, gnomAD variants, MGI, RGD) will
 * be added as each call site migrates during v11.1.
 *
 * Wire shapes mirror `api/endpoints/external_endpoints.R`. The endpoints
 * use `@serializer unboxedJSON`, so responses arrive as plain objects
 * (not the R/Plumber 1-element-array scalar wrapping used by tibble
 * collectors elsewhere). Consumers therefore do NOT need `unwrapScalar`.
 */

import type { AxiosRequestConfig } from 'axios';
import { apiClient } from './client';

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
  config?: AxiosRequestConfig,
): Promise<UniProtData> {
  const path = `/api/external/uniprot/domains/${encodeURIComponent(symbol)}`;
  return apiClient.get<UniProtData>(path, config);
}
