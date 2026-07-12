// app/src/stores/cacheStore.ts
//
// In-memory SWR cache for per-source hooks (v11.3 W1).
// Spec: .planning/superpowers/specs/2026-04-26-v11.3-genes-entities-perf-ux-design.md §4.1.3
//
// Holds { value, fetchedAt, ttlMs, pending, abortController, refCount } per stable
// URL key. LRU bounded at 64 entries; eviction skips entries with refCount > 0
// because they are actively subscribed by a mounted component. The `lastAccessAt`
// field is updated on every peek/set/subscribe so eviction picks the genuinely
// least-recently-used entry, not just the oldest insertion.

import { defineStore } from 'pinia';

const MAX_ENTRIES = 64;

export interface CacheEntry<T = unknown> {
  value: T | null;
  fetchedAt: number; // ms since epoch when value was written; 0 means "never"
  ttlMs: number; // 0 means "never stale" (not used by current hooks)
  pending: Promise<T> | null; // in-flight fetch (shared across subscribers)
  abortController: AbortController | null;
  refCount: number; // active subscribers
  insertedAt: number; // first creation time (informational)
  lastAccessAt: number; // for true LRU eviction — touched on every read/write
  // Monotonic per-key fetch epoch, bumped on every beginFetch() and preserved by
  // set/endFetch/subscribe. Consumers of a shared slot capture the epoch when they
  // start awaiting; a later beginFetch (a newer fetch replacing the slot) advances
  // it, so a stale consumer knows not to apply an out-of-date result even though it
  // shares one activeToken with the newer fetch (#535 S5b cross-consumer ownership).
  epoch: number;
}

interface CacheState {
  // Plain object keyed by string. We keep insertion order via insertedAt for LRU.
  entries: Record<string, CacheEntry>;
  // Globally-monotonic, never-reused fetch epoch allocator. Using a store-wide
  // counter (rather than a per-key increment) means invalidate()/invalidatePrefix()
  // — which delete an entry and let the next fetch recreate it — can never make a
  // recreated slot's epoch collide with an in-flight older fetch's captured epoch.
  epochCounter: number;
}

export const useCacheStore = defineStore('cache', {
  state: (): CacheState => ({
    entries: Object.create(null),
    epochCounter: 0,
  }),
  actions: {
    peek<T>(key: string): CacheEntry<T> | null {
      const entry = this.entries[key] as CacheEntry<T> | undefined;
      if (!entry) return null;
      // True LRU: every read counts as a touch.
      entry.lastAccessAt = Date.now();
      return entry;
    },

    isStale(key: string): boolean {
      const entry = this.entries[key];
      if (!entry || entry.fetchedAt === 0) return true;
      if (entry.ttlMs === 0) return false;
      return Date.now() - entry.fetchedAt > entry.ttlMs;
    },

    set<T>(key: string, value: T, ttlMs: number): void {
      const existing = this.entries[key];
      const now = Date.now();
      this.entries[key] = {
        value,
        fetchedAt: now,
        ttlMs,
        pending: null,
        abortController: null,
        refCount: existing?.refCount ?? 0,
        insertedAt: existing?.insertedAt ?? now,
        lastAccessAt: now,
        epoch: existing?.epoch ?? 0,
      };
      this.evictIfNeeded();
    },

    beginFetch<T>(key: string, promise: Promise<T>, abortController: AbortController): void {
      const existing = this.entries[key];
      const now = Date.now();
      this.entries[key] = {
        value: existing?.value ?? null,
        fetchedAt: existing?.fetchedAt ?? 0,
        ttlMs: existing?.ttlMs ?? 0,
        pending: promise as unknown as Promise<unknown>,
        abortController,
        refCount: existing?.refCount ?? 0,
        insertedAt: existing?.insertedAt ?? now,
        lastAccessAt: now,
        // Allocate a fresh globally-unique epoch so a stale consumer of the previous
        // pending promise (or of a since-invalidated slot) can detect supersession.
        epoch: (this.epochCounter += 1),
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
      const now = Date.now();
      if (!existing) {
        // Pre-create a placeholder so refCount survives the first set/beginFetch.
        this.entries[key] = {
          value: null,
          fetchedAt: 0,
          ttlMs: 0,
          pending: null,
          abortController: null,
          refCount: 1,
          insertedAt: now,
          lastAccessAt: now,
          epoch: 0,
        };
        return;
      }
      existing.refCount += 1;
      existing.lastAccessAt = now;
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
      // True LRU: sort by lastAccessAt ascending; evict the
      // least-recently-touched unpinned entry first.
      const sorted = keys
        .map((k) => ({ k, t: this.entries[k].lastAccessAt, r: this.entries[k].refCount }))
        .sort((a, b) => a.t - b.t);
      for (const { k, r } of sorted) {
        if (Object.keys(this.entries).length <= MAX_ENTRIES) break;
        if (r > 0) continue; // skip pinned
        delete this.entries[k];
      }
    },
  },
});
