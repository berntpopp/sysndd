// app/src/composables/useResource.ts
//
// In-house SWR composable. Spec: §4.1.1 + §4.1.2.
//
// On mount: serve cache value (if any) immediately; revalidate in background if
// the entry is stale; dedupe in-flight via cacheStore's pending promise. Multiple
// consumers with the same key share one fetch via ref-counted subscription; only
// the last unsubscriber aborts the underlying fetch. Cancelled consumers do not
// write back to their data ref even if the shared promise eventually resolves
// (the cacheStore still records the value so a later mount sees fresh data).

import { computed, isRef, onBeforeUnmount, ref, watch, type ComputedRef, type Ref } from 'vue';
import { useCacheStore } from '@/stores/cacheStore';

export type ResourceKey = string;
export type ResourceFetcher<T> = (signal: AbortSignal) => Promise<T>;

export interface ResourceOptions {
  ttlMs?: number; // default 60_000
  staleWhileRevalidate?: boolean; // default true
}

export interface ResourceState<T> {
  data: Ref<T | null>;
  error: Ref<Error | null>;
  loading: Ref<boolean>;
  isStale: Ref<boolean>;
  refresh: () => Promise<void>;
  abort: () => void;
}

const DEFAULT_TTL = 60_000;

export function useResource<T>(
  keyInput: ResourceKey | null | ComputedRef<ResourceKey | null> | Ref<ResourceKey | null>,
  fetcher: ResourceFetcher<T>,
  opts: ResourceOptions = {}
): ResourceState<T> {
  const { ttlMs = DEFAULT_TTL, staleWhileRevalidate = true } = opts;
  const cache = useCacheStore();

  const data = ref<T | null>(null) as Ref<T | null>;
  const error = ref<Error | null>(null);
  const loading = ref(false);
  const isStale = ref(false);

  // A mutable token so that a fetcher resolution after key-change is ignored.
  let activeToken = Symbol('resource');
  let activeKey: ResourceKey | null = null;

  const keyRef = computed<ResourceKey | null>(() => {
    if (keyInput === null) return null;
    if (typeof keyInput === 'string') return keyInput;
    if (isRef(keyInput)) {
      const v = keyInput.value;
      return typeof v === 'string' ? v : null;
    }
    return null;
  });

  function readFromCache(key: ResourceKey): { hasEntry: boolean; value: T | null; fresh: boolean } {
    const entry = cache.peek<T>(key);
    // Distinguish "no resolved entry yet" from "entry resolved to null". A
    // legitimate cached null (e.g. a 404 that the fetcher mapped to null) must
    // be served as a hit so we don't re-fetch on every mount.
    if (!entry || entry.fetchedAt === 0) {
      return { hasEntry: false, value: null, fresh: false };
    }
    return { hasEntry: true, value: entry.value, fresh: !cache.isStale(key) };
  }

  async function doFetch(key: ResourceKey, force: boolean, background = false): Promise<void> {
    const myToken = activeToken;
    // If another consumer already has a fetch in flight for this key, subscribe to it.
    const existing = cache.peek<T>(key);
    if (existing?.pending && !force) {
      // Capture the slot epoch of the pending we subscribe to. If a newer fetch
      // (any consumer) replaces the slot before this resolves, its epoch advances
      // and we must not apply this now-stale shared value to our consumer refs.
      const myEpoch = existing.epoch;
      const stillOurs = (): boolean =>
        myToken === activeToken && cache.peek<T>(key)?.epoch === myEpoch;
      try {
        if (!background) loading.value = true;
        const value = (await existing.pending) as T;
        if (!stillOurs()) return; // consumer switched keys or the slot was superseded
        data.value = value;
        error.value = null;
        isStale.value = false;
      } catch (e) {
        if (!stillOurs()) return;
        error.value = e instanceof Error ? e : new Error(String(e));
      } finally {
        if (stillOurs() && !background) loading.value = false;
      }
      return;
    }

    const ac = new AbortController();
    const promise = (async () => {
      return await fetcher(ac.signal);
    })();
    cache.beginFetch<T>(key, promise, ac); // advances this slot's epoch
    const myEpoch = cache.peek<T>(key)?.epoch;
    // The slot epoch is the ownership signal for BOTH the shared cache write and
    // the consumer refs. A newer `beginFetch` (any consumer) advances the epoch, so
    // a stale fetch declines to write the cache. Crucially, `endFetch()` (e.g. the
    // abort cleanup when a consumer switches keys) preserves the epoch, so a lone
    // in-flight fetch still records its value for a future mount — unlike a
    // `pending === promise` check, which the abort would have nulled out.
    const slotCurrent = (): boolean => cache.peek<T>(key)?.epoch === myEpoch;
    const isLatest = (): boolean => myToken === activeToken && slotCurrent();
    if (!background) loading.value = true;
    try {
      const value = await promise;
      if (slotCurrent()) cache.set<T>(key, value, ttlMs); // only the latest fetch records
      if (!isLatest()) return;
      data.value = value;
      error.value = null;
      isStale.value = false;
    } catch (e) {
      if (slotCurrent()) cache.endFetch(key);
      if (!isLatest()) return;
      error.value = e instanceof Error ? e : new Error(String(e));
    } finally {
      if (slotCurrent()) cache.endFetch(key);
      if (isLatest() && !background) loading.value = false;
    }
  }

  async function activate(key: ResourceKey | null): Promise<void> {
    activeToken = Symbol('resource');
    if (activeKey !== null && activeKey !== key) {
      // Unsubscribe from the previous key.
      cache.unsubscribe(activeKey);
      const prev = cache.peek(activeKey);
      if (prev && prev.refCount === 0 && prev.abortController) {
        prev.abortController.abort();
        cache.endFetch(activeKey);
      }
    }
    activeKey = key;
    if (key === null) {
      data.value = null;
      error.value = null;
      loading.value = false;
      isStale.value = false;
      return;
    }
    cache.subscribe(key);
    const { hasEntry, value, fresh } = readFromCache(key);
    if (hasEntry) {
      // Cache hit (including legitimate cached null): serve it immediately.
      // Take ownership of `loading`: a superseded foreground fetch on the previous
      // key can no longer clear it (its activeToken is stale), so clear it here.
      loading.value = false;
      data.value = value;
      isStale.value = !fresh;
      if (!fresh && staleWhileRevalidate) {
        // SWR: revalidate in background; loading stays false because we already
        // have a (stale) value.
        void doFetch(key, true, true);
      }
    } else {
      await doFetch(key, false);
    }
  }

  function refresh(): Promise<void> {
    if (activeKey === null) return Promise.resolve();
    // Force a fresh fetch without invalidating the entry — invalidate would
    // drop refCount/pending/abortController for OTHER subscribers of the same
    // key. doFetch(force=true) bypasses the existing-pending dedupe and the
    // success path overwrites the cached value via cache.set() (which preserves
    // refCount and lastAccessAt).
    return doFetch(activeKey, true);
  }

  function abort(): void {
    if (activeKey === null) return;
    cache.unsubscribe(activeKey);
    const entry = cache.peek(activeKey);
    if (entry && entry.refCount === 0 && entry.abortController) {
      entry.abortController.abort();
      cache.endFetch(activeKey);
    }
    activeKey = null;
    activeToken = Symbol('resource');
    // A foreground fetch invalidated by this abort can no longer clear `loading`.
    loading.value = false;
  }

  // Initial activation + key-change watcher.
  watch(
    keyRef,
    (next) => {
      void activate(next);
    },
    { immediate: true }
  );

  onBeforeUnmount(() => {
    abort();
  });

  return { data, error, loading, isStale, refresh, abort };
}
