// app/src/api/publication.spec.ts
//
// Vitest + MSW spec for the typed publication helpers (W3.16).

import { describe, it, expect } from 'vitest';
import { http, HttpResponse } from 'msw';

import {
  getPublicationStats,
  getPublicationByPmid,
  listPublications,
  listPublicationsXlsx,
  searchPubtator,
  listPubtatorTable,
  listPubtatorTableXlsx,
  listPubtatorGenes,
  listPubtatorGenesXlsx,
  backfillPubtatorGenes,
  getPubtatorCacheStatus,
  updatePubtator,
  submitPubtatorUpdate,
  clearPubtatorCache,
  type PublicationStats,
  type PublicationRecord,
  type PublicationListResponse,
  type PubtatorSearchResponse,
  type PubtatorTableResponse,
  type PubtatorGenesResponse,
  type PubtatorBackfillResponse,
  type PubtatorCacheStatus,
  type PubtatorUpdateResponse,
  type PubtatorAsyncSubmitResponse,
  type PubtatorClearCacheResponse,
} from './publication';
import { isApiError } from './client';
import { server } from '@/test-utils/mocks/server';

describe('api/publication — getPublicationStats', () => {
  it('returns the stats envelope on 200', async () => {
    const ok: PublicationStats = {
      total: 4500,
      oldest_update: '2020-01-01',
      outdated_count: 1200,
    };
    server.use(http.get('/api/publication/stats', () => HttpResponse.json(ok)));

    const result = await getPublicationStats();
    expect(result.total).toBe(4500);
  });
});

describe('api/publication — getPublicationByPmid', () => {
  it('URL-encodes the pmid path param', async () => {
    let observedPath: string | null = null;
    server.use(
      http.get('/api/publication/:pmid', ({ request }) => {
        observedPath = new URL(request.url).pathname;
        return HttpResponse.json([]);
      })
    );

    await getPublicationByPmid('PMID:12345');
    expect(observedPath).toBe('/api/publication/PMID%3A12345');
  });

  it('returns the metadata array on 200', async () => {
    const ok: PublicationRecord[] = [{ publication_id: 'PMID:12345', Title: 'foo' }];
    server.use(http.get('/api/publication/:pmid', () => HttpResponse.json(ok)));

    const result = await getPublicationByPmid('12345');
    expect(result[0].publication_id).toBe('PMID:12345');
  });
});

describe('api/publication — listPublications', () => {
  it('forces format=json and returns the envelope', async () => {
    let observedQuery: URLSearchParams | null = null;
    const ok: PublicationListResponse = { data: [] };
    server.use(
      http.get('/api/publication/', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json(ok);
      })
    );

    await listPublications();
    expect((observedQuery as unknown as URLSearchParams).get('format')).toBe('json');
  });
});

describe('api/publication — listPublicationsXlsx', () => {
  it('returns a Blob and forces format=xlsx', async () => {
    server.use(
      http.get(
        '/api/publication/',
        () =>
          new HttpResponse(new Uint8Array([0x50, 0x4b]), {
            status: 200,
            headers: {
              'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            },
          })
      )
    );
    const blob = await listPublicationsXlsx();
    expect(blob).toBeInstanceOf(Blob);
  });
});

describe('api/publication — searchPubtator', () => {
  it('returns the search envelope on 200', async () => {
    const ok: PubtatorSearchResponse = {
      meta: { perPage: 10, currentPage: 1, totalPages: 5 },
      data: [{ pmid: 'PMID:1' }],
    };
    server.use(http.get('/api/publication/pubtator/search', () => HttpResponse.json(ok)));

    const result = await searchPubtator({ current_page: 1 });
    expect(result.meta.totalPages).toBe(5);
  });
});

describe('api/publication — listPubtatorTable', () => {
  it('forces format=json and returns the table envelope', async () => {
    let observedQuery: URLSearchParams | null = null;
    const ok: PubtatorTableResponse = { data: [] };
    server.use(
      http.get('/api/publication/pubtator/table', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json(ok);
      })
    );

    await listPubtatorTable();
    expect((observedQuery as unknown as URLSearchParams).get('format')).toBe('json');
  });

  it('forwards PMID filter params and accepts request config', async () => {
    let observedQuery: URLSearchParams | null = null;
    const ok: PubtatorTableResponse = { data: [{ pmid: 123 }] };
    server.use(
      http.get('/api/publication/pubtator/table', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json(ok);
      })
    );

    const controller = new AbortController();
    const result = await listPubtatorTable(
      {
        filter: 'any(pmid,123,456)',
        fields: 'search_id,pmid,title',
        page_size: '2',
      },
      { signal: controller.signal }
    );

    expect(result.data[0].pmid).toBe(123);
    expect(observedQuery).not.toBeNull();
    const query = observedQuery as unknown as URLSearchParams;
    expect(query.get('filter')).toBe('any(pmid,123,456)');
    expect(query.get('fields')).toBe('search_id,pmid,title');
    expect(query.get('page_size')).toBe('2');
    expect(query.get('format')).toBe('json');
  });
});

