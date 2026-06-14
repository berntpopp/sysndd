/**
 * Tiny bounded LRU cache backed by a Map.
 *
 * A `Map` preserves insertion order, so the first key is the oldest. We refresh
 * recency on every hit (delete + re-set) so frequently-used entries are not
 * evicted as "oldest", and evict the oldest entry once the size limit is hit.
 * Used to bound the PubTator annotation-parse cache and the gene-symbol split
 * cache so long browsing sessions cannot grow them without limit.
 */
export interface LruCache<K, V> {
  get(key: K): V | undefined;
  set(key: K, value: V): void;
  clear(): void;
  readonly size: number;
}

export function createLruCache<K, V>(limit: number): LruCache<K, V> {
  const map = new Map<K, V>();
  return {
    get(key: K): V | undefined {
      const value = map.get(key);
      if (value !== undefined) {
        // Refresh recency: move this key to the newest position.
        map.delete(key);
        map.set(key, value);
      }
      return value;
    },
    set(key: K, value: V): void {
      if (map.has(key)) map.delete(key);
      else if (map.size >= limit) {
        const oldest = map.keys().next().value;
        if (oldest !== undefined) map.delete(oldest);
      }
      map.set(key, value);
    },
    clear(): void {
      map.clear();
    },
    get size(): number {
      return map.size;
    },
  };
}
