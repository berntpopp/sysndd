import { beforeEach, describe, expect, it, vi } from 'vitest';
import { createLogTableRequestCache, logRequestKey } from './logTableRequests';

describe('logTableRequests', () => {
  beforeEach(() => {
    vi.useRealTimers();
  });

  it('builds a stable request key from table params', () => {
    expect(
      logRequestKey({
        sort: '-timestamp',
        filter: 'status==500',
        page_after: 10,
        page_size: 25,
      })
    ).toBe('sort=-timestamp&filter=status%3D%3D500&page_after=10&page_size=25');
  });

  it('encodes param values so filters cannot collide with pagination fields', () => {
    const keyWithEmbeddedDelimiter = logRequestKey({
      sort: '-id',
      filter: 'path contains &page_after=25',
      page_after: 0,
      page_size: 10,
    });
    const keyWithDifferentPage = logRequestKey({
      sort: '-id',
      filter: 'path contains ',
      page_after: 25,
      page_size: 10,
    });

    expect(keyWithEmbeddedDelimiter).not.toBe(keyWithDifferentPage);
    expect(keyWithEmbeddedDelimiter).toContain('filter=path+contains+%26page_after%3D25');
  });

  it('reuses a fresh cached response for duplicate requests', async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-05-20T00:00:00Z'));

    const cache = createLogTableRequestCache();
    const fetcher = vi.fn().mockResolvedValue({ data: [], meta: [{ totalItems: 0 }] });

    const first = await cache.load(
      { sort: '-id', filter: '', page_after: 0, page_size: 10 },
      fetcher
    );
    const second = await cache.load(
      { sort: '-id', filter: '', page_after: 0, page_size: 10 },
      fetcher
    );

    expect(first.fromCache).toBe(false);
    expect(second.fromCache).toBe(true);
    expect(first.response).toBe(second.response);
    expect(fetcher).toHaveBeenCalledTimes(1);
  });

  it('shares an in-flight duplicate request without calling the fetcher twice', async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-05-20T00:00:00Z'));

    const cache = createLogTableRequestCache();
    let resolveResponse: (value: { data: unknown[]; meta: Array<{ totalItems: number }> }) => void;
    const responsePromise = new Promise<{ data: unknown[]; meta: Array<{ totalItems: number }> }>(
      (resolve) => {
        resolveResponse = resolve;
      }
    );
    const fetcher = vi.fn().mockReturnValue(responsePromise);

    const firstPromise = cache.load({ sort: '-id', filter: '', page_after: 0, page_size: 10 }, fetcher);
    const secondPromise = cache.load(
      { sort: '-id', filter: '', page_after: 0, page_size: 10 },
      fetcher
    );

    resolveResponse!({ data: [{ id: 1 }], meta: [{ totalItems: 1 }] });
    const [first, second] = await Promise.all([firstPromise, secondPromise]);

    expect(first.fromCache).toBe(false);
    expect(second.fromCache).toBe(true);
    expect(second.response).toBe(first.response);
    expect(fetcher).toHaveBeenCalledTimes(1);
  });

  it('does not reuse stale cached responses after the duplicate window', async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-05-20T00:00:00Z'));

    const cache = createLogTableRequestCache();
    const fetcher = vi
      .fn()
      .mockResolvedValueOnce({ data: [{ id: 1 }], meta: [{ totalItems: 1 }] })
      .mockResolvedValueOnce({ data: [{ id: 2 }], meta: [{ totalItems: 1 }] });

    await cache.load({ sort: '-id', filter: '', page_after: 0, page_size: 10 }, fetcher);
    vi.setSystemTime(new Date('2026-05-20T00:00:01Z'));
    const result = await cache.load(
      { sort: '-id', filter: '', page_after: 0, page_size: 10 },
      fetcher
    );

    expect(result.response.data).toEqual([{ id: 2 }]);
    expect(result.fromCache).toBe(false);
    expect(fetcher).toHaveBeenCalledTimes(2);
  });

  it('does not reuse a previous successful response after a different request fails', async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-05-20T00:00:00Z'));

    const cache = createLogTableRequestCache();
    const fetcher = vi
      .fn()
      .mockResolvedValueOnce({ data: [{ id: 1 }], meta: [{ totalItems: 1 }] })
      .mockRejectedValueOnce(new Error('invalid filter'))
      .mockResolvedValueOnce({ data: [{ id: 2 }], meta: [{ totalItems: 1 }] });

    await cache.load({ sort: '-id', filter: 'status==200', page_after: 0, page_size: 10 }, fetcher);
    await expect(
      cache.load({ sort: '-id', filter: 'status==500', page_after: 0, page_size: 10 }, fetcher)
    ).rejects.toThrow('invalid filter');

    const retry = await cache.load(
      { sort: '-id', filter: 'status==500', page_after: 0, page_size: 10 },
      fetcher
    );

    expect(retry.response.data).toEqual([{ id: 2 }]);
    expect(retry.fromCache).toBe(false);
    expect(fetcher).toHaveBeenCalledTimes(3);
  });
});