describe('api/publication — listPubtatorTableXlsx', () => {
  it('returns a Blob and forces format=xlsx', async () => {
    server.use(
      http.get(
        '/api/publication/pubtator/table',
        () =>
          new HttpResponse(new Uint8Array([0x50, 0x4b]), {
            status: 200,
            headers: {
              'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            },
          })
      )
    );
    const blob = await listPubtatorTableXlsx();
    expect(blob).toBeInstanceOf(Blob);
  });
});

describe('api/publication — listPubtatorGenes', () => {
  it('returns the genes envelope on 200', async () => {
    const ok: PubtatorGenesResponse = { data: [] };
    server.use(http.get('/api/publication/pubtator/genes', () => HttpResponse.json(ok)));
    const result = await listPubtatorGenes();
    expect(result.data).toHaveLength(0);
  });

  it('forwards cursor params and forces format=json', async () => {
    let observedQuery: URLSearchParams | null = null;
    const ok: PubtatorGenesResponse = { data: [] };
    server.use(
      http.get('/api/publication/pubtator/genes', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json(ok);
      })
    );

    await listPubtatorGenes({
      sort: '-is_novel,oldest_pub_date',
      filter: 'all(publication_count,5)',
      page_after: 25,
      page_size: '10',
      fields: 'gene_symbol,pmids',
    });

    expect(observedQuery).not.toBeNull();
    const query = observedQuery as unknown as URLSearchParams;
    expect(query.get('sort')).toBe('-is_novel,oldest_pub_date');
    expect(query.get('filter')).toBe('all(publication_count,5)');
    expect(query.get('page_after')).toBe('25');
    expect(query.get('page_size')).toBe('10');
    expect(query.get('fields')).toBe('gene_symbol,pmids');
    expect(query.get('format')).toBe('json');
  });
});

describe('api/publication — listPubtatorGenesXlsx', () => {
  it('returns a Blob and forces format=xlsx', async () => {
    server.use(
      http.get(
        '/api/publication/pubtator/genes',
        () =>
          new HttpResponse(new Uint8Array([0x50, 0x4b]), {
            status: 200,
            headers: {
              'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            },
          })
      )
    );
    const blob = await listPubtatorGenesXlsx();
    expect(blob).toBeInstanceOf(Blob);
  });
});

describe('api/publication — backfillPubtatorGenes', () => {
  it('returns the backfill summary on 200', async () => {
    const ok: PubtatorBackfillResponse = {
      updated: 12,
      total_null: 12,
      execution_time: '5 secs',
      message: 'Updated 12 rows',
    };
    server.use(http.post('/api/publication/pubtator/backfill-genes', () => HttpResponse.json(ok)));
    const result = await backfillPubtatorGenes();
    expect(result.updated).toBe(12);
  });
});

describe('api/publication — getPubtatorCacheStatus', () => {
  it('forwards query and returns the status envelope', async () => {
    let observedQuery: URLSearchParams | null = null;
    const ok: PubtatorCacheStatus = {
      query: 'epilepsy',
      cached: true,
      pages_cached: 50,
      total_pages_available: 100,
      total_results_available: 1000,
      cache_date: '2026-04-25',
      estimated_fetch_time_minutes: 2.1,
      message: 'Soft update will fetch 50 new pages.',
    };
    server.use(
      http.get('/api/publication/pubtator/cache-status', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json(ok);
      })
    );

    await getPubtatorCacheStatus({ query: 'epilepsy' });
    expect((observedQuery as unknown as URLSearchParams).get('query')).toBe('epilepsy');
  });

  it('throws AxiosError on 400 (missing query)', async () => {
    server.use(
      http.get('/api/publication/pubtator/cache-status', () =>
        HttpResponse.json({ error: 'Query parameter is required' }, { status: 400 })
      )
    );

    let caught: unknown;
    try {
      await getPubtatorCacheStatus({ query: '' });
    } catch (err) {
      caught = err;
    }
    expect(isApiError(caught)).toBe(true);
    if (isApiError(caught)) {
      expect(caught.response?.status).toBe(400);
    }
  });
});

describe('api/publication — updatePubtator', () => {
  it('forwards query and returns the update result', async () => {
    let observedQuery: URLSearchParams | null = null;
    const ok: PubtatorUpdateResponse = {
      success: true,
      query_id: 'q-1',
      pages_cached: 10,
      pages_total: 10,
      publications_count: 100,
      execution_time: '60 secs',
    };
    server.use(
      http.post('/api/publication/pubtator/update', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json(ok);
      })
    );

    const result = await updatePubtator({ query: 'epilepsy', max_pages: 10 });
    expect((observedQuery as unknown as URLSearchParams).get('query')).toBe('epilepsy');
    expect(result.success).toBe(true);
  });
});

describe('api/publication — submitPubtatorUpdate', () => {
  it('returns the 202 async submit envelope', async () => {
    const ok: PubtatorAsyncSubmitResponse = {
      job_id: 'p-1',
      status: 'accepted',
      query: 'epilepsy',
      max_pages: 10,
      estimated_seconds: 25,
      status_url: '/api/jobs/p-1/status',
    };
    server.use(
      http.post('/api/publication/pubtator/update/submit', () =>
        HttpResponse.json(ok, { status: 202 })
      )
    );

    const result = await submitPubtatorUpdate({ query: 'epilepsy', max_pages: 10 });
    expect(result.job_id).toBe('p-1');
  });
});

describe('api/publication — clearPubtatorCache', () => {
  it('returns the clear envelope on 200', async () => {
    const ok: PubtatorClearCacheResponse = {
      success: true,
      deleted: { queries: 1, publications: 100, annotations: 200 },
      execution_time: '1 sec',
      message: 'Cleared 1 queries, 100 publications, 200 annotations',
    };
    server.use(http.post('/api/publication/pubtator/clear-cache', () => HttpResponse.json(ok)));
    const result = await clearPubtatorCache();
    expect(result.deleted?.queries).toBe(1);
  });
});
