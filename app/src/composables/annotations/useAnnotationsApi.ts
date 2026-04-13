// composables/annotations/useAnnotationsApi.ts
/**
 * Axios helpers for the Manage Annotations view (Phase E.E4).
 *
 * Each function is a thin typed wrapper around an existing backend call the
 * view previously made inline.  They return already-unwrapped payloads so the
 * view can stay focussed on orchestration.
 */

import axios from 'axios';
import {
  unwrapValue,
  authRequestConfig,
} from './useAnnotationFormatters';
import type {
  OntologyBlockedState,
  UserOption,
} from '@/components/annotations/OntologyAnnotationsCard.vue';
import type { PubtatorStats } from '@/components/annotations/PubtatorStatsCard.vue';
import type { ComparisonsMetadata } from '@/components/annotations/ComparisonsRefreshCard.vue';
import type { PublicationStats } from '@/components/annotations/PublicationRefreshCard.vue';
import type { DeprecatedData } from '@/components/annotations/DeprecatedEntitiesCard.vue';
import type { JobHistoryItem } from '@/components/annotations/JobHistoryCard.vue';

const API = (): string => import.meta.env.VITE_API_URL || '';

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
  const response = await axios.get(`${API()}/api/admin/annotation_dates`, authRequestConfig());
  const data = response.data;
  return {
    omim_update: unwrapValue(data.omim_update),
    hgnc_update: unwrapValue(data.hgnc_update),
    mondo_update: unwrapValue(data.mondo_update),
    disease_ontology_update: unwrapValue(data.disease_ontology_update),
  };
}

