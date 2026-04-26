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
