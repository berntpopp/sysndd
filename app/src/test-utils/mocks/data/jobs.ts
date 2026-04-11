// test-utils/mocks/data/jobs.ts
/**
 * Static fixtures mirroring the OpenAPI response shapes for job endpoints
 * defined in api/endpoints/jobs_endpoints.R.
 *
 * Reference: api/config/openapi/schemas/inferred/api_jobs_history_GET.json.
 *
 * R/Plumber serialises scalars as one-element arrays — job_id returned from
 * submit endpoints must be `[string]`, not `string`.  See CLAUDE.md
 * "R/Plumber returns JSON scalars as arrays" for details.
 */

export interface JobHistoryRow {
  job_id: string;
  job_type: string;
  status: string;
  submitted_at: string;
  finished_at: string | null;
  submitted_by: string;
}

export const jobsHistoryOk: {
  data: JobHistoryRow[];
  meta: { count: number[]; limit: number[] };
} = {
  data: [
    {
      job_id: 'hgnc-update-2025-06-01',
      job_type: 'hgnc_update',
      status: 'success',
      submitted_at: '2025-06-01 00:00:00',
      finished_at: '2025-06-01 00:05:12',
      submitted_by: 'alice_admin',
    },
    {
      job_id: 'ontology-update-2025-06-05',
      job_type: 'ontology_update',
      status: 'blocked',
      submitted_at: '2025-06-05 00:00:00',
      finished_at: '2025-06-05 00:01:42',
      submitted_by: 'alice_admin',
    },
  ],
  meta: {
    count: [2],
    limit: [50],
  },
};

export const jobsHistoryForbidden = {
  error: 'Not authorised to view job history.',
};

export const jobStatusOk = {
  job_id: ['hgnc-update-2025-06-01'],
  status: ['success'],
  submitted_at: ['2025-06-01 00:00:00'],
  finished_at: ['2025-06-01 00:05:12'],
  result: [{ rows_updated: 42 }],
};

export const jobStatusNotFound = {
  error: 'Job not found.',
};

export const hgncUpdateSubmitOk = {
  message: 'HGNC update job submitted.',
  job_id: ['hgnc-update-2025-07-01'],
};

export const hgncUpdateSubmitForbidden = {
  error: 'HGNC update forbidden for non-admin.',
};

export const ontologyUpdateSubmitOk = {
  message: 'Ontology update job submitted.',
  job_id: ['ontology-update-2025-07-01'],
};

export const ontologyUpdateSubmitForbidden = {
  error: 'Ontology update forbidden for non-admin.',
};

export const comparisonsUpdateSubmitOk = {
  message: 'Comparisons update job submitted.',
  job_id: ['comparisons-update-2025-07-01'],
};

export const comparisonsUpdateSubmitForbidden = {
  error: 'Comparisons update forbidden for non-admin.',
};

export const clusteringSubmitOk = {
  message: 'Clustering job submitted.',
  job_id: ['clustering-2025-07-01'],
};

export const clusteringSubmitBadRequest = {
  error: 'Invalid clustering parameters.',
};

export const phenotypeClusteringSubmitOk = {
  message: 'Phenotype clustering job submitted.',
  job_id: ['phenotype-clustering-2025-07-01'],
};

export const phenotypeClusteringSubmitBadRequest = {
  error: 'Invalid phenotype clustering parameters.',
};
