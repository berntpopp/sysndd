import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { PubtatorTableResponse } from '@/api/publication';

const { listPubtatorTableMock } = vi.hoisted(() => ({ listPubtatorTableMock: vi.fn() }));

vi.mock('@/api/publication', async (importOriginal) => {
  const actual = await importOriginal<typeof import('@/api/publication')>();
  return { ...actual, listPubtatorTable: listPubtatorTableMock };
});

import { usePubtatorGenePublications } from './usePubtatorGenePublications';

function deferred<T>() {
  let resolve!: (value: T) => void;
  const promise = new Promise<T>((done) => {
    resolve = done;
  });
  return { promise, resolve };
}

function response(pmid: number): PubtatorTableResponse {
  return { data: [{ pmid }], meta: [], links: [] };
}

describe('usePubtatorGenePublications request ownership', () => {
  beforeEach(() => {
    listPubtatorTableMock.mockReset();
  });

  it('cancelAll then a same-gene refetch keeps the new slot owned after A settles', async () => {
    const a = deferred<PubtatorTableResponse>();
    const b = deferred<PubtatorTableResponse>();
    listPubtatorTableMock.mockReturnValueOnce(a.promise).mockReturnValueOnce(b.promise);
    const publications = usePubtatorGenePublications({ makeToast: vi.fn() });

    const requestA = publications.fetchPublications('MECP2', ['1']);
    publications.cancelAll();
    const requestB = publications.fetchPublications('MECP2', ['2']);

    a.resolve(response(1));
    await requestA;
    expect(publications.isLoading('MECP2')).toBe(true);
    expect(publications.isCached('MECP2')).toBe(false);

    b.resolve(response(2));
    await requestB;
    expect(publications.isLoading('MECP2')).toBe(false);
    expect(publications.getPublications('MECP2')).toEqual([{ pmid: 2 }]);
  });

  it('suppresses a typed-client cancellation without importing Axios', async () => {
    const makeToast = vi.fn();
    listPubtatorTableMock.mockRejectedValueOnce({ name: 'CanceledError', code: 'ERR_CANCELED' });
    const publications = usePubtatorGenePublications({ makeToast });

    await publications.fetchPublications('MECP2', ['1']);

    expect(makeToast).not.toHaveBeenCalled();
    expect(publications.isLoading('MECP2')).toBe(false);
  });
});
