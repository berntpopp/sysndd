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
        })
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
        })
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

describe('useResource — Copilot review fixes', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  it('serves cached null as a hit (does not re-fetch on remount)', async () => {
    // A fetcher that maps a 404 to null (the canonical pattern in our hooks)
    // must populate the cache with `null`, not look like a cache miss. Before
    // the fix, readFromCache returned `value: null` for both "no entry" and
    // "cached null", so every remount re-fetched.
    const fetcher = vi.fn(async (_s: AbortSignal) => null as { id: number } | null);
    const Comp = defineComponent({
      setup() {
        const r = useResource<{ id: number } | null>('null-key', fetcher);
        return { r };
      },
      render: () => h('div'),
    });
    const w1 = mount(Comp);
    await nextTick();
    await Promise.resolve();
    await nextTick();
    expect(fetcher).toHaveBeenCalledTimes(1);
    expect((w1.vm as any).r.data.value).toBe(null);
    w1.unmount();

    // Remount — cache holds null, ttlMs has not expired, so no new fetch.
    const w2 = mount(Comp);
    await nextTick();
    await Promise.resolve();
    expect(fetcher).toHaveBeenCalledTimes(1);
    expect((w2.vm as any).r.data.value).toBe(null);
    w2.unmount();
  });

  it('refresh() preserves the cache entry so other subscribers keep their refCount', async () => {
    let n = 0;
    const fetcher = vi.fn(async (_s: AbortSignal) => ({ n: ++n }));
    const Comp = defineComponent({
      setup() {
        const r = useResource('shared', fetcher, { ttlMs: 60_000 });
        return { r };
      },
      render: () => h('div'),
    });
    // Two subscribers of the same key.
    const a = mount(Comp);
    await nextTick();
    await Promise.resolve();
    await nextTick();
    const b = mount(Comp);
    await nextTick();
    await Promise.resolve();

    const cache = useCacheStore();
    const refBefore = cache.peek('shared')?.refCount ?? 0;
    expect(refBefore).toBeGreaterThanOrEqual(2);

    // Refresh from one consumer — the other must keep its subscription.
    await (a.vm as any).r.refresh();
    await Promise.resolve();
    await nextTick();

    const entry = cache.peek('shared');
    expect(entry).not.toBeNull();
    expect(entry?.refCount).toBe(refBefore);
    // And the value was actually re-fetched (n bumped).
    expect((a.vm as any).r.data.value).toEqual({ n: 2 });

    a.unmount();
    b.unmount();
  });
});

