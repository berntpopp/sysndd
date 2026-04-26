import { setActivePinia, createPinia } from 'pinia';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { defineComponent, h, ref, nextTick } from 'vue';
import { mount } from '@vue/test-utils';
import { useResource } from '../useResource';
import { useCacheStore } from '@/stores/cacheStore';

describe('useResource — happy path', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  afterEach(() => {
    vi.useRealTimers();
  });

  it('fetches on mount when cache is empty and resolves data', async () => {
    const fetcher = vi.fn(async (_signal: AbortSignal) => ({ ok: true }));
    const Comp = defineComponent({
      setup() {
        const r = useResource('k1', fetcher);
        return { r };
      },
      render() {
        return h('div');
      },
    });
    const wrapper = mount(Comp);
    await nextTick();
    await Promise.resolve(); // microtask: fetcher resolves
    await Promise.resolve();
    expect(fetcher).toHaveBeenCalledOnce();
    expect((wrapper.vm as any).r.data.value).toEqual({ ok: true });
    expect((wrapper.vm as any).r.error.value).toBeNull();
    expect((wrapper.vm as any).r.loading.value).toBe(false);
    expect((wrapper.vm as any).r.isStale.value).toBe(false);
  });

  it('serves cached value without re-fetching when fresh', async () => {
    const cache = useCacheStore();
    cache.set('k2', { cached: true }, 60_000);
    const fetcher = vi.fn();
    const Comp = defineComponent({
      setup() {
        const r = useResource('k2', fetcher as any, { ttlMs: 60_000 });
        return { r };
      },
      render() {
        return h('div');
      },
    });
    const wrapper = mount(Comp);
    await nextTick();
    expect(fetcher).not.toHaveBeenCalled();
    expect((wrapper.vm as any).r.data.value).toEqual({ cached: true });
    expect((wrapper.vm as any).r.isStale.value).toBe(false);
  });

  it('refresh() forces a re-fetch ignoring TTL', async () => {
    const cache = useCacheStore();
    cache.set('k3', 'old', 60_000);
    const fetcher = vi.fn(async () => 'new');
    const Comp = defineComponent({
      setup() {
        const r = useResource('k3', fetcher, { ttlMs: 60_000 });
        return { r };
      },
      render() {
        return h('div');
      },
    });
    const wrapper = mount(Comp);
    await nextTick();
    expect(fetcher).not.toHaveBeenCalled(); // fresh
    await (wrapper.vm as any).r.refresh();
    expect(fetcher).toHaveBeenCalledOnce();
    expect((wrapper.vm as any).r.data.value).toBe('new');
  });

  it('null key skips the fetch and exposes null data', async () => {
    const fetcher = vi.fn();
    const Comp = defineComponent({
      setup() {
        const r = useResource(null, fetcher as any);
        return { r };
      },
      render() {
        return h('div');
      },
    });
    const wrapper = mount(Comp);
    await nextTick();
    expect(fetcher).not.toHaveBeenCalled();
    expect((wrapper.vm as any).r.data.value).toBeNull();
    expect((wrapper.vm as any).r.loading.value).toBe(false);
  });

  it('captures fetcher errors into error ref', async () => {
    const err = new Error('boom');
    const fetcher = vi.fn(async () => {
      throw err;
    });
    const Comp = defineComponent({
      setup() {
        const r = useResource('k4', fetcher);
        return { r };
      },
      render() {
        return h('div');
      },
    });
    const wrapper = mount(Comp);
    await nextTick();
    await Promise.resolve();
    await Promise.resolve();
    expect((wrapper.vm as any).r.error.value).toBe(err);
    expect((wrapper.vm as any).r.data.value).toBeNull();
    expect((wrapper.vm as any).r.loading.value).toBe(false);
  });
});

