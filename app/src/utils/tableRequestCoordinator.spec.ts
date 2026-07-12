import { describe, expect, it, vi } from 'vitest';
import { createTableRequestCoordinator } from './tableRequestCoordinator';

describe('createTableRequestCoordinator', () => {
  it('awaits an in-flight request before using the recent cache shortcut', async () => {
    const coordinator = createTableRequestCoordinator<string>();
    let resolveRequest: (value: string) => void = () => {};
    const fetcher = vi.fn(
      () =>
        new Promise<string>((resolve) => {
          resolveRequest = resolve;
        })
    );
    const firstApply = vi.fn();
    const secondApply = vi.fn();

    const first = coordinator.request({
      params: 'page=1',
      fetcher,
      apply: firstApply,
      onError: vi.fn(),
      isCurrent: () => true,
      now: () => 100,
    });
    const second = coordinator.request({
      params: 'page=1',
      fetcher,
      apply: secondApply,
      onError: vi.fn(),
      isCurrent: () => true,
      now: () => 101,
    });

    resolveRequest('response');

    await expect(first).resolves.toEqual({ handled: true, source: 'network' });
    await expect(second).resolves.toEqual({ handled: true, source: 'shared' });
    expect(fetcher).toHaveBeenCalledTimes(1);
    expect(firstApply).toHaveBeenCalledWith('response', 'network');
    expect(secondApply).toHaveBeenCalledWith('response', 'shared');
  });

  it('does not apply a shared response when the waiting instance changed params', async () => {
    const coordinator = createTableRequestCoordinator<string>();
    let currentParams = 'page=1';
    let resolveRequest: (value: string) => void = () => {};
    const fetcher = vi.fn(
      () =>
        new Promise<string>((resolve) => {
          resolveRequest = resolve;
        })
    );
    const staleApply = vi.fn();

    const first = coordinator.request({
      params: 'page=1',
      fetcher,
      apply: vi.fn(),
      onError: vi.fn(),
      isCurrent: () => true,
    });
    const staleWaiter = coordinator.request({
      params: 'page=1',
      fetcher,
      apply: staleApply,
      onError: vi.fn(),
      isCurrent: (params) => currentParams === params,
    });

    currentParams = 'page=2';
    resolveRequest('response');

    await first;
    await expect(staleWaiter).resolves.toEqual({ handled: false, source: 'shared' });
    expect(staleApply).not.toHaveBeenCalled();
  });

  it('only uses cached responses that match the current params', async () => {
    const coordinator = createTableRequestCoordinator<string>();
    const firstApply = vi.fn();
    const secondApply = vi.fn();

    await coordinator.request({
      params: 'page=1',
      fetcher: () => Promise.resolve('first'),
      apply: firstApply,
      onError: vi.fn(),
      isCurrent: () => true,
      now: () => 100,
    });
    const result = await coordinator.request({
      params: 'page=2',
      fetcher: () => Promise.resolve('second'),
      apply: secondApply,
      onError: vi.fn(),
      isCurrent: () => true,
      now: () => 101,
    });

    expect(result).toEqual({ handled: true, source: 'network' });
    expect(secondApply).toHaveBeenCalledWith('second', 'network');
  });

  // #535 P1-7: generation-based request ownership (A-B-A + out-of-order).
  function deferred<T>() {
    let resolve!: (v: T) => void;
    let reject!: (e: unknown) => void;
    const promise = new Promise<T>((res, rej) => {
      resolve = res;
      reject = rej;
    });
    return { promise, resolve, reject };
  }

  it('A-B-A: the original A response does not apply after A2 supersedes it', async () => {
    const coord = createTableRequestCoordinator<string>();
    const applied: string[] = [];
    let current = 'A';
    const dA = deferred<string>();
    const dB = deferred<string>();
    const dA2 = deferred<string>();

    const rA = coord.request({ params: 'A', fetcher: () => dA.promise, apply: (d) => applied.push(`A:${d}`), onError: () => {}, isCurrent: (p) => p === current });
    current = 'B';
    const rB = coord.request({ params: 'B', fetcher: () => dB.promise, apply: (d) => applied.push(`B:${d}`), onError: () => {}, isCurrent: (p) => p === current });
    current = 'A';
    const rA2 = coord.request({ params: 'A', fetcher: () => dA2.promise, apply: (d) => applied.push(`A2:${d}`), onError: () => {}, isCurrent: (p) => p === current });

    dA.resolve('stale');
    await rA;
    expect(applied).not.toContain('A:stale');

    dB.resolve('bdata');
    await rB;
    expect(applied).not.toContain('B:bdata');

    dA2.resolve('fresh');
    await rA2;
    expect(applied).toContain('A2:fresh');
  });

  it('slot integrity: original A does not corrupt A2 in-flight slot (a 4th A shares A2)', async () => {
    const coord = createTableRequestCoordinator<string>();
    const fetchCalls: string[] = [];
    let current = 'A';
    const dA = deferred<string>();
    const dB = deferred<string>();
    const dA2 = deferred<string>();

    const rA = coord.request({ params: 'A', fetcher: () => { fetchCalls.push('A'); return dA.promise; }, apply: () => {}, onError: () => {}, isCurrent: (p) => p === current });
    current = 'B';
    const rB = coord.request({ params: 'B', fetcher: () => { fetchCalls.push('B'); return dB.promise; }, apply: () => {}, onError: () => {}, isCurrent: (p) => p === current });
    current = 'A';
    const rA2 = coord.request({ params: 'A', fetcher: () => { fetchCalls.push('A2'); return dA2.promise; }, apply: () => {}, onError: () => {}, isCurrent: (p) => p === current });

    // Original A resolves — must NOT clear A2's in-flight slot.
    dA.resolve('stale');
    await rA;

    // A 4th request for A must SHARE A2's in-flight promise (no new fetch). Use a
    // settled sentinel fetcher so a regression (new fetch) fails fast, not hangs.
    const applied4: string[] = [];
    const r4 = coord.request({ params: 'A', fetcher: () => { fetchCalls.push('A4'); return Promise.resolve('A4-unexpected'); }, apply: (d) => applied4.push(d), onError: () => {}, isCurrent: (p) => p === current });

    dB.resolve('bstale'); // superseded B; resolve so its awaited request settles
    dA2.resolve('fresh');
    const [r4result] = await Promise.all([r4, rA2, rB]);

    expect(fetchCalls).toEqual(['A', 'B', 'A2']); // no 'A4' — the 4th shared A2's slot
    expect(r4result.source).toBe('shared');
    expect(applied4).toEqual(['fresh']);

    // Recent-cache branch returns A2's data after it settled.
    const r5 = await coord.request({ params: 'A', fetcher: () => Promise.resolve('unused'), apply: () => {}, onError: () => {}, isCurrent: () => true, now: () => 1 });
    expect(r5.source).toBe('cache');
  });

  it('error out-of-order: a superseded rejected request does not call onError', async () => {
    const coord = createTableRequestCoordinator<string>();
    const errors: string[] = [];
    let current = 'X';
    const d1 = deferred<string>();
    const d2 = deferred<string>();

    const r1 = coord.request({ params: 'X', fetcher: () => d1.promise, apply: () => {}, onError: () => errors.push('X'), isCurrent: (p) => p === current });
    current = 'Y';
    const r2 = coord.request({ params: 'Y', fetcher: () => d2.promise, apply: () => {}, onError: () => errors.push('Y'), isCurrent: (p) => p === current });

    d2.resolve('ok');
    await r2;
    d1.reject(new Error('stale fail'));
    await r1;
    expect(errors).toEqual([]); // superseded X's rejection must not surface
  });
});