describe('useResource — S5b request ownership (cache-slot epoch + transport-slot)', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  it('two concurrent refresh() for the same key: the stale (older) resolution does not win', async () => {
    // activeToken does not change between two refresh() calls for the same key; a
    // stale fetch is distinguished by the shared cache-slot epoch, and only the
    // transport-slot owner may write the shared cache.
    const resolvers: Array<(v: string) => void> = [];
    const fetcher = vi.fn(() => new Promise<string>((res) => { resolvers.push(res); }));
    const Comp = defineComponent({
      setup() {
        const r = useResource<string>('k-race', fetcher, { ttlMs: 60_000 });
        return { r };
      },
      render: () => h('div'),
    });
    const w = mount(Comp);
    await nextTick();
    resolvers[0]('v0'); // settle the initial mount fetch
    await Promise.resolve();
    await nextTick();
    expect((w.vm as any).r.data.value).toBe('v0');

    const p1 = (w.vm as any).r.refresh(); // fetch #1 (older)
    const p2 = (w.vm as any).r.refresh(); // fetch #2 (latest)
    resolvers[2]('fresh');
    await p2;
    await Promise.resolve();
    resolvers[1]('stale'); // the older fetch resolves LAST
    await p1;
    await Promise.resolve();

    expect((w.vm as any).r.data.value).toBe('fresh');
    const cache = useCacheStore();
    expect(cache.peek('k-race')?.value).toBe('fresh'); // stale did NOT overwrite cache
    w.unmount();
  });

  it('a stale rejection while the newer fetch is still pending does not clear its slot/refs', async () => {
    const rs: Array<(v: string) => void> = [];
    const rj: Array<(e: unknown) => void> = [];
    const fetcher = vi.fn(
      () => new Promise<string>((res, rej) => { rs.push(res); rj.push(rej); })
    );
    const Comp = defineComponent({
      setup() {
        const r = useResource<string>('k-rej', fetcher, { ttlMs: 60_000 });
        return { r };
      },
      render: () => h('div'),
    });
    const w = mount(Comp);
    await nextTick();
    rs[0]('v0');
    await Promise.resolve();
    await nextTick();

    const p1 = (w.vm as any).r.refresh(); // #1 (older)
    const p2 = (w.vm as any).r.refresh(); // #2 (latest, STILL pending)
    const cache = useCacheStore();
    const pendingBefore = cache.peek('k-rej')?.pending;
    expect(pendingBefore).toBeTruthy();

    rj[1](new Error('stale-boom')); // reject #1 while #2 is still pending
    await p1.catch(() => {});
    await Promise.resolve();

    expect(cache.peek('k-rej')?.pending).toBe(pendingBefore); // #1 did not clear #2's slot
    expect((w.vm as any).r.error.value).toBeNull(); // #1 rejection not applied
    expect((w.vm as any).r.loading.value).toBe(true); // #2 still owns loading

    rs[2]('fresh2');
    await p2;
    await Promise.resolve();
    expect((w.vm as any).r.data.value).toBe('fresh2');
    expect((w.vm as any).r.loading.value).toBe(false);
    expect(cache.peek('k-rej')?.value).toBe('fresh2');
    w.unmount();
  });

  it('clears loading when switching from an in-flight key to a fresh cached key', async () => {
    const cache = useCacheStore();
    cache.set('kB', 'bval', 60_000); // B fresh in cache
    const fetcher = vi.fn((_s: AbortSignal) => new Promise<string>(() => {})); // A never resolves
    const Comp = defineComponent({
      setup() {
        const key = ref<string | null>('kA');
        const r = useResource<string>(key, fetcher, { ttlMs: 60_000 });
        return { key, r };
      },
      render: () => h('div'),
    });
    const w = mount(Comp);
    await nextTick();
    expect((w.vm as any).r.loading.value).toBe(true); // foreground A in flight
    (w.vm as any).key = 'kB';
    await nextTick();
    expect((w.vm as any).r.data.value).toBe('bval');
    expect((w.vm as any).r.loading.value).toBe(false); // activate(B) took ownership of loading
    w.unmount();
  });

  it('clears loading when switching from an in-flight key to a stale (SWR) cached key', async () => {
    const cache = useCacheStore();
    cache.set('kSwrB', 'staleB', 1); // instantly stale
    await new Promise((r) => setTimeout(r, 5));
    const fetcher = vi.fn((_s: AbortSignal) => new Promise<string>(() => {}));
    const Comp = defineComponent({
      setup() {
        const key = ref<string | null>('kA');
        const r = useResource<string>(key, fetcher, { ttlMs: 1 });
        return { key, r };
      },
      render: () => h('div'),
    });
    const w = mount(Comp);
    await nextTick();
    expect((w.vm as any).r.loading.value).toBe(true);
    (w.vm as any).key = 'kSwrB';
    await nextTick();
    expect((w.vm as any).r.data.value).toBe('staleB');
    expect((w.vm as any).r.isStale.value).toBe(true);
    expect((w.vm as any).r.loading.value).toBe(false); // stale shown, no loading flicker
    w.unmount();
  });

  it('abort() clears loading for an in-flight foreground fetch', async () => {
    const fetcher = vi.fn((_s: AbortSignal) => new Promise<string>(() => {}));
    const Comp = defineComponent({
      setup() {
        const r = useResource<string>('kAbort', fetcher);
        return { r };
      },
      render: () => h('div'),
    });
    const w = mount(Comp);
    await nextTick();
    expect((w.vm as any).r.loading.value).toBe(true);
    (w.vm as any).r.abort();
    expect((w.vm as any).r.loading.value).toBe(false);
    w.unmount();
  });

  it('a subscriber is not left stuck when another consumer starts a newer fetch', async () => {
    // Consumer-ref ownership is per-instance, not the shared slot epoch, so a
    // subscriber applies its subscribed value and clears loading even when another
    // consumer supersedes the shared slot (regression guard for the epoch-as-consumer
    // -token stuck-loading bug).
    const resolvers: Array<(v: string) => void> = [];
    const fetcher = vi.fn(() => new Promise<string>((res) => resolvers.push(res)));
    const Comp = defineComponent({
      setup() {
        const r = useResource<string>('shared-k', fetcher, { ttlMs: 60_000 });
        return { r };
      },
      render: () => h('div'),
    });
    const a = mount(Comp); // consumer A → fetch #0
    await nextTick();
    const b = mount(Comp); // consumer B subscribes to A's in-flight #0
    await nextTick();
    expect((b.vm as any).r.loading.value).toBe(true);

    const pA = (a.vm as any).r.refresh(); // fetch #1 supersedes the slot
    resolvers[0]('v0'); // B's subscribed pending resolves
    await Promise.resolve();
    await nextTick();
    expect((b.vm as any).r.data.value).toBe('v0'); // B applied its value…
    expect((b.vm as any).r.loading.value).toBe(false); // …and is NOT stuck loading

    resolvers[1]('v1');
    await pA;
    await Promise.resolve();
    expect((a.vm as any).r.data.value).toBe('v1');
    a.unmount();
    b.unmount();
  });

  it('an old fetch cannot overwrite a newer one after invalidate() recreates the slot', async () => {
    // Global monotonic epochs prevent the collision where invalidate() resets a
    // per-key epoch and a stale fetch then matches the recreated slot.
    const resolvers: Array<(v: string) => void> = [];
    const fetcher = vi.fn(() => new Promise<string>((res) => resolvers.push(res)));
    const cache = useCacheStore();
    const Comp = defineComponent({
      setup() {
        const r = useResource<string>('inv-k', fetcher, { ttlMs: 60_000 });
        return { r };
      },
      render: () => h('div'),
    });
    const w = mount(Comp);
    await nextTick(); // fetch #0 in flight
    cache.invalidate('inv-k'); // deletes the slot mid-flight
    const p1 = (w.vm as any).r.refresh(); // fetch #1 recreates the slot
    resolvers[1]('fresh');
    await p1;
    await Promise.resolve();
    expect(cache.peek('inv-k')?.value).toBe('fresh');

    resolvers[0]('stale'); // the old #0 resolves LAST
    await Promise.resolve();
    expect((w.vm as any).r.data.value).toBe('fresh');
    expect(cache.peek('inv-k')?.value).toBe('fresh'); // stale did NOT overwrite
    w.unmount();
  });
});
