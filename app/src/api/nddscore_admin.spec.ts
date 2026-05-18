import { afterEach, describe, expect, it } from 'vitest';
import { http, HttpResponse } from 'msw';
import { server } from '@/test-utils/mocks/server';
import { primeAuth } from '@/test-utils/primeAuth';
import { fetchNddScoreStatus, fetchNddScoreZenodo, submitNddScoreImport } from './nddscore_admin';

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
    let payload: unknown;
    server.use(
      http.post('/api/admin/nddscore/import', async ({ request }) => {
        payload = await request.json();
        return HttpResponse.json({ job_id: ['job-xyz'], status: ['accepted'] });
      })
    );
    const result = await submitNddScoreImport({ recordId: '20258027', validateOnly: true });
    expect(result.jobId).toBe('job-xyz');
    expect(payload).toEqual({ record_id: '20258027', validate_only: true });
  });

  it('lets the backend apply the configured default record id', async () => {
    primeAuth();
    let zenodoUrl: URL | undefined;
    let importPayload: unknown;
    server.use(
      http.get('/api/admin/nddscore/zenodo', ({ request }) => {
        zenodoUrl = new URL(request.url);
        return HttpResponse.json({ zenodo: {}, active_release: null, matches_active: false });
      }),
      http.post('/api/admin/nddscore/import', async ({ request }) => {
        importPayload = await request.json();
        return HttpResponse.json({ job_id: ['job-xyz'], status: ['accepted'] });
      })
    );

    await fetchNddScoreZenodo();
    await submitNddScoreImport({ validateOnly: false });

    expect(zenodoUrl?.searchParams.has('record_id')).toBe(false);
    expect(importPayload).toEqual({ validate_only: false });
  });
});
