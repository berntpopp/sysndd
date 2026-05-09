// app/src/api/entity.spec.ts
//
// Vitest + MSW spec for the typed entity helpers (W3.6).

import { describe, it, expect } from 'vitest';
import { http, HttpResponse } from 'msw';

import {
  listEntities,
  listEntitiesXlsx,
  createEntity,
  renameEntity,
  deactivateEntity,
  getEntityPhenotypes,
  getEntityVariation,
  getEntityReview,
  getEntityStatus,
  getEntityPublications,
  type EntityListResponse,
  type EntityMutationResponse,
} from './entity';
import { isApiError } from './client';
import { server } from '@/test-utils/mocks/server';

describe('api/entity — listEntities', () => {
  it('forwards format=json + filter/fields params', async () => {
    let observedQuery: URLSearchParams | null = null;
    const ok: EntityListResponse = { links: {}, meta: {}, data: [] };
    server.use(
      http.get('/api/entity/', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json(ok);
      })
    );

    await listEntities({ filter: 'symbol:GRIN2B', fields: 'entity_id,symbol' });
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('format')).toBe('json');
    expect(q.get('filter')).toBe('symbol:GRIN2B');
    expect(q.get('fields')).toBe('entity_id,symbol');
  });

  it('forwards compact=true to the entity endpoint when set', async () => {
    let observedQuery: URLSearchParams | null = null;
    server.use(
      http.get('/api/entity/', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json({ links: {}, meta: {}, data: [] });
      })
    );
    await listEntities({ filter: 'equals(symbol,GRIN2B)', compact: true });
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('compact')).toBe('true');
  });

  it('does not include compact when omitted (default behaviour preserved)', async () => {
    let observedQuery: URLSearchParams | null = null;
    server.use(
      http.get('/api/entity/', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json({ links: {}, meta: {}, data: [] });
      })
    );
    await listEntities({ filter: 'equals(symbol,GRIN2B)' });
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('compact')).toBeNull();
  });

  it('forwards compact=false explicitly when caller passes it', async () => {
    let observedQuery: URLSearchParams | null = null;
    server.use(
      http.get('/api/entity/', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json({ links: {}, meta: {}, data: [] });
      })
    );
    await listEntities({ filter: 'equals(symbol,GRIN2B)', compact: false });
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('compact')).toBe('false');
  });
});

describe('api/entity — listEntitiesXlsx', () => {
  it('returns a Blob and forces format=xlsx', async () => {
    let observedQuery: URLSearchParams | null = null;
    server.use(
      http.get('/api/entity/', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return new HttpResponse(new Uint8Array([0x50, 0x4b, 0x03, 0x04]), {
          status: 200,
          headers: {
            'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          },
        });
      })
    );

    const blob = await listEntitiesXlsx({ sort: 'entity_id' });
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('format')).toBe('xlsx');
    expect(q.get('sort')).toBe('entity_id');
    expect(blob).toBeInstanceOf(Blob);
  });
});

describe('api/entity — createEntity', () => {
  it('POSTs the create_json body and forwards direct_approval', async () => {
    let receivedBody: unknown = null;
    let observedQuery: URLSearchParams | null = null;
    const ok: EntityMutationResponse = {
      status: 200,
      message: 'OK',
      entry: { entity_id: 7 },
    };
    server.use(
      http.post('/api/entity/create', async ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        receivedBody = await request.json();
        return HttpResponse.json(ok, { status: 201 });
      })
    );

    const result = await createEntity(
      {
        create_json: {
          entity: {
            hgnc_id: 'HGNC:4586',
            disease_ontology_id_version: 'OMIM:613970-2026-04-25',
            hpo_mode_of_inheritance_term: 'AD',
            ndd_phenotype: 1,
          },
          review: { comment: 'sample' },
          status: { category_id: 1 },
        },
      },
      { direct_approval: true }
    );

    expect((receivedBody as { create_json?: unknown }).create_json).toBeDefined();
    expect((observedQuery as unknown as URLSearchParams).get('direct_approval')).toBe('true');
    expect(result.entry?.entity_id).toBe(7);
  });

  it('throws AxiosError on 409 (duplicate)', async () => {
    server.use(
      http.post('/api/entity/create', () =>
        HttpResponse.json({ status: 409, message: 'duplicate' }, { status: 409 })
      )
    );

    let caught: unknown;
    try {
      await createEntity({
        create_json: {
          entity: {
            hgnc_id: 'HGNC:1',
            disease_ontology_id_version: 'OMIM:1-2026-01-01',
            hpo_mode_of_inheritance_term: 'AD',
            ndd_phenotype: 1,
          },
          review: {},
          status: { category_id: 1 },
        },
      });
    } catch (err) {
      caught = err;
    }
    expect(isApiError(caught)).toBe(true);
    if (isApiError(caught)) {
      expect(caught.response?.status).toBe(409);
    }
  });
});

