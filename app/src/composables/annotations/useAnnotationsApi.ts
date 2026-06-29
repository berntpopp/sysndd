// composables/annotations/useAnnotationsApi.ts
/**
 * Typed apiClient helpers for the Manage Annotations view (Phase E.E4).
 *
 * Each function is a thin typed wrapper around an existing backend call the
 * view previously made inline.  They return already-unwrapped payloads so the
 * view can stay focussed on orchestration.
 *
 * Calls go through the shared `apiClient` (`@/api/client`), which already sets
 * the `baseURL` and injects the Bearer token / 401 handling via its
 * interceptors.  Paths are therefore relative `/api/...` with no manual
 * `VITE_API_URL` prefix.  `authRequestConfig()` continues to contribute only
 * the `withCredentials: true` opt-in.
 */

import { apiClient } from '@/api/client';
import { unwrapValue, authRequestConfig } from './useAnnotationFormatters';
import type {
  OntologyBlockedState,
  UserOption,
} from '@/components/annotations/OntologyAnnotationsCard.vue';
import type { PubtatorStats } from '@/components/annotations/PubtatorStatsCard.vue';
import type { ComparisonsMetadata } from '@/components/annotations/ComparisonsRefreshCard.vue';
import type { PublicationStats } from '@/components/annotations/PublicationRefreshCard.vue';
import type { DeprecatedData } from '@/components/annotations/DeprecatedEntitiesCard.vue';
import type { JobHistoryItem } from '@/components/annotations/JobHistoryCard.vue';

export interface AnnotationDates {
  omim_update: string | null;
  hgnc_update: string | null;
  mondo_update: string | null;
  disease_ontology_update: string | null;
}

export interface JobSubmissionResponse {
  error?: string;
  message?: string;
  job_id?: string | string[];
  existing_job_id?: string | string[];
  status?: string;
  count?: number;
}

export async function fetchAnnotationDates(): Promise<AnnotationDates> {
  const data = await apiClient.get<Record<string, unknown>>(
    '/api/admin/annotation_dates',
    authRequestConfig()
  );
  return {
    omim_update: unwrapValue(data.omim_update) as string,
    hgnc_update: unwrapValue(data.hgnc_update) as string,
    mondo_update: unwrapValue(data.mondo_update) as string,
    disease_ontology_update: unwrapValue(data.disease_ontology_update) as string,
  };
}

export async function fetchJobHistory(limit = 20): Promise<JobHistoryItem[]> {
  const data = await apiClient.get<{ data?: Array<Record<string, unknown>> }>('/api/jobs/history', {
    ...authRequestConfig(),
    params: { limit },
  });
  if (!data || !Array.isArray(data.data)) return [];
  return data.data.map((job: Record<string, unknown>) => ({
    job_id: unwrapValue(job.job_id),
    operation: unwrapValue(job.operation),
    status: unwrapValue(job.status),
    submitted_at: unwrapValue(job.submitted_at),
    completed_at: unwrapValue(job.completed_at),
    duration_seconds: unwrapValue(job.duration_seconds),
    error_message: unwrapValue(job.error_message),
  })) as JobHistoryItem[];
}

export async function fetchJobHistoryRaw(limit = 1000): Promise<Array<Record<string, unknown>>> {
  const data = await apiClient.get<{ data?: Array<Record<string, unknown>> }>('/api/jobs/history', {
    ...authRequestConfig(),
    params: { limit },
  });
  return data?.data || [];
}

export async function fetchDeprecatedEntities(): Promise<DeprecatedData> {
  const data = await apiClient.get<Record<string, unknown>>(
    '/api/admin/deprecated_entities',
    authRequestConfig()
  );
  const unwrappedEntities = ((data.affected_entities as Array<Record<string, unknown>>) || []).map(
    (entity: Record<string, unknown>) => {
      const unwrapped: Record<string, unknown> = {};
      Object.keys(entity).forEach((key) => {
        unwrapped[key] = unwrapValue(entity[key]);
      });
      return unwrapped;
    }
  );
  return {
    deprecated_count: unwrapValue(data.deprecated_count) as number,
    affected_entity_count: (unwrapValue(data.affected_entity_count) as number) || 0,
    affected_entities: unwrappedEntities,
    mim2gene_date: unwrapValue(data.mim2gene_date) as string,
    message: unwrapValue(data.message) as string,
  };
}

