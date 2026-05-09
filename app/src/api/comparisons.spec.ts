// app/src/api/comparisons.spec.ts
//
// Vitest + MSW spec for the typed comparisons helpers (W3.5).

import { describe, it, expect } from 'vitest';
import { http, HttpResponse } from 'msw';

import {
  getComparisonsOptions,
  getUpsetData,
  getSimilarity,
  browseComparisons,
  browseComparisonsXlsx,
  getComparisonsMetadata,
  type ComparisonsOptions,
  type UpsetRow,
  type SimilarityCell,
  type BrowseComparisonsResponse,
  type ComparisonsMetadata,
} from './comparisons';
import { server } from '@/test-utils/mocks/server';

describe('api/comparisons — getComparisonsOptions', () => {
  it('returns the option-lists envelope on 200', async () => {
    const ok: ComparisonsOptions = {
      list: [{ list: 'SysNDD' }, { list: 'panelapp' }],
      inheritance: [{ inheritance: 'AD' }],
      category: [{ category: 'Definitive' }],
      pathogenicity_mode: [{ pathogenicity_mode: 'LoF' }],
    };
    server.use(http.get('/api/comparisons/options', () => HttpResponse.json(ok)));

    const result = await getComparisonsOptions();
    expect(result.list).toHaveLength(2);
  });
});

describe('api/comparisons — getUpsetData', () => {
  it('forwards fields + definitive_only params', async () => {
    let observedQuery: URLSearchParams | null = null;
    const ok: UpsetRow[] = [{ name: 'HGNC:1', sets: ['SysNDD'] }];
    server.use(
      http.get('/api/comparisons/upset', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json(ok);
      })
    );

    await getUpsetData({ fields: 'SysNDD,panelapp', definitive_only: 'true' });
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('fields')).toBe('SysNDD,panelapp');
    expect(q.get('definitive_only')).toBe('true');
  });
});

describe('api/comparisons — getSimilarity', () => {
  it('returns the melted similarity matrix on 200', async () => {
    const ok: SimilarityCell[] = [{ x: 'SysNDD', y: 'SysNDD', value: 1.0 }];
    server.use(http.get('/api/comparisons/similarity', () => HttpResponse.json(ok)));

    const result = await getSimilarity();
    expect(result[0].value).toBe(1.0);
  });
});

describe('api/comparisons — browseComparisons', () => {
  it('forces format=json and returns the cursor envelope', async () => {
    let observedQuery: URLSearchParams | null = null;
    const ok: BrowseComparisonsResponse = {
      meta: [],
      data: [{ symbol: 'GRIN2B', SysNDD: 1, panelapp: 1 }],
      links: [],
    };
    server.use(
      http.get('/api/comparisons/browse', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json(ok);
      })
    );

    const result = await browseComparisons({ sort: 'symbol' });
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('format')).toBe('json');
    expect(q.get('sort')).toBe('symbol');
    expect(result.data).toHaveLength(1);
  });
});

describe('api/comparisons — browseComparisonsXlsx', () => {
  it('returns a Blob and forces format=xlsx', async () => {
    let observedQuery: URLSearchParams | null = null;
    server.use(
      http.get('/api/comparisons/browse', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return new HttpResponse(new Uint8Array([0x50, 0x4b, 0x03, 0x04]), {
          status: 200,
          headers: {
            'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          },
        });
      })
    );

    const blob = await browseComparisonsXlsx({ filter: 'category:Definitive' });
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('format')).toBe('xlsx');
    expect(q.get('filter')).toBe('category:Definitive');
    expect(blob).toBeInstanceOf(Blob);
  });
});

describe('api/comparisons — getComparisonsMetadata', () => {
  it('returns the metadata envelope on 200', async () => {
    const ok: ComparisonsMetadata = {
      last_full_refresh: '2026-04-25T00:00:00Z',
      last_refresh_status: 'success',
      last_refresh_error: null,
      sources_count: 8,
      rows_imported: 12345,
    };
    server.use(http.get('/api/comparisons/metadata', () => HttpResponse.json(ok)));

    const result = await getComparisonsMetadata();
    expect(result.last_refresh_status).toBe('success');
  });

  it('returns the never-state envelope when no metadata exists', async () => {
    const ok: ComparisonsMetadata = {
      last_full_refresh: null,
      last_refresh_status: 'never',
      last_refresh_error: null,
      sources_count: 0,
      rows_imported: 0,
    };
    server.use(http.get('/api/comparisons/metadata', () => HttpResponse.json(ok)));

    const result = await getComparisonsMetadata();
    expect(result.last_refresh_status).toBe('never');
  });
});
