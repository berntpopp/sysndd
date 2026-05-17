import { afterEach, describe, expect, it } from 'vitest';
import { http, HttpResponse } from 'msw';
import { server } from '@/test-utils/mocks/server';
import { primeAuth } from '@/test-utils/primeAuth';
import { fetchNddScoreStatus, submitNddScoreImport } from './nddscore_admin';

describe('nddscore_admin api client', () => {
  afterEach(() => server.resetHandlers());

  it('fetches admin status', async () => {
    primeAuth();
    server.use(
      http.get('/api/admin/nddscore/status', () =>
        HttpResponse.json({ active_release: { release_id: 'r1' }, recent_jobs: [] })
      )
    );
    const status = await fetchNddScoreStatus();
    expect(status.active_release?.release_id).toBe('r1');
  });

  it('submits an import job and returns the unwrapped job id', async () => {
    primeAuth();
    server.use(
      http.post('/api/admin/nddscore/import', () =>
        HttpResponse.json({ job_id: ['job-xyz'], status: ['accepted'] })
      )
    );
    const result = await submitNddScoreImport({ recordId: '20258027', validateOnly: true });
    expect(result.jobId).toBe('job-xyz');
  });
});