export async function fetchJobHistory(limit = 20): Promise<JobHistoryItem[]> {
  const response = await axios.get(`${API()}/api/jobs/history`, {
    ...authRequestConfig(),
    params: { limit },
  });
  const data = response.data;
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

export async function fetchJobHistoryRaw(
  limit = 1000
): Promise<Array<Record<string, unknown>>> {
  const response = await axios.get(`${API()}/api/jobs/history`, {
    ...authRequestConfig(),
    params: { limit },
  });
  return response.data?.data || [];
}

export async function fetchDeprecatedEntities(): Promise<DeprecatedData> {
  const response = await axios.get(
    `${API()}/api/admin/deprecated_entities`,
    authRequestConfig()
  );
  const data = response.data;
  const unwrappedEntities = (data.affected_entities || []).map(
    (entity: Record<string, unknown>) => {
      const unwrapped: Record<string, unknown> = {};
      Object.keys(entity).forEach((key) => {
        unwrapped[key] = unwrapValue(entity[key]);
      });
      return unwrapped;
    }
  );
  return {
    deprecated_count: unwrapValue(data.deprecated_count),
    affected_entity_count: (unwrapValue(data.affected_entity_count) as number) || 0,
    affected_entities: unwrappedEntities,
    mim2gene_date: unwrapValue(data.mim2gene_date),
    message: unwrapValue(data.message),
  };
}

export async function fetchPubtatorStats(): Promise<PubtatorStats> {
  const metaTotal = (
    response: { data?: { meta?: unknown } }
  ): number | null => {
    const meta = Array.isArray(response.data?.meta)
      ? response.data?.meta[0]
      : response.data?.meta;
    return (meta as { totalItems?: number })?.totalItems ?? null;
  };

  const genesResponse = await axios.get(`${API()}/api/publication/pubtator/genes`, {
    withCredentials: true,
    params: { page_size: 1, fields: 'gene_symbol' },
  });
  const pubsResponse = await axios.get(`${API()}/api/publication/pubtator/table`, {
    withCredentials: true,
    params: { page_size: 1, fields: 'search_id' },
  });
  const novelResponse = await axios.get(`${API()}/api/publication/pubtator/genes`, {
    withCredentials: true,
    params: { page_size: 1, filter: 'is_novel==1', fields: 'gene_symbol' },
  });

  return {
    publication_count: metaTotal(pubsResponse),
    gene_count: metaTotal(genesResponse),
    novel_count: metaTotal(novelResponse),
  };
}

export async function fetchPublicationStats(
  notUpdatedSince?: string | null
): Promise<PublicationStats & { filtered_count: number | null }> {
  const params: Record<string, string> = {};
  if (notUpdatedSince) params.not_updated_since = notUpdatedSince;

  const response = await axios.get(`${API()}/api/publication/stats`, {
    ...authRequestConfig(),
    params,
  });
  return {
    total: unwrapValue(response.data.total),
    oldest_update: unwrapValue(response.data.oldest_update),
    outdated_count: unwrapValue(response.data.outdated_count),
    filtered_count: (unwrapValue(response.data.filtered_count) as number) ?? null,
  };
}

export async function fetchComparisonsMetadata(): Promise<ComparisonsMetadata> {
  const response = await axios.get(`${API()}/api/comparisons/metadata`, {
    withCredentials: true,
  });
  return {
    last_full_refresh: unwrapValue(response.data.last_full_refresh),
    last_refresh_status:
      (unwrapValue(response.data.last_refresh_status) as string) ?? 'never',
    last_refresh_error: unwrapValue(response.data.last_refresh_error),
    sources_count: (unwrapValue(response.data.sources_count) as number) ?? 0,
    rows_imported: (unwrapValue(response.data.rows_imported) as number) ?? 0,
  };
}

export async function fetchForceApplyUsers(): Promise<UserOption[]> {
  const response = await axios.get(
    `${API()}/api/user/list?roles=Curator,Reviewer`,
    authRequestConfig()
  );
  if (!Array.isArray(response.data)) return [];
  return response.data.map((item: Record<string, unknown>) => ({
    value: item.user_id as number,
    text: item.user_name as string,
  }));
}

export async function submitOntologyUpdate(): Promise<JobSubmissionResponse> {
  const response = await axios.put(
    `${API()}/api/admin/update_ontology_async`,
    {},
    authRequestConfig()
  );
  return response.data as JobSubmissionResponse;
}

export async function submitForceApplyOntology(
  blockedJobId: string,
  assignedUserId: number | null
): Promise<JobSubmissionResponse> {
  const params: Record<string, string | number> = { blocked_job_id: blockedJobId };
  if (assignedUserId) params.assigned_user_id = assignedUserId;

  const response = await axios.put(
    `${API()}/api/admin/force_apply_ontology`,
    {},
    { ...authRequestConfig(), params }
  );
  return response.data as JobSubmissionResponse;
}

export async function submitHgncUpdate(): Promise<JobSubmissionResponse> {
  const response = await axios.post(
    `${API()}/api/jobs/hgnc_update/submit`,
    {},
    authRequestConfig()
  );
  return response.data as JobSubmissionResponse;
}

export async function submitComparisonsRefresh(): Promise<JobSubmissionResponse> {
  const response = await axios.post(
    `${API()}/api/jobs/comparisons_update/submit`,
    {},
    authRequestConfig()
  );
  return response.data as JobSubmissionResponse;
}

export async function submitPublicationRefresh(
  payload: { not_updated_since: string } | { pmids: unknown[] }
): Promise<JobSubmissionResponse> {
  const response = await axios.post(
    `${API()}/api/admin/publications/refresh`,
    payload,
    authRequestConfig()
  );
  return response.data as JobSubmissionResponse;
}

export async function fetchAllPublicationPmids(): Promise<unknown[]> {
  const response = await axios.get(`${API()}/api/publication`, {
    ...authRequestConfig(),
    params: { fields: 'publication_id', page_size: 10000 },
  });
  const publications: Array<{ publication_id: string | string[] }> = response.data?.data || [];
  return publications.map((p) => unwrapValue(p.publication_id));
}

export type OntologyJobResult =
  | { kind: 'blocked'; state: OntologyBlockedState }
  | { kind: 'ok'; autoFixesApplied: number }
  | null;

export async function fetchOntologyJobResult(jobId: string): Promise<OntologyJobResult> {
  const statusResp = await axios.get(
    `${API()}/api/jobs/${jobId}/status`,
    authRequestConfig()
  );
  const result = statusResp.data?.result;
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
    return {
      kind: 'blocked',
      state: {
        blocked_job_id: unwrapValue(jobId) as string,
        critical_count: (unwrapValue(result.critical_count) as number) || 0,
        auto_fixable_count: (unwrapValue(result.auto_fixable_count) as number) || 0,
        total_affected: (unwrapValue(result.total_affected) as number) || 0,
        critical_entities: unwrapRows(result.critical_entities || []),
        auto_fixes: unwrapRows(result.auto_fixes || []),
      },
    };
  }

  const applied = Number(unwrapValue(result?.auto_fixes_applied)) || 0;
  return { kind: 'ok', autoFixesApplied: applied };
}
