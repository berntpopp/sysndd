// app/src/stores/cacheStore.ts
//
// In-memory SWR cache for per-source hooks (v11.3 W1).
// Spec: .planning/superpowers/specs/2026-04-26-v11.3-genes-entities-perf-ux-design.md §4.1.3
//
// Holds { value, fetchedAt, ttlMs, pending, abortController, refCount } per stable
// URL key. LRU bounded at 64 entries; eviction skips entries with refCount > 0
// because they are actively subscribed by a mounted component.

import { defineStore } from 'pinia';

const MAX_ENTRIES = 64;

export interface CacheEntry<T = unknown> {
  value: T | null;
  fetchedAt: number;            // ms since epoch when value was written; 0 means "never"
  ttlMs: number;                // 0 means "never stale" (not used by current hooks)
  pending: Promise<T> | null;   // in-flight fetch (shared across subscribers)
  abortController: AbortController | null;
  refCount: number;             // active subscribers
  insertedAt: number;           // for LRU
}

interface CacheState {
  // Plain object keyed by string. We keep insertion order via insertedAt for LRU.
  entries: Record<string, CacheEntry>;
}

export const useCacheStore = defineStore('cache', {
  state: (): CacheState => ({
    entries: Object.create(null),
  }),
  actions: {
    peek<T>(key: string): CacheEntry<T> | null {
      return (this.entries[key] as CacheEntry<T> | undefined) ?? null;
    },

    isStale(key: string): boolean {
      const entry = this.entries[key];
      if (!entry || entry.fetchedAt === 0) return true;
      if (entry.ttlMs === 0) return false;
      return Date.now() - entry.fetchedAt > entry.ttlMs;
    },

    set<T>(key: string, value: T, ttlMs: number): void {
      const existing = this.entries[key];
      this.entries[key] = {
        value,
        fetchedAt: Date.now(),
        ttlMs,
        pending: null,
        abortController: null,
        refCount: existing?.refCount ?? 0,
        insertedAt: existing?.insertedAt ?? Date.now(),
      };
      this.evictIfNeeded();
    },

    beginFetch<T>(key: string, promise: Promise<T>, abortController: AbortController): void {
      const existing = this.entries[key];
      this.entries[key] = {
        value: existing?.value ?? null,
        fetchedAt: existing?.fetchedAt ?? 0,
        ttlMs: existing?.ttlMs ?? 0,
        pending: promise as unknown as Promise<unknown>,
        abortController,
        refCount: existing?.refCount ?? 0,
        insertedAt: existing?.insertedAt ?? Date.now(),
      };
    },

    endFetch(key: string): void {
      const existing = this.entries[key];
      if (!existing) return;
      existing.pending = null;
      existing.abortController = null;
    },

    subscribe(key: string): void {
      const existing = this.entries[key];
      if (!existing) {
        // Pre-create a placeholder so refCount survives the first set/beginFetch.
        this.entries[key] = {
          value: null,
          fetchedAt: 0,
          ttlMs: 0,
          pending: null,
          abortController: null,
          refCount: 1,
          insertedAt: Date.now(),
        };
        return;
      }
      existing.refCount += 1;
    },

    unsubscribe(key: string): void {
      const existing = this.entries[key];
      if (!existing) return;
      existing.refCount = Math.max(0, existing.refCount - 1);
    },

    invalidate(key: string): void {
      delete this.entries[key];
    },

    invalidatePrefix(prefix: string): void {
      for (const key of Object.keys(this.entries)) {
        if (key.startsWith(prefix)) delete this.entries[key];
      }
    },

    evictIfNeeded(): void {
      const keys = Object.keys(this.entries);
      if (keys.length <= MAX_ENTRIES) return;
      // Sort by insertedAt ascending; evict oldest unpinned entry.
      const sorted = keys
        .map((k) => ({ k, t: this.entries[k].insertedAt, r: this.entries[k].refCount }))
        .sort((a, b) => a.t - b.t);
      for (const { k, r } of sorted) {
        if (Object.keys(this.entries).length <= MAX_ENTRIES) break;
        if (r > 0) continue; // skip pinned
        delete this.entries[k];
      }
    },
  },
});
