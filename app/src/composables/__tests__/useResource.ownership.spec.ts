// useResource — S5b request-ownership tests (#535).
//
// Split out of useResource.spec.ts to keep each spec under the 600-line ceiling.
// Covers the cache-slot epoch (cross-consumer ownership), the follow-current-slot
// behavior for a superseded shared-pending subscriber, the loading-ownership
// handoff on key-change/abort, and the global-epoch invalidate-collision guard.
import { setActivePinia, createPinia } from 'pinia';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { defineComponent, h, ref, nextTick } from 'vue';
import { mount, flushPromises } from '@vue/test-utils';
import { useResource } from '../useResource';
import { useCacheStore } from '@/stores/cacheStore';

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

  it('a superseded subscriber follows the current slot instead of applying the stale value', async () => {
    // Consumer B subscribes to A's in-flight fetch; consumer A then supersedes the
    // shared slot with a newer fetch. B must NOT latch the stale subscribed value and
    // must NOT be stuck loading — it follows the newer fetch and ends on the fresh
    // value (regression guard: per-instance generation alone would let B accept the
    // stale value; the slot epoch makes B detect supersession and follow).
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
    resolvers[0]('v0'); // B's subscribed (now-stale) pending resolves
    await Promise.resolve();
    await nextTick();
    // B did NOT latch the stale v0 — it detected supersession and is following #1.
    expect((b.vm as any).r.data.value).not.toBe('v0');

    resolvers[1]('v1'); // the superseding fetch resolves
    await pA;
    await flushPromises();
    expect((a.vm as any).r.data.value).toBe('v1');
    expect((b.vm as any).r.data.value).toBe('v1'); // B followed to the fresh value
    expect((b.vm as any).r.loading.value).toBe(false); // and cleared loading, not stuck
    a.unmount();
    b.unmount();
  });

  it('a superseded subscriber hydrates from cache when the newer fetch already resolved', async () => {
    // Same supersession, but the newer fetch resolves BEFORE the stale subscribed
    // pending. B must adopt the already-cached fresh value directly (no third fetch)
    // and never apply the stale value.
    const resolvers: Array<(v: string) => void> = [];
    const fetcher = vi.fn(() => new Promise<string>((res) => resolvers.push(res)));
    const Comp = defineComponent({
      setup() {
        const r = useResource<string>('hydrate-k', fetcher, { ttlMs: 60_000 });
        return { r };
      },
      render: () => h('div'),
    });
    const a = mount(Comp); // fetch #0
    await nextTick();
    const b = mount(Comp); // B subscribes to #0
    await nextTick();

    const pA = (a.vm as any).r.refresh(); // fetch #1 supersedes
    resolvers[1]('fresh'); // #1 resolves FIRST → cache now holds 'fresh'
    await pA;
    await flushPromises();
    expect(fetcher).toHaveBeenCalledTimes(2); // no third fetch spawned yet

    resolvers[0]('stale'); // B's stale subscribed pending resolves LAST
    await flushPromises();
    expect(fetcher).toHaveBeenCalledTimes(2); // B hydrated from cache, did not refetch
    expect((b.vm as any).r.data.value).toBe('fresh'); // adopted the cached fresh value
    expect((b.vm as any).r.loading.value).toBe(false);
    a.unmount();
    b.unmount();
  });

  it('a superseded STARTER (owner) follows the current slot instead of applying its stale value', async () => {
    // Consumer A OWNS fetch #0; consumer B (a subscriber) then supersedes the shared
    // slot with a forced fetch #1. #1 resolves first; when A's owned #0 resolves last
    // it must NOT write its stale value into A's refs (consumerCurrent stays true, but
    // the slot epoch advanced) — A follows the current slot to the fresh value. This
    // guards the owner/starter path symmetrically with the subscriber path.
    const resolvers: Array<(v: string) => void> = [];
    const fetcher = vi.fn(() => new Promise<string>((res) => resolvers.push(res)));
    const Comp = defineComponent({
      setup() {
        const r = useResource<string>('owner-k', fetcher, { ttlMs: 60_000 });
        return { r };
      },
      render: () => h('div'),
    });
    const a = mount(Comp); // A owns fetch #0
    await nextTick();
    const b = mount(Comp); // B subscribes to #0
    await nextTick();

    const pB = (b.vm as any).r.refresh(); // B supersedes the slot with fetch #1
    resolvers[1]('fresh'); // #1 resolves FIRST → cache holds 'fresh'
    await pB;
    await flushPromises();
    expect((b.vm as any).r.data.value).toBe('fresh');

    resolvers[0]('stale'); // A's OWNED #0 resolves LAST
    await flushPromises();
    expect((a.vm as any).r.data.value).toBe('fresh'); // A followed, did NOT apply 'stale'
    expect((a.vm as any).r.data.value).not.toBe('stale');
    expect((a.vm as any).r.loading.value).toBe(false);
    const cache = useCacheStore();
    expect(cache.peek('owner-k')?.value).toBe('fresh'); // stale owner did not poison cache
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
