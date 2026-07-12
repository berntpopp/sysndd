import { beforeEach, describe, expect, it, vi } from 'vitest';

const { getEntitiesOverTimeMock } = vi.hoisted(() => ({ getEntitiesOverTimeMock: vi.fn() }));

vi.mock('@/api/statistics', async (importOriginal) => {
  const actual = await importOriginal<typeof import('@/api/statistics')>();
  return { ...actual, getEntitiesOverTime: getEntitiesOverTimeMock };
});

import { useAdminTrendData } from '../useAdminTrendData';

function deferred<T>() {
  let resolve!: (value: T) => void;
  let reject!: (reason: unknown) => void;
  const promise = new Promise<T>((done, fail) => {
    resolve = done;
    reject = fail;
  });
  return { promise, resolve, reject };
}

describe('useAdminTrendData request ownership', () => {
  beforeEach(() => {
    getEntitiesOverTimeMock.mockReset();
  });

  it('keeps B loading when stale A rejects out of order', async () => {
    const a = deferred<{ data: unknown[] }>();
    const b = deferred<{ data: unknown[] }>();
    getEntitiesOverTimeMock.mockReturnValueOnce(a.promise).mockReturnValueOnce(b.promise);
    const makeToast = vi.fn();
    const consoleError = vi.spyOn(console, 'error').mockImplementation(() => {});
    const trends = useAdminTrendData(makeToast);

    const requestA = trends.fetchTrendData();
    const requestB = trends.fetchTrendData();
    a.reject(new Error('stale failure'));
    await requestA;
    expect(trends.loading.value).toBe(true);
    expect(makeToast).not.toHaveBeenCalled();

    b.resolve({ data: [] });
    await requestB;
    expect(trends.loading.value).toBe(false);
    consoleError.mockRestore();
  });
});
