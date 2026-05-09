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
});
