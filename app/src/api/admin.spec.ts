// app/src/api/admin.spec.ts
//
// Vitest + MSW spec for the typed admin helpers (W3.2).

import { describe, it, expect } from 'vitest';
import { http, HttpResponse } from 'msw';

import {
  getOpenApiSpec,
  updateOntologyAsync,
  forceApplyOntology,
  updateHgncData,
  getApiVersion,
  getAnnotationDates,
  getDeprecatedEntities,
  testSmtp,
  refreshPublications,
  type AsyncJobAccepted,
  type AnnotationDates,
  type DeprecatedEntitiesResponse,
  type SmtpTestResponse,
  type PublicationRefreshNoop,
} from './admin';
import { isApiError } from './client';
import { server } from '@/test-utils/mocks/server';

describe('api/admin — getOpenApiSpec', () => {
  it('returns the OpenAPI spec on 200', async () => {
    server.use(http.get('/api/admin/openapi.json', () => HttpResponse.json({ openapi: '3.0.0' })));
    const spec = (await getOpenApiSpec()) as { openapi: string };
    expect(spec.openapi).toBe('3.0.0');
  });
});

describe('api/admin — updateOntologyAsync', () => {
  it('returns the AsyncJobAccepted envelope on 202', async () => {
    const expected: AsyncJobAccepted = { job_id: 'omim-1', status: 'accepted' };
    server.use(
      http.put('/api/admin/update_ontology_async', () =>
        HttpResponse.json(expected, { status: 202 })
      )
    );
    const result = await updateOntologyAsync();
    expect(result).toEqual(expected);
  });

  it('throws AxiosError on 403 (caller is not Administrator)', async () => {
    server.use(
      http.put('/api/admin/update_ontology_async', () =>
        HttpResponse.json({ error: 'forbidden' }, { status: 403 })
      )
    );
    let caught: unknown;
    try {
      await updateOntologyAsync();
    } catch (err) {
      caught = err;
    }
    expect(isApiError(caught)).toBe(true);
    if (isApiError(caught)) {
      expect(caught.response?.status).toBe(403);
    }
  });
});

describe('api/admin — forceApplyOntology', () => {
  it('forwards blocked_job_id as a query param', async () => {
    let observedQuery: URLSearchParams | null = null;
    const expected: AsyncJobAccepted = { job_id: 'force-1', status: 'accepted' };
    server.use(
      http.put('/api/admin/force_apply_ontology', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json(expected, { status: 202 });
      })
    );

    const result = await forceApplyOntology({ blocked_job_id: 'omim-blocked-1' });
    expect(observedQuery).not.toBeNull();
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('blocked_job_id')).toBe('omim-blocked-1');
    expect(result.job_id).toBe('force-1');
  });

  it('throws AxiosError on 410 (pending CSV expired)', async () => {
    server.use(
      http.put('/api/admin/force_apply_ontology', () =>
        HttpResponse.json({ error: 'stale' }, { status: 410 })
      )
    );
    await expect(forceApplyOntology({ blocked_job_id: 'omim-blocked-1' })).rejects.toThrow();
  });
});

describe('api/admin — updateHgncData', () => {
  it('returns success envelope on 200', async () => {
    server.use(
      http.put('/api/admin/update_hgnc_data', () =>
        HttpResponse.json({ status: 'Success', message: 'HGNC data update process completed.' })
      )
    );
    const result = await updateHgncData();
    expect(result.status).toBe('Success');
  });
});

describe('api/admin — getApiVersion', () => {
  it('returns the API version envelope on 200', async () => {
    server.use(
      http.get('/api/admin/api_version', () => HttpResponse.json({ api_version: '0.11.14' }))
    );
    const result = await getApiVersion();
    expect(result.api_version).toBe('0.11.14');
  });
});

describe('api/admin — getAnnotationDates', () => {
  it('returns the date envelope on 200', async () => {
    const ok: AnnotationDates = {
      omim_update: '2026-04-25 10:00:00',
      mondo_update: null,
      hgnc_update: '2026-04-20 09:00:00',
      disease_ontology_update: null,
    };
    server.use(http.get('/api/admin/annotation_dates', () => HttpResponse.json(ok)));
    const result = await getAnnotationDates();
    expect(result).toEqual(ok);
  });
});

describe('api/admin — getDeprecatedEntities', () => {
  it('returns the deprecated-entities envelope on 200', async () => {
    const ok: DeprecatedEntitiesResponse = {
      deprecated_count: 0,
      affected_entity_count: 0,
      affected_entities: [],
      mim2gene_date: '2026-04-25',
    };
    server.use(http.get('/api/admin/deprecated_entities', () => HttpResponse.json(ok)));
    const result = await getDeprecatedEntities();
    expect(result.deprecated_count).toBe(0);
  });
});

describe('api/admin — testSmtp', () => {
  it('returns SMTP-test result on 200', async () => {
    const ok: SmtpTestResponse = {
      success: true,
      host: 'smtp.example.com',
      port: 25,
      error: null,
    };
    server.use(http.get('/api/admin/smtp/test', () => HttpResponse.json(ok)));
    const result = await testSmtp();
    expect(result.success).toBe(true);
  });
});

describe('api/admin — refreshPublications', () => {
  it('returns AsyncJobAccepted envelope on 202', async () => {
    let receivedBody: unknown = null;
    const expected: AsyncJobAccepted = {
      job_id: 'pub-1',
      status: 'accepted',
      estimated_seconds: 5,
    };
    server.use(
      http.post('/api/admin/publications/refresh', async ({ request }) => {
        receivedBody = await request.json();
        return HttpResponse.json(expected, { status: 202 });
      })
    );

    const result = await refreshPublications({ pmids: ['12345', '67890'] });
    expect(receivedBody).toEqual({ pmids: ['12345', '67890'] });
    expect((result as AsyncJobAccepted).job_id).toBe('pub-1');
  });

  it('returns the no-op envelope on 200 when no publications match', async () => {
    const ok: PublicationRefreshNoop = {
      message: 'No publications need refreshing',
      filter_date: '2026-01-01',
      count: 0,
    };
    server.use(http.post('/api/admin/publications/refresh', () => HttpResponse.json(ok)));

    const result = await refreshPublications({ not_updated_since: '2026-01-01' });
    expect((result as PublicationRefreshNoop).count).toBe(0);
  });

  it('throws AxiosError on 400 (no pmids and no date filter)', async () => {
    server.use(
      http.post('/api/admin/publications/refresh', () =>
        HttpResponse.json(
          { error: 'No PMIDs provided and no date filter specified' },
          { status: 400 }
        )
      )
    );
    await expect(refreshPublications({})).rejects.toThrow();
  });
});
