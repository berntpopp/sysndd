import { computed, ref } from 'vue';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import type { PubtatorCacheStatus } from '@/api/publication';

const { getPubtatorCacheStatusMock } = vi.hoisted(() => ({
  getPubtatorCacheStatusMock: vi.fn(),
}));

vi.mock('@/api/publication', async (importOriginal) => {
  const actual = await importOriginal<typeof import('@/api/publication')>();
  return { ...actual, getPubtatorCacheStatus: getPubtatorCacheStatusMock };
});

vi.mock('@/composables/useAsyncJob', () => ({
  useAsyncJob: () => ({
    jobId: ref(null),
    status: ref('idle'),
    step: ref(''),
    progress: ref({ current: 0, total: 0 }),
    error: ref(null),
    elapsedSeconds: ref(0),
    hasRealProgress: computed(() => false),
    progressPercent: computed(() => null),
    elapsedTimeDisplay: computed(() => ''),
    progressVariant: computed(() => 'primary'),
    statusBadgeClass: computed(() => ''),
    isLoading: computed(() => false),
    isPolling: computed(() => false),
    startJob: vi.fn(),
    stopPolling: vi.fn(),
    reset: vi.fn(),
  }),
}));

import { usePubtatorAdmin } from './usePubtatorAdmin';

function deferred<T>() {
  let resolve!: (value: T) => void;
  let reject!: (reason: unknown) => void;
  const promise = new Promise<T>((done, fail) => {
    resolve = done;
    reject = fail;
  });
  return { promise, resolve, reject };
}

function status(query: string): PubtatorCacheStatus {
  return {
    query,
    cached: true,
    pages_cached: 1,
    total_pages_available: 1,
    total_results_available: 1,
    cache_date: null,
    estimated_fetch_time_minutes: 0,
    message: 'cached',
  };
}

describe('usePubtatorAdmin cache-status ownership', () => {
  beforeEach(() => {
    getPubtatorCacheStatusMock.mockReset();
  });

  it('keeps B status state current when stale A rejects out of order', async () => {
    const a = deferred<PubtatorCacheStatus>();
    const b = deferred<PubtatorCacheStatus>();
    getPubtatorCacheStatusMock.mockReturnValueOnce(a.promise).mockReturnValueOnce(b.promise);
    const admin = usePubtatorAdmin();

    const requestA = admin.getCacheStatus('A');
    const requestB = admin.getCacheStatus('B');
    a.reject(new Error('stale failure'));
    await expect(requestA).rejects.toThrow('stale failure');
    expect(admin.isCheckingStatus.value).toBe(true);
    expect(admin.error.value).toBeNull();

    b.resolve(status('B'));
    await requestB;
    expect(admin.isCheckingStatus.value).toBe(false);
    expect(admin.lastStatus.value?.query).toBe('B');
  });
});
