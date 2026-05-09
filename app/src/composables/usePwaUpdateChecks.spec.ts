import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import {
  DEFAULT_PWA_UPDATE_CHECK_INTERVAL_MS,
  PWA_UPDATE_CHECK_THROTTLE_MS,
  usePwaUpdateChecks,
} from './usePwaUpdateChecks';

async function flushPromises() {
  await Promise.resolve();
  await Promise.resolve();
}

function makeRegistration() {
  return {
    installing: null,
    update: vi.fn().mockResolvedValue(undefined),
  } as unknown as ServiceWorkerRegistration & {
    update: ReturnType<typeof vi.fn>;
  };
}

describe('usePwaUpdateChecks', () => {
  const fetchMock = vi.fn();

  beforeEach(() => {
    vi.useFakeTimers();
    fetchMock.mockResolvedValue({ status: 200 });
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('checks for a service worker update immediately after registration', async () => {
    const registration = makeRegistration();
    const checks = usePwaUpdateChecks({ fetchImpl: fetchMock });

    checks.registerServiceWorker('/sw.js', registration);
    await flushPromises();

    expect(fetchMock).toHaveBeenCalledWith('/sw.js', {
      cache: 'no-store',
      headers: { 'cache-control': 'no-cache' },
    });
    expect(registration.update).toHaveBeenCalledTimes(1);

    checks.stop();
  });

  it('uses a dense periodic check instead of waiting an hour', async () => {
    const registration = makeRegistration();
    const checks = usePwaUpdateChecks({ fetchImpl: fetchMock });

    checks.registerServiceWorker('/sw.js', registration);
    await flushPromises();

    fetchMock.mockClear();
    registration.update.mockClear();

    await vi.advanceTimersByTimeAsync(DEFAULT_PWA_UPDATE_CHECK_INTERVAL_MS);

    expect(DEFAULT_PWA_UPDATE_CHECK_INTERVAL_MS).toBeLessThan(60 * 60 * 1000);
    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(registration.update).toHaveBeenCalledTimes(1);

    checks.stop();
  });

  it('checks when the app becomes visible, focused, or online without duplicate bursts', async () => {
    const registration = makeRegistration();
    const checks = usePwaUpdateChecks({ fetchImpl: fetchMock });

    checks.registerServiceWorker('/sw.js', registration);
    await flushPromises();

    fetchMock.mockClear();
    registration.update.mockClear();

    document.dispatchEvent(new Event('visibilitychange'));
    window.dispatchEvent(new Event('focus'));
    window.dispatchEvent(new Event('online'));
    await flushPromises();

    expect(fetchMock).toHaveBeenCalledTimes(1);

    await vi.advanceTimersByTimeAsync(PWA_UPDATE_CHECK_THROTTLE_MS);
    window.dispatchEvent(new Event('focus'));
    await flushPromises();

    expect(fetchMock).toHaveBeenCalledTimes(2);
    expect(registration.update).toHaveBeenCalledTimes(2);

    checks.stop();
  });

  it('skips checks while offline or while a worker is already installing', async () => {
    const registration = makeRegistration();
    Object.defineProperty(navigator, 'onLine', {
      configurable: true,
      value: false,
    });
    const checks = usePwaUpdateChecks({ fetchImpl: fetchMock });

    checks.registerServiceWorker('/sw.js', registration);
    await flushPromises();

    expect(fetchMock).not.toHaveBeenCalled();
    expect(registration.update).not.toHaveBeenCalled();

    Object.defineProperty(navigator, 'onLine', {
      configurable: true,
      value: true,
    });
    Object.defineProperty(registration, 'installing', {
      configurable: true,
      value: {} as ServiceWorker,
    });

    await vi.advanceTimersByTimeAsync(DEFAULT_PWA_UPDATE_CHECK_INTERVAL_MS);

    expect(fetchMock).not.toHaveBeenCalled();
    expect(registration.update).not.toHaveBeenCalled();

    checks.stop();
  });
});
