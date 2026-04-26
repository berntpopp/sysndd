import { setActivePinia, createPinia } from 'pinia';
import { beforeEach, describe, expect, it, vi } from 'vitest';
import { useCacheStore } from '../cacheStore';

describe('cacheStore', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  it('returns null for an empty key', () => {
    const store = useCacheStore();
    expect(store.peek('missing')).toBeNull();
  });

  it('stores and retrieves a value', () => {
    const store = useCacheStore();
    store.set('k', { hello: 'world' }, 60_000);
    const entry = store.peek('k');
    expect(entry).not.toBeNull();
    expect(entry!.value).toEqual({ hello: 'world' });
    expect(entry!.fetchedAt).toBeGreaterThan(0);
    expect(entry!.ttlMs).toBe(60_000);
    expect(entry!.refCount).toBe(0);
    expect(entry!.pending).toBeNull();
  });

  it('reports a fresh entry as not stale within TTL', () => {
    const store = useCacheStore();
    vi.useFakeTimers();
    vi.setSystemTime(new Date('2026-04-26T12:00:00Z'));
    store.set('k', 1, 60_000);
    vi.advanceTimersByTime(30_000);
    expect(store.isStale('k')).toBe(false);
    vi.advanceTimersByTime(31_000);
    expect(store.isStale('k')).toBe(true);
    vi.useRealTimers();
  });

  it('reports an unknown key as stale', () => {
    const store = useCacheStore();
    expect(store.isStale('missing')).toBe(true);
  });

  it('reference-counts subscribers', () => {
    const store = useCacheStore();
    store.set('k', 1, 60_000);
    expect(store.peek('k')!.refCount).toBe(0);
    store.subscribe('k');
    store.subscribe('k');
    expect(store.peek('k')!.refCount).toBe(2);
    store.unsubscribe('k');
    expect(store.peek('k')!.refCount).toBe(1);
    store.unsubscribe('k');
    expect(store.peek('k')!.refCount).toBe(0);
  });

  it('attaches and reads pending promise + AbortController', () => {
    const store = useCacheStore();
    const ac = new AbortController();
    const p = Promise.resolve(42);
    store.beginFetch('k', p, ac);
    const entry = store.peek('k');
    expect(entry!.pending).toBe(p);
    expect(entry!.abortController).toBe(ac);
  });

  it('clears pending and abortController on endFetch', () => {
    const store = useCacheStore();
    const ac = new AbortController();
    store.beginFetch('k', Promise.resolve(1), ac);
    store.endFetch('k');
    const entry = store.peek('k');
    expect(entry!.pending).toBeNull();
    expect(entry!.abortController).toBeNull();
  });

  it('invalidates by exact key', () => {
    const store = useCacheStore();
    store.set('a', 1, 60_000);
    store.set('b', 2, 60_000);
    store.invalidate('a');
    expect(store.peek('a')).toBeNull();
    expect(store.peek('b')).not.toBeNull();
  });

  it('invalidates by prefix', () => {
    const store = useCacheStore();
    store.set('gene:GRIN2B', 1, 60_000);
    store.set('gene:MECP2', 2, 60_000);
    store.set('entity:304', 3, 60_000);
    store.invalidatePrefix('gene:');
    expect(store.peek('gene:GRIN2B')).toBeNull();
    expect(store.peek('gene:MECP2')).toBeNull();
    expect(store.peek('entity:304')).not.toBeNull();
  });

  it('LRU-evicts oldest entry when over the cap', () => {
    const store = useCacheStore();
    // The store caps at 64; we set 65 to force one eviction.
    for (let i = 0; i < 65; i++) {
      store.set(`k${i}`, i, 60_000);
    }
    expect(store.peek('k0')).toBeNull(); // oldest evicted
    expect(store.peek('k64')).not.toBeNull();
  });

  it('LRU eviction skips entries with refCount > 0', () => {
    const store = useCacheStore();
    store.set('keep', 'pinned', 60_000);
    store.subscribe('keep'); // refCount = 1
    for (let i = 0; i < 64; i++) {
      store.set(`k${i}`, i, 60_000);
    }
    // 'keep' should still be there even though it's the oldest.
    expect(store.peek('keep')).not.toBeNull();
  });
});
