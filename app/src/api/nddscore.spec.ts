import { afterEach, describe, expect, it } from 'vitest';
import { http, HttpResponse } from 'msw';
import { server } from '@/test-utils/mocks/server';
import { fetchCurrentRelease, fetchGenePredictions } from './nddscore';

describe('nddscore api client', () => {
  afterEach(() => server.resetHandlers());

  it('fetches the current release', async () => {
    server.use(
      http.get('/api/nddscore/release/current', () =>
        HttpResponse.json({ release_id: ['ndd_fixture_release'], n_genes: [3] })
      )
    );
    const release = await fetchCurrentRelease();
    expect(release.release_id).toBe('ndd_fixture_release');
    expect(release.n_genes).toBe(3);
  });

  it('passes pagination + filter params to the genes endpoint', async () => {
    let seen: URL | null = null;
    server.use(
      http.get('/api/nddscore/genes', ({ request }) => {
        seen = new URL(request.url);
        return HttpResponse.json({ data: [], total: 0, page: 2, page_size: 10 });
      })
    );
    await fetchGenePredictions({ page: 2, pageSize: 10, riskTier: 'Low' });
    expect(seen!.searchParams.get('page')).toBe('2');
    expect(seen!.searchParams.get('page_size')).toBe('10');
    expect(seen!.searchParams.get('risk_tier')).toBe('Low');
  });
});
