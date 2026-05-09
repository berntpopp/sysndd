// app/src/api/variant.spec.ts
//
// Vitest + MSW spec for the typed variant helpers (W3.23).

import { describe, it, expect } from 'vitest';
import { http, HttpResponse } from 'msw';

import {
  browseVariantEntities,
  getVariantCorrelation,
  getVariantCounts,
  type VariantBrowseResponse,
  type VariantCorrelationCell,
  type VariantCountRow,
} from './variant';
import { isApiError } from './client';
import { server } from '@/test-utils/mocks/server';

describe('api/variant — browseVariantEntities', () => {
  it('forwards filter/sort/page_size params via config.params', async () => {
    let observedQuery: URLSearchParams | null = null;
    const ok: VariantBrowseResponse = {
      links: {},
      meta: {},
      data: [
        {
          entity_id: 1,
          symbol: 'GRIN2B',
          disease_ontology_name: 'Mental retardation, autosomal dominant 6',
          hpo_mode_of_inheritance_term_name: 'Autosomal dominant',
          category: 'Definitive',
          ndd_phenotype_word: 'Yes',
          modifier_variant_id: '1-VariO:0001',
          details: null,
        },
      ],
    };
    server.use(
      http.get('/api/variant/browse', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json(ok);
      })
    );

    const result = await browseVariantEntities({
      filter: 'any(category,Definitive)',
      sort: 'symbol',
      page_size: '10',
    });
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('filter')).toBe('any(category,Definitive)');
    expect(q.get('sort')).toBe('symbol');
    expect(q.get('page_size')).toBe('10');
    expect(result.data[0].symbol).toBe('GRIN2B');
  });

  it('throws AxiosError on 500', async () => {
    server.use(
      http.get('/api/variant/browse', () => HttpResponse.json({ error: 'boom' }, { status: 500 }))
    );

    let caught: unknown;
    try {
      await browseVariantEntities();
    } catch (err) {
      caught = err;
    }
    expect(isApiError(caught)).toBe(true);
    if (isApiError(caught)) {
      expect(caught.response?.status).toBe(500);
    }
  });
});

describe('api/variant — getVariantCorrelation', () => {
  it('returns long-form correlation cells on 200', async () => {
    const ok: VariantCorrelationCell[] = [
      {
        x: 'missense variant',
        x_vario_id: 'VariO:0001',
        y: 'splice variant',
        y_vario_id: 'VariO:0002',
        value: 0.42,
      },
    ];
    server.use(http.get('/api/variant/correlation', () => HttpResponse.json(ok)));

    const result = await getVariantCorrelation({ filter: 'any(category,Definitive)' });
    expect(result[0].value).toBe(0.42);
    expect(result[0].x_vario_id).toBe('VariO:0001');
  });

  it('forwards limit/offset query params', async () => {
    let observedQuery: URLSearchParams | null = null;
    server.use(
      http.get('/api/variant/correlation', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json([]);
      })
    );

    await getVariantCorrelation({ limit: 100, offset: 50 });
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('limit')).toBe('100');
    expect(q.get('offset')).toBe('50');
  });
});

describe('api/variant — getVariantCounts', () => {
  it('returns variant counts on 200', async () => {
    const ok: VariantCountRow[] = [
      { vario_id: 'VariO:0001', variant_name: 'missense variant', count: 42 },
      { vario_id: 'VariO:0002', variant_name: 'splice variant', count: 7 },
    ];
    server.use(http.get('/api/variant/count', () => HttpResponse.json(ok)));

    const result = await getVariantCounts();
    expect(result.length).toBe(2);
    expect(result[0].count).toBe(42);
  });

  it('throws AxiosError on 500', async () => {
    server.use(
      http.get('/api/variant/count', () => HttpResponse.json({ error: 'boom' }, { status: 500 }))
    );
    await expect(getVariantCounts()).rejects.toThrow();
  });
});
