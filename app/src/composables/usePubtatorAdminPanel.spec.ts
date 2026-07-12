import { computed, ref } from 'vue';
import { beforeEach, describe, expect, it, vi } from 'vitest';

const { getCacheStatusMock } = vi.hoisted(() => ({ getCacheStatusMock: vi.fn() }));

vi.mock('@/composables/usePubtatorAdmin', () => ({
  usePubtatorAdmin: () => ({
    error: ref(null),
    lastStatus: ref(null),
    isCheckingStatus: ref(false),
    isClearing: ref(false),
    isBackfilling: ref(false),
    getCacheStatus: getCacheStatusMock,
    submitFetchJob: vi.fn(),
    clearCache: vi.fn(),
    backfillGeneSymbols: vi.fn(),
    resetJob: vi.fn(),
    jobId: ref(null),
    jobStatus: ref('idle'),
    jobStep: ref(''),
    jobProgress: ref({ current: 0, total: 0 }),
    jobError: ref(null),
    jobElapsedSeconds: ref(0),
    hasRealProgress: computed(() => false),
    progressPercent: computed(() => null),
    elapsedTimeDisplay: computed(() => ''),
    progressVariant: computed(() => 'primary'),
    statusBadgeClass: computed(() => ''),
    isJobLoading: computed(() => false),
    isPolling: computed(() => false),
    stopPolling: vi.fn(),
  }),
}));

import { usePubtatorAdminPanel } from './usePubtatorAdminPanel';

function deferred<T>() {
  let resolve!: (value: T) => void;
  let reject!: (reason: unknown) => void;
  const promise = new Promise<T>((done, fail) => {
    resolve = done;
    reject = fail;
  });
  return { promise, resolve, reject };
}

describe('usePubtatorAdminPanel request ownership', () => {
  beforeEach(() => {
    getCacheStatusMock.mockReset();
  });

  it('does not show stale A failure feedback after check B begins', async () => {
    const a = deferred<unknown>();
    const b = deferred<unknown>();
    getCacheStatusMock.mockReturnValueOnce(a.promise).mockReturnValueOnce(b.promise);
    const panel = usePubtatorAdminPanel();

    panel.query.value = 'A';
    const checkA = panel.checkStatus();
    panel.query.value = 'B';
    const checkB = panel.checkStatus();
    a.reject(new Error('stale failure'));
    await checkA;

    expect(panel.feedbackMessage.value).toBe('');
    b.resolve({});
    await checkB;
  });
});
