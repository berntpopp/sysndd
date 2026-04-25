// app/src/api/external.ts
/**
 * External-proxy resource helpers.
 *
 * Phase E.E1 established this module as a stub; Phase E.E3 fills in the
 * first real helper (`getUniprotDomains`) as part of migrating
 * `GeneView.vue` off raw `axios.get`. v11.1 W7 finish-hardening adds the
 * Ensembl gene-structure helper (used by `GeneStructureCard` and
 * `GenomicVisualizationTabs`) and the Internet Archive snapshot helper
 * (used by `HelperBadge`).
 *
 * Wire shapes mirror `api/endpoints/external_endpoints.R`. The
 * external-proxy endpoints use `@serializer unboxedJSON`, so responses
 * arrive as plain objects (not the R/Plumber 1-element-array scalar
 * wrapping used by tibble collectors elsewhere). Consumers therefore do
 * NOT need `unwrapScalar`. The Internet Archive endpoint returns the raw
 * archive.org SPN2 response body (JSON object containing `job_id`).
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
  config?: AxiosRequestConfig,
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
  config?: AxiosRequestConfig,
): Promise<EnsemblGeneStructure> {
  const path = `/api/external/ensembl/structure/${encodeURIComponent(symbol)}`;
  return apiClient.get<EnsemblGeneStructure>(path, config);
}

// ---------------------------------------------------------------------------
// Internet Archive snapshot
// ---------------------------------------------------------------------------

/**
 * Response body from `GET /api/external/internet_archive`.
 *
 * The R endpoint forwards the URL to archive.org's SPN2 (Save Page Now v2)
 * API and returns the raw response body. SPN2 is asynchronous: a successful
 * submission returns a `job_id` and `url` immediately; the actual archiving
 * completes later. Consumers can poll the SPN2 status endpoint with the
 * returned `job_id` if they need to confirm capture (sysndd does not).
 *
 * Fields beyond `job_id` and `url` are documented as returned by archive.org
 * but treated as optional — the payload shape may evolve upstream.
 */
export interface InternetArchiveSnapshot {
  /**
   * SPN2 job identifier returned synchronously on a successful submission.
   * `HelperBadge` surfaces this in the success toast so curators can
   * cross-reference the citation in archive.org's wayback machine.
   */
  job_id: string;
  /** The submitted URL, echoed back by archive.org. */
  url?: string;
  /** Optional status hint emitted by SPN2 ("pending", etc.). */
  status?: string;
  /** Optional human-readable status text from SPN2. */
  message?: string;
}

/**
 * GET /api/external/internet_archive?parameter_url=<url>
 * Mirrors `api/endpoints/external_endpoints.R` (`@get internet_archive`).
 *
 * Submits a sysndd page URL to archive.org's SPN2 API and returns the
 * snapshot identifier. The R handler validates `parameter_url` against the
 * configured `archive_base_url` (sysndd domain whitelist) and returns 400
 * for any other origin. Throws the underlying `AxiosError` on non-2xx.
 */
export async function createInternetArchiveSnapshot(
  url: string,
  config?: AxiosRequestConfig,
): Promise<InternetArchiveSnapshot> {
  return apiClient.get<InternetArchiveSnapshot>('/api/external/internet_archive', {
    ...config,
    params: { ...(config?.params ?? {}), parameter_url: url },
  });
}
