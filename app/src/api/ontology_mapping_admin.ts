// Administrator-only disease cross-ontology mapping API client.
// Both endpoints use @serializer unboxedJSON, so scalars come back as bare
// values (not 1-element arrays). No unwrapScalar needed.
import { apiClient } from './client';

export interface OntologyMappingMetaRow {
  id: number;
  mondo_release_version: string | null;
  /** success | failed | skipped */
  status: string | null;
  mondo_term_count: number | null;
  mondo_xref_count: number | null;
  mapping_count: number | null;
  disease_covered_count: number | null;
  build_started_at: string | null;
  build_finished_at: string | null;
  build_duration_s: number | null;
}

export interface OntologyMappingStatus {
  latest: OntologyMappingMetaRow | null;
  history: OntologyMappingMetaRow[];
  build_exists: boolean;
}

export interface OntologyMappingRefreshResult {
  submitted: boolean;
  duplicate: boolean;
  skipped: boolean;
  job_id: string | null;
  message: string;
}

/**
 * GET /api/admin/ontology/mappings/status
 * Returns the latest build row, recent history, and a build_exists flag.
 */
export async function fetchOntologyMappingStatus(
  config?: Parameters<typeof apiClient.get>[1]
): Promise<OntologyMappingStatus> {
  return apiClient.get<OntologyMappingStatus>(
    '/api/admin/ontology/mappings/status',
    config
  );
}

/**
 * POST /api/admin/ontology/mappings/refresh?force=<bool>
 * Submits (or deduplicates) a mapping refresh job.
 * - submitted=true  → new job enqueued; poll job_id.
 * - duplicate=true  → identical job already queued/running; poll reused job_id.
 * - skipped=true    → only with force=false when a successful build exists.
 */
export async function submitOntologyMappingRefresh(
  force: boolean,
  config?: Parameters<typeof apiClient.raw.post>[2]
): Promise<OntologyMappingRefreshResult> {
  const response = await apiClient.raw.post<OntologyMappingRefreshResult>(
    '/api/admin/ontology/mappings/refresh',
    undefined,
    {
      ...config,
      params: { force },
      validateStatus: (status) => status >= 200 && status < 300,
    }
  );
  return response.data;
}
