// Administrator-only NDDScore API client. R/Plumber scalars are unwrapped
// before use (notably job_id, which axios would otherwise encode as job_id[]).
import { apiClient, unwrapScalar } from './client';

export interface NddScoreAdminStatus {
  active_release: Record<string, unknown> | null;
  recent_jobs: Record<string, unknown>[] | null;
}

export interface NddScoreZenodoComparison {
  zenodo: Record<string, unknown>;
  active_release: Record<string, unknown> | null;
  matches_active: boolean;
}

export async function fetchNddScoreStatus(): Promise<NddScoreAdminStatus> {
  return apiClient.get('/api/admin/nddscore/status');
}

export async function fetchNddScoreZenodo(recordId?: string): Promise<NddScoreZenodoComparison> {
  return apiClient.get('/api/admin/nddscore/zenodo', {
    params: recordId ? { record_id: recordId } : undefined,
  });
}

export async function submitNddScoreImport(opts: {
  recordId?: string;
  validateOnly: boolean;
}): Promise<{ jobId: string; status: string }> {
  const payload: { record_id?: string; validate_only: boolean } = {
    validate_only: opts.validateOnly,
  };
  if (opts.recordId) {
    payload.record_id = opts.recordId;
  }

  const response = await apiClient.raw.post<{ job_id: unknown; status: unknown }>(
    '/api/admin/nddscore/import',
    payload,
    { validateStatus: (status) => (status >= 200 && status < 300) || status === 409 }
  );
  const raw = response.data;
  return {
    jobId: String(unwrapScalar(raw.job_id as never)),
    status: String(unwrapScalar(raw.status as never)),
  };
}
