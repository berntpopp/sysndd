// app/src/composables/usePubtatorGenePublications.spec.ts
//
// Covers the per-gene publication-detail cache extracted from
// PubtatorNDDGenes.vue:
//   - lazy fetch + caching (no refetch when already cached),
//   - resetCache() drops stale data on filter/sort change (correctness fix),
//   - real upstream errors surface a toast and exit the loading state,
//   - genuine aborts stay silent.

import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { http, HttpResponse } from 'msw';

import '@/plugins/axios';
import '@/api/client';
import { server } from '@/test-utils/mocks/server';
import { usePubtatorGenePublications } from './usePubtatorGenePublications';

const makeToast = vi.fn();

beforeEach(() => {
  makeToast.mockClear();
});

afterEach(() => {
  server.resetHandlers();
});

function pubtatorRows() {
  return HttpResponse.json({
    data: [
      {
        search_id: 1,
        pmid: 123,
        title: 'MECP2 paper',
        journal: 'Journal',
        date: '2001-01-01',
        score: 8,
        gene_symbols: 'MECP2',
        text_hl: 'MECP2 is linked to NDD.',
      },
    ],
  });
}

describe('usePubtatorGenePublications', () => {
  it('fetches and caches publications for a gene, then serves from cache', async () => {
    let calls = 0;
    server.use(
      http.get('*/api/publication/pubtator/table', () => {
        calls += 1;
        return pubtatorRows();
      })
    );

    const pubs = usePubtatorGenePublications({ makeToast });
    await pubs.fetchPublications('MECP2', ['123', '456']);

    expect(pubs.isCached('MECP2')).toBe(true);
    expect(pubs.getPublications('MECP2')).toHaveLength(1);
    expect(pubs.getPublications('MECP2')[0].title).toBe('MECP2 paper');
    expect(pubs.isLoading('MECP2')).toBe(false);
    expect(calls).toBe(1);

    // Second call must hit the cache (no second request).
    await pubs.fetchPublications('MECP2', ['123', '456']);
    expect(calls).toBe(1);
    expect(makeToast).not.toHaveBeenCalled();
  });

  it('resetCache clears cached publications so a filter/sort change cannot show stale data', async () => {
    server.use(http.get('*/api/publication/pubtator/table', () => pubtatorRows()));

    const pubs = usePubtatorGenePublications({ makeToast });
    await pubs.fetchPublications('MECP2', ['123']);
    expect(pubs.isCached('MECP2')).toBe(true);

    pubs.resetCache();
    expect(pubs.isCached('MECP2')).toBe(false);
    expect(pubs.getPublications('MECP2')).toEqual([]);
  });

  it('surfaces a toast and records an empty result on a real upstream error', async () => {
    server.use(
      http.get('*/api/publication/pubtator/table', () => new HttpResponse(null, { status: 500 }))
    );

    const pubs = usePubtatorGenePublications({ makeToast });
    await pubs.fetchPublications('SCN2A', ['789']);

    expect(makeToast).toHaveBeenCalledTimes(1);
    expect(makeToast.mock.calls[0][2]).toBe('danger');
    // Row exits its spinner and shows the empty/fallback state.
    expect(pubs.isLoading('SCN2A')).toBe(false);
    expect(pubs.isCached('SCN2A')).toBe(true);
    expect(pubs.getPublications('SCN2A')).toEqual([]);
  });

  it('stays silent and does not cache when the request is aborted', async () => {
    server.use(
      http.get('*/api/publication/pubtator/table', async () => {
        // Delay so the abort lands before the response resolves.
        await new Promise((resolve) => setTimeout(resolve, 50));
        return pubtatorRows();
      })
    );

    const pubs = usePubtatorGenePublications({ makeToast });
    const pending = pubs.fetchPublications('GRIN2B', ['1', '2']);
    // resetCache aborts the in-flight controller.
    pubs.resetCache();
    await pending;

    expect(makeToast).not.toHaveBeenCalled();
    expect(pubs.isCached('GRIN2B')).toBe(false);
    expect(pubs.isLoading('GRIN2B')).toBe(false);
  });

  it('does nothing for an empty PMID list', async () => {
    let calls = 0;
    server.use(
      http.get('*/api/publication/pubtator/table', () => {
        calls += 1;
        return pubtatorRows();
      })
    );

    const pubs = usePubtatorGenePublications({ makeToast });
    await pubs.fetchPublications('EMPTY', []);
    expect(calls).toBe(0);
    expect(pubs.isCached('EMPTY')).toBe(false);
  });
});