export async function fetchPubtatorStats(): Promise<PubtatorStats> {
  const metaTotal = (data: { meta?: unknown }): number | null => {
    const meta = Array.isArray(data?.meta) ? data?.meta[0] : data?.meta;
    return (meta as { totalItems?: number })?.totalItems ?? null;
  };

  const genesData = await apiClient.get<{ meta?: unknown }>('/api/publication/pubtator/genes', {
    withCredentials: true,
    params: { page_size: 1, fields: 'gene_symbol' },
  });
  const pubsData = await apiClient.get<{ meta?: unknown }>('/api/publication/pubtator/table', {
    withCredentials: true,
    params: { page_size: 1, fields: 'search_id' },
  });
  const novelData = await apiClient.get<{ meta?: unknown }>('/api/publication/pubtator/genes', {
    withCredentials: true,
    params: { page_size: 1, filter: 'is_novel==1', fields: 'gene_symbol' },
  });

  return {
    publication_count: metaTotal(pubsData),
    gene_count: metaTotal(genesData),
    novel_count: metaTotal(novelData),
  };
}

export async function fetchPublicationStats(
  notUpdatedSince?: string | null
): Promise<PublicationStats & { filtered_count: number | null }> {
  const params: Record<string, string> = {};
  if (notUpdatedSince) params.not_updated_since = notUpdatedSince;

  const data = await apiClient.get<Record<string, unknown>>('/api/publication/stats', {
    ...authRequestConfig(),
    params,
  });
  return {
    total: unwrapValue(data.total) as number,
    oldest_update: unwrapValue(data.oldest_update) as string,
    outdated_count: unwrapValue(data.outdated_count) as number,
    filtered_count: (unwrapValue(data.filtered_count) as number) ?? null,
  };
}

export async function fetchComparisonsMetadata(): Promise<ComparisonsMetadata> {
  const data = await apiClient.get<Record<string, unknown>>('/api/comparisons/metadata', {
    withCredentials: true,
  });
  return {
    last_full_refresh: unwrapValue(data.last_full_refresh) as string,
    last_refresh_status: (unwrapValue(data.last_refresh_status) as string) ?? 'never',
    last_refresh_error: unwrapValue(data.last_refresh_error) as string,
    sources_count: (unwrapValue(data.sources_count) as number) ?? 0,
    rows_imported: (unwrapValue(data.rows_imported) as number) ?? 0,
  };
}

export async function fetchForceApplyUsers(): Promise<UserOption[]> {
  const data = await apiClient.get<Array<Record<string, unknown>>>(
    '/api/user/list?roles=Curator,Reviewer',
    authRequestConfig()
  );
  if (!Array.isArray(data)) return [];
  return data.map((item: Record<string, unknown>) => ({
    value: item.user_id as number,
    text: item.user_name as string,
  }));
}

export async function submitOntologyUpdate(): Promise<JobSubmissionResponse> {
  return apiClient.put<JobSubmissionResponse>(
    '/api/admin/update_ontology_async',
    {},
    authRequestConfig()
  );
}

export async function submitForceApplyOntology(
  blockedJobId: string,
  assignedUserId: number | null
): Promise<JobSubmissionResponse> {
  const params: Record<string, string | number> = { blocked_job_id: blockedJobId };
  if (assignedUserId) params.assigned_user_id = assignedUserId;

  return apiClient.put<JobSubmissionResponse>('/api/admin/force_apply_ontology', {}, {
    ...authRequestConfig(),
    params,
  });
}

export async function submitHgncUpdate(): Promise<JobSubmissionResponse> {
  return apiClient.post<JobSubmissionResponse>(
    '/api/jobs/hgnc_update/submit',
    {},
    authRequestConfig()
  );
}

export async function submitComparisonsRefresh(): Promise<JobSubmissionResponse> {
  return apiClient.post<JobSubmissionResponse>(
    '/api/jobs/comparisons_update/submit',
    {},
    authRequestConfig()
  );
}

