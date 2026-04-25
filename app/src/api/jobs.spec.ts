// app/src/api/jobs.spec.ts
//
// Vitest + MSW spec for the typed jobs helpers (W3.9).

import { describe, it, expect } from 'vitest';
import { http, HttpResponse } from 'msw';

import {
  submitClustering,
  submitPhenotypeClustering,
  submitOntologyUpdate,
  submitHgncUpdate,
  submitComparisonsUpdate,
  getJobHistory,
  getJobStatus,
  type JobSubmissionResponse,
  type JobHistoryResponse,
  type JobStatusResponse,
} from './jobs';
import { isApiError } from './client';
import { server } from '@/test-utils/mocks/server';

const acceptedJob: JobSubmissionResponse = {
  job_id: 'j-1',
  status: 'accepted',
  estimated_seconds: 30,
  status_url: '/api/jobs/j-1/status',
};

describe('api/jobs — submitClustering', () => {
  it('POSTs the clustering body and returns the 202 envelope', async () => {
    let receivedBody: unknown = null;
    server.use(
      http.post('/api/jobs/clustering/submit', async ({ request }) => {
        receivedBody = await request.json();
        return HttpResponse.json(acceptedJob, { status: 202 });
      }),
    );

    const result = await submitClustering({ algorithm: 'walktrap' });
    expect(receivedBody).toEqual({ algorithm: 'walktrap' });
    expect(result.job_id).toBe('j-1');
  });

  it('throws AxiosError on 409 (duplicate job)', async () => {
    server.use(
      http.post('/api/jobs/clustering/submit', () =>
        HttpResponse.json(
          {
            error: 'DUPLICATE_JOB',
            message: 'Identical job already running',
            existing_job_id: 'j-1',
            status_url: '/api/jobs/j-1/status',
          },
          { status: 409 },
        ),
      ),
    );

    let caught: unknown;
    try {
      await submitClustering();
    } catch (err) {
      caught = err;
    }
    expect(isApiError(caught)).toBe(true);
    if (isApiError(caught)) {
      expect(caught.response?.status).toBe(409);
    }
  });
});

describe('api/jobs — submitPhenotypeClustering', () => {
  it('returns the 202 envelope on submission', async () => {
    server.use(
      http.post('/api/jobs/phenotype_clustering/submit', () =>
        HttpResponse.json(acceptedJob, { status: 202 }),
      ),
    );
    const result = await submitPhenotypeClustering();
    expect(result.job_id).toBe('j-1');
  });
});

describe('api/jobs — submitOntologyUpdate', () => {
  it('returns the 202 envelope on submission', async () => {
    server.use(
      http.post('/api/jobs/ontology_update/submit', () =>
        HttpResponse.json(acceptedJob, { status: 202 }),
      ),
    );
    const result = await submitOntologyUpdate();
    expect(result.job_id).toBe('j-1');
  });
});

describe('api/jobs — submitHgncUpdate', () => {
  it('returns the 202 envelope on submission', async () => {
    server.use(
      http.post('/api/jobs/hgnc_update/submit', () =>
        HttpResponse.json(acceptedJob, { status: 202 }),
      ),
    );
    const result = await submitHgncUpdate();
    expect(result.job_id).toBe('j-1');
  });
});

describe('api/jobs — submitComparisonsUpdate', () => {
  it('returns the 202 envelope on submission', async () => {
    server.use(
      http.post('/api/jobs/comparisons_update/submit', () =>
        HttpResponse.json(acceptedJob, { status: 202 }),
      ),
    );
    const result = await submitComparisonsUpdate();
    expect(result.job_id).toBe('j-1');
  });
});

describe('api/jobs — getJobHistory', () => {
  it('forwards the limit param and returns the paginated envelope', async () => {
    let observedQuery: URLSearchParams | null = null;
    const ok: JobHistoryResponse = {
      data: [
        {
          job_id: 'j-1',
          operation: 'clustering',
          status: 'completed',
          submitted_at: '2026-04-25T00:00:00Z',
          completed_at: '2026-04-25T00:01:00Z',
          duration_seconds: 60,
          error_message: null,
        },
      ],
      meta: { count: 1, limit: 5 },
    };
    server.use(
      http.get('/api/jobs/history', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json(ok);
      }),
    );

    const result = await getJobHistory({ limit: 5 });
    expect((observedQuery as unknown as URLSearchParams).get('limit')).toBe('5');
    expect(result.data).toHaveLength(1);
  });
});

describe('api/jobs — getJobStatus', () => {
  it('URL-encodes the job_id path param', async () => {
    let observedPath: string | null = null;
    const ok: JobStatusResponse = {
      job_id: 'j-1',
      status: 'completed',
    };
    server.use(
      http.get('/api/jobs/:job_id/status', ({ request }) => {
        observedPath = new URL(request.url).pathname;
        return HttpResponse.json(ok);
      }),
    );

    await getJobStatus('550e/8400');
    expect(observedPath).toBe('/api/jobs/550e%2F8400/status');
  });

  it('throws AxiosError on 404 (job expired or not found)', async () => {
    server.use(
      http.get('/api/jobs/:job_id/status', () =>
        HttpResponse.json({ error: 'JOB_NOT_FOUND' }, { status: 404 }),
      ),
    );

    let caught: unknown;
    try {
      await getJobStatus('does-not-exist');
    } catch (err) {
      caught = err;
    }
    expect(isApiError(caught)).toBe(true);
    if (isApiError(caught)) {
      expect(caught.response?.status).toBe(404);
    }
  });
});