describe('useResource — SWR / dedupe / abort', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  it('serves stale value immediately and revalidates in background', async () => {
    const cache = useCacheStore();
    // Place a stale entry: fetchedAt very far in the past.
    cache.set('k-swr', 'stale', 1); // ttl 1ms => instantly stale
    await new Promise((r) => setTimeout(r, 5));
    let resolved!: () => void;
    const fetcher = vi.fn(
      () =>
        new Promise<string>((res) => {
          resolved = () => res('fresh');
        }),
    );
    const Comp = defineComponent({
      setup() {
        const r = useResource('k-swr', fetcher, { ttlMs: 1 });
        return { r };
      },
      render() {
        return h('div');
      },
    });
    const wrapper = mount(Comp);
    await nextTick();
    // First paint: stale value visible, isStale flag true, no loading flicker.
    expect((wrapper.vm as any).r.data.value).toBe('stale');
    expect((wrapper.vm as any).r.isStale.value).toBe(true);
    expect((wrapper.vm as any).r.loading.value).toBe(false);
    // Now resolve the background fetch.
    resolved();
    await Promise.resolve();
    await Promise.resolve();
    expect((wrapper.vm as any).r.data.value).toBe('fresh');
    expect((wrapper.vm as any).r.isStale.value).toBe(false);
  });

  it('dedupes concurrent fetches for the same key', async () => {
    let calls = 0;
    let resolveFn!: (v: number) => void;
    const fetcher = vi.fn(() => {
      calls += 1;
      return new Promise<number>((res) => {
        resolveFn = res;
      });
    });
    // Two consumers mounting on the same tick with the same key.
    const Comp = defineComponent({
      setup() {
        const a = useResource('k-dedupe', fetcher);
        const b = useResource('k-dedupe', fetcher);
        return { a, b };
      },
      render() {
        return h('div');
      },
    });
    const wrapper = mount(Comp);
    await nextTick();
    expect(calls).toBe(1); // only one underlying fetch
    resolveFn(7);
    await Promise.resolve();
    await Promise.resolve();
    expect((wrapper.vm as any).a.data.value).toBe(7);
    expect((wrapper.vm as any).b.data.value).toBe(7);
  });

  it('aborts the in-flight fetch when the last subscriber unmounts', async () => {
    let aborted = false;
    let neverResolve!: () => void;
    const fetcher = vi.fn((signal: AbortSignal) => {
      signal.addEventListener('abort', () => {
        aborted = true;
        neverResolve();
      });
      return new Promise<number>((res) => {
        neverResolve = () => res(-1);
      });
    });
    const Comp = defineComponent({
      setup() {
        const r = useResource('k-abort', fetcher);
        return { r };
      },
      render() {
        return h('div');
      },
    });
    const wrapper = mount(Comp);
    await nextTick();
    wrapper.unmount();
    await Promise.resolve();
    expect(aborted).toBe(true);
  });

  it('does not abort while another subscriber still holds the key', async () => {
    let aborted = false;
    let resolveFn!: (v: number) => void;
    const fetcher = vi.fn((signal: AbortSignal) => {
      signal.addEventListener('abort', () => {
        aborted = true;
      });
      return new Promise<number>((res) => {
        resolveFn = res;
      });
    });
    const Inner = defineComponent({
      setup() {
        useResource('k-shared', fetcher);
        return () => h('div');
      },
    });
    const Outer = defineComponent({
      setup() {
        const showInner = ref(true);
        useResource('k-shared', fetcher);
        return { showInner };
      },
      render() {
        return h('div', this.showInner ? [h(Inner)] : []);
      },
    });
    const wrapper = mount(Outer);
    await nextTick();
    // Unmount the Inner subscriber; Outer still holds the key.
    (wrapper.vm as any).showInner = false;
    await nextTick();
    expect(aborted).toBe(false);
    resolveFn(99);
    await Promise.resolve();
  });

  it('cancelled consumer (key change) does not write back to its data ref', async () => {
    // Each fetcher call gets its own resolver so resolving 'first' does not
    // also resolve the second invocation.
    const resolvers: Array<(v: number) => void> = [];
    const fetcher = vi.fn(
      () =>
        new Promise<number>((res) => {
          resolvers.push(res);
        }),
    );
    const Comp = defineComponent({
      setup() {
        const key = ref<string | null>('first');
        const r = useResource(key, fetcher);
        return { key, r };
      },
      render() {
        return h('div');
      },
    });
    const wrapper = mount(Comp);
    await nextTick();
    // Switch key before the first fetch resolves.
    (wrapper.vm as any).key = 'second';
    await nextTick();
    // Now resolve the ORIGINAL ('first') promise — index 0.
    resolvers[0](123);
    await Promise.resolve();
    await Promise.resolve();
    // The consumer's data must NOT be 123 — that result belonged to the old key.
    expect((wrapper.vm as any).r.data.value).not.toBe(123);
    // But the cache still has it under 'first', so a remount would see it.
    const cache = useCacheStore();
    expect(cache.peek('first')?.value).toBe(123);
  });
});
