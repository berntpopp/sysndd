// app/src/api/phenotype.spec.ts
//
// Vitest + MSW spec for the typed phenotype helpers (W3.15).

import { describe, it, expect } from 'vitest';
import { http, HttpResponse } from 'msw';

import {
  browsePhenotypeEntities,
  browsePhenotypeEntitiesXlsx,
  getPhenotypeCorrelation,
  getPhenotypeCount,
  type BrowsePhenotypeEntitiesResponse,
  type PhenotypeCorrelationCell,
  type PhenotypeCountRow,
} from './phenotype';
import { server } from '@/test-utils/mocks/server';

describe('api/phenotype — browsePhenotypeEntities', () => {
  it('forces format=json and forwards filter param', async () => {
    let observedQuery: URLSearchParams | null = null;
    const ok: BrowsePhenotypeEntitiesResponse = { data: [] };
    server.use(
      http.get('/api/phenotype/entities/browse', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json(ok);
      }),
    );

    await browsePhenotypeEntities({ filter: 'contains(ndd_phenotype_word,Yes)' });
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('format')).toBe('json');
    expect(q.get('filter')).toBe('contains(ndd_phenotype_word,Yes)');
  });
});

describe('api/phenotype — browsePhenotypeEntitiesXlsx', () => {
  it('returns a Blob and forces format=xlsx', async () => {
    let observedQuery: URLSearchParams | null = null;
    server.use(
      http.get('/api/phenotype/entities/browse', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return new HttpResponse(new Uint8Array([0x50, 0x4b]), {
          status: 200,
          headers: {
            'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          },
        });
      }),
    );

    const blob = await browsePhenotypeEntitiesXlsx({ sort: 'entity_id' });
    expect((observedQuery as unknown as URLSearchParams).get('format')).toBe('xlsx');
    expect(blob).toBeInstanceOf(Blob);
  });
});

describe('api/phenotype — getPhenotypeCorrelation', () => {
  it('returns the melted matrix on 200', async () => {
    const ok: PhenotypeCorrelationCell[] = [
      { x: 'a', x_id: 'HP:0001249', y: 'b', y_id: 'HP:0001256', value: 0.42 },
    ];
    server.use(
      http.get('/api/phenotype/correlation', () => HttpResponse.json(ok)),
    );

    const result = await getPhenotypeCorrelation();
    expect(result[0].value).toBe(0.42);
  });

  it('forwards the filter query param', async () => {
    let observedQuery: URLSearchParams | null = null;
    server.use(
      http.get('/api/phenotype/correlation', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json([]);
      }),
    );

    await getPhenotypeCorrelation({ filter: 'any(category,Definitive)' });
    expect((observedQuery as unknown as URLSearchParams).get('filter')).toBe(
      'any(category,Definitive)',
    );
  });
});

describe('api/phenotype — getPhenotypeCount', () => {
  it('returns the count rows on 200', async () => {
    const ok: PhenotypeCountRow[] = [
      { HPO_term: 'Intellectual disability', phenotype_id: 'HP:0001249', count: 200 },
    ];
    server.use(
      http.get('/api/phenotype/count', () => HttpResponse.json(ok)),
    );

    const result = await getPhenotypeCount();
    expect(result[0].count).toBe(200);
  });
});