describe('api/entity — renameEntity', () => {
  it('POSTs the rename_json body', async () => {
    let receivedBody: unknown = null;
    server.use(
      http.post('/api/entity/rename', async ({ request }) => {
        receivedBody = await request.json();
        return HttpResponse.json({ status: 200, entry: { entity_id: 8 } });
      })
    );

    await renameEntity({
      rename_json: {
        entity: {
          entity_id: 7,
          hgnc_id: 'HGNC:4586',
          hpo_mode_of_inheritance_term: 'AD',
          ndd_phenotype: 1,
          disease_ontology_id_version: 'OMIM:613970-2026-05-01',
        },
      },
    });

    expect((receivedBody as { rename_json?: unknown }).rename_json).toBeDefined();
  });
});

describe('api/entity — deactivateEntity', () => {
  it('POSTs the deactivate_json body', async () => {
    let receivedBody: unknown = null;
    server.use(
      http.post('/api/entity/deactivate', async ({ request }) => {
        receivedBody = await request.json();
        return HttpResponse.json({ status: 200, message: 'OK' });
      })
    );

    await deactivateEntity({
      deactivate_json: {
        entity: {
          entity_id: 7,
          hgnc_id: 'HGNC:4586',
          hpo_mode_of_inheritance_term: 'AD',
          ndd_phenotype: 1,
          is_active: 0,
          replaced_by: null,
        },
      },
    });

    expect((receivedBody as { deactivate_json?: unknown }).deactivate_json).toBeDefined();
  });
});

describe('api/entity — getEntityPhenotypes', () => {
  it('URL-encodes the path param', async () => {
    let observedPath: string | null = null;
    server.use(
      http.get('/api/entity/:id/phenotypes', ({ request }) => {
        observedPath = new URL(request.url).pathname;
        return HttpResponse.json([]);
      })
    );

    await getEntityPhenotypes(7);
    expect(observedPath).toBe('/api/entity/7/phenotypes');
  });

  it('serializes current_review boolean as TRUE/FALSE for the R server', async () => {
    let observedQuery: URLSearchParams | null = null;
    server.use(
      http.get('/api/entity/:id/phenotypes', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json([]);
      })
    );

    await getEntityPhenotypes(7, { current_review: false });
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('current_review')).toBe('FALSE');
  });
});

describe('api/entity — getEntityVariation', () => {
  it('returns the variation rows on 200', async () => {
    server.use(
      http.get('/api/entity/:id/variation', () =>
        HttpResponse.json([
          { entity_id: 7, vario_id: 'VariO:0001', vario_name: 'missense', modifier_id: 1 },
        ])
      )
    );

    const rows = await getEntityVariation(7);
    expect(rows).toHaveLength(1);
    expect(rows[0].vario_id).toBe('VariO:0001');
  });
});

describe('api/entity — getEntityReview', () => {
  it('returns the review rows on 200', async () => {
    server.use(
      http.get('/api/entity/:id/review', () =>
        HttpResponse.json([
          {
            entity_id: 7,
            review_id: 100,
            synopsis: 'foo',
            review_date: '2026-01-01',
            comment: null,
          },
        ])
      )
    );

    const rows = await getEntityReview(7);
    expect(rows[0].review_id).toBe(100);
  });
});

describe('api/entity — getEntityStatus', () => {
  it('returns the status rows on 200', async () => {
    server.use(
      http.get('/api/entity/:id/status', () =>
        HttpResponse.json([
          {
            status_id: 1,
            entity_id: 7,
            category: 'Definitive',
            category_id: 5,
            status_date: '2026-01-01',
            comment: null,
            problematic: 0,
          },
        ])
      )
    );

    const rows = await getEntityStatus(7);
    expect(rows[0].category).toBe('Definitive');
  });
});

describe('api/entity — getEntityPublications', () => {
  it('returns the publications on 200', async () => {
    server.use(
      http.get('/api/entity/:id/publications', () =>
        HttpResponse.json([
          {
            entity_id: 7,
            publication_id: 'PMID:12345',
            publication_type: 'gene_review',
            is_reviewed: 1,
          },
        ])
      )
    );

    const rows = await getEntityPublications(7);
    expect(rows[0].publication_id).toBe('PMID:12345');
  });
});
