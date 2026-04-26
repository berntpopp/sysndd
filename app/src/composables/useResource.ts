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

import {
  computed,
  isRef,
  onBeforeUnmount,
  ref,
  watch,
  type ComputedRef,
  type Ref,
} from 'vue';
import { useCacheStore } from '@/stores/cacheStore';

export type ResourceKey = string;
export type ResourceFetcher<T> = (signal: AbortSignal) => Promise<T>;

export interface ResourceOptions {
  ttlMs?: number;                 // default 60_000
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
  opts: ResourceOptions = {},
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
    if (typeof keyInput === 'string' || keyInput === null) return keyInput;
    if (isRef(keyInput)) return keyInput.value;
    return null;
  });

  function readFromCache(key: ResourceKey): { value: T | null; fresh: boolean } {
    const entry = cache.peek<T>(key);
    if (!entry || entry.fetchedAt === 0) return { value: null, fresh: false };
    return { value: entry.value, fresh: !cache.isStale(key) };
  }

  async function doFetch(key: ResourceKey, force: boolean, background = false): Promise<void> {
    const myToken = activeToken;
    // If another consumer already has a fetch in flight for this key, subscribe to it.
    const existing = cache.peek<T>(key);
    if (existing?.pending && !force) {
      try {
        if (!background) loading.value = true;
        const value = (await existing.pending) as T;
        if (myToken !== activeToken) return; // consumer switched keys
        data.value = value;
        error.value = null;
        isStale.value = false;
      } catch (e) {
        if (myToken !== activeToken) return;
        error.value = e instanceof Error ? e : new Error(String(e));
      } finally {
        if (myToken === activeToken && !background) loading.value = false;
      }
      return;
    }

    const ac = new AbortController();
    const promise = (async () => {
      return await fetcher(ac.signal);
    })();
    cache.beginFetch<T>(key, promise, ac);
    if (!background) loading.value = true;
    try {
      const value = await promise;
      // Always write to cache so a later mount sees the value.
      cache.set<T>(key, value, ttlMs);
      if (myToken !== activeToken) return;
      data.value = value;
      error.value = null;
      isStale.value = false;
    } catch (e) {
      cache.endFetch(key);
      if (myToken !== activeToken) return;
      error.value = e instanceof Error ? e : new Error(String(e));
    } finally {
      cache.endFetch(key);
      if (myToken === activeToken && !background) loading.value = false;
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
    const { value, fresh } = readFromCache(key);
    if (value !== null) {
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
    cache.invalidate(activeKey);
    // Re-subscribe because invalidate dropped the entry (and its refCount).
    cache.subscribe(activeKey);
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
  }

  // Initial activation + key-change watcher.
  watch(
    keyRef,
    (next) => {
      void activate(next);
    },
    { immediate: true },
  );

  onBeforeUnmount(() => {
    abort();
  });

  return { data, error, loading, isStale, refresh, abort };
}