export async function submitPublicationRefresh(
  // `{ all: true }` asks the server to enumerate the entire publication corpus
  // server-side (the client no longer fetches every PMID).
  payload: { not_updated_since: string } | { pmids: unknown[] } | { all: true }
): Promise<JobSubmissionResponse> {
  return apiClient.post<JobSubmissionResponse>(
    '/api/admin/publications/refresh',
    payload,
    authRequestConfig()
  );
}

export type OntologyJobResult =
  | { kind: 'blocked'; state: OntologyBlockedState }
  | { kind: 'ok'; autoFixesApplied: number }
  | null;

export async function fetchOntologyJobResult(jobId: string): Promise<OntologyJobResult> {
  // result_mode=full is required: the default "summary" mode returns result:{}
  // (no result_json), so the blocked payload (status, critical_entities, …) would
  // be missing and the blocked banner would never hydrate — both on page-load
  // (ManageAnnotations onMounted) and in the reactive post-run flow.
  const statusData = await apiClient.get<{ result?: Record<string, unknown> }>(
    `/api/jobs/${jobId}/status?result_mode=full`,
    authRequestConfig()
  );
  const result = statusData?.result;
  if (!result) return null;
  const resultStatus = unwrapValue(result?.status);

  if (resultStatus === 'blocked') {
    const unwrapRows = (rows: Array<Record<string, unknown>> = []) =>
      rows.map((row) => {
        const out: Record<string, unknown> = {};
        Object.keys(row).forEach((k) => {
          out[k] = unwrapValue(row[k]);
        });
        return out;
      });
    const payloadBlockedId = unwrapValue(result?.blocked_job_id);
    const blockedJobId =
      typeof payloadBlockedId === 'string' && payloadBlockedId.length > 0
        ? payloadBlockedId
        : (unwrapValue(jobId) as string);
    return {
      kind: 'blocked',
      state: {
        blocked_job_id: blockedJobId,
        critical_count: (unwrapValue(result.critical_count) as number) || 0,
        auto_fixable_count: (unwrapValue(result.auto_fixable_count) as number) || 0,
        total_affected: (unwrapValue(result.total_affected) as number) || 0,
        critical_entities: unwrapRows(
          (result.critical_entities as Array<Record<string, unknown>>) || []
        ),
        auto_fixes: unwrapRows((result.auto_fixes as Array<Record<string, unknown>>) || []),
      },
    };
  }

  const applied = Number(unwrapValue(result?.auto_fixes_applied)) || 0;
  return { kind: 'ok', autoFixesApplied: applied };
}

export interface OntologyDictionaryStatus {
  blocked: boolean;
  blocked_job_id: string | null;
  stale: boolean;
  last_full_apply_at: string | null;
  last_additive_apply_at: string | null;
  latest_blocked_omim_update_at: string | null;
  disease_ontology_last_applied: string | null;
  max_omim_id: string | null;
  critical_count: number;
  auto_fixable_count: number;
  additive_applied: number;
}

export async function fetchOntologyDictionaryStatus(): Promise<OntologyDictionaryStatus> {
  const data = await apiClient.get<Record<string, unknown>>(
    '/api/admin/ontology/dictionary-status',
    authRequestConfig()
  );
  const b = (v: unknown) => unwrapValue(v) === true || unwrapValue(v) === 'TRUE';
  const n = (v: unknown) => (unwrapValue(v) as number) ?? 0;
  const s = (v: unknown) => (unwrapValue(v) as string) ?? null;
  return {
    blocked: b(data.blocked),
    blocked_job_id: s(data.blocked_job_id),
    stale: b(data.stale),
    last_full_apply_at: s(data.last_full_apply_at),
    last_additive_apply_at: s(data.last_additive_apply_at),
    latest_blocked_omim_update_at: s(data.latest_blocked_omim_update_at),
    disease_ontology_last_applied: s(data.disease_ontology_last_applied),
    max_omim_id: s(data.max_omim_id),
    critical_count: n(data.critical_count),
    auto_fixable_count: n(data.auto_fixable_count),
    additive_applied: n(data.additive_applied),
  };
}
