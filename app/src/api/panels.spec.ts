// app/src/api/panels.spec.ts
//
// Vitest + MSW spec for the typed panels helpers (W3.14).

import { describe, it, expect } from 'vitest';
import { http, HttpResponse } from 'msw';

import {
  getPanelOptions,
  browsePanels,
  browsePanelsXlsx,
  type PanelOptionGroup,
  type BrowsePanelsResponse,
} from './panels';
import { server } from '@/test-utils/mocks/server';

describe('api/panels — getPanelOptions', () => {
  it('returns the option-groups array on 200', async () => {
    const ok: PanelOptionGroup[] = [
      { lists: 'categories_list', options: [{ value: 'Definitive' }] },
      { lists: 'inheritance_list', options: [{ value: 'Autosomal dominant' }] },
    ];
    server.use(http.get('/api/panels/options', () => HttpResponse.json(ok)));

    const result = await getPanelOptions();
    expect(result).toHaveLength(2);
  });
});

describe('api/panels — browsePanels', () => {
  it('forces format=json and forwards filter/sort params', async () => {
    let observedQuery: URLSearchParams | null = null;
    const ok: BrowsePanelsResponse = { data: [] };
    server.use(
      http.get('/api/panels/browse', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return HttpResponse.json(ok);
      })
    );

    await browsePanels({ filter: "equals(category,'Definitive')", sort: 'symbol' });
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('format')).toBe('json');
    expect(q.get('filter')).toBe("equals(category,'Definitive')");
    expect(q.get('sort')).toBe('symbol');
  });
});

describe('api/panels — browsePanelsXlsx', () => {
  it('returns a Blob and forces format=xlsx', async () => {
    let observedQuery: URLSearchParams | null = null;
    server.use(
      http.get('/api/panels/browse', ({ request }) => {
        observedQuery = new URL(request.url).searchParams;
        return new HttpResponse(new Uint8Array([0x50, 0x4b]), {
          status: 200,
          headers: {
            'Content-Type': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
          },
        });
      })
    );

    const blob = await browsePanelsXlsx({ sort: 'symbol' });
    const q = observedQuery as unknown as URLSearchParams;
    expect(q.get('format')).toBe('xlsx');
    expect(blob).toBeInstanceOf(Blob);
  });
});
