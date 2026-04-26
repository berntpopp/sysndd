// app/src/composables/useGeneMGI.ts
import axios from 'axios';
import { computed, isRef, type ComputedRef, type Ref } from 'vue';
import { useResource, type ResourceState } from './useResource';

const apiBase = import.meta.env.VITE_API_URL ?? '';

export interface MgiPayload {
  source: 'mgi';
  gene_symbol: string;
  phenotypes: unknown[];
  counts?: Record<string, number>;
}

export function useGeneMGI(
  symbol: string | Ref<string | null> | ComputedRef<string | null>,
): ResourceState<MgiPayload | null> {
  const symRef = computed<string | null>(() => {
    if (typeof symbol === 'string') return symbol || null;
    if (isRef(symbol)) return symbol.value;
    return null;
  });
  const key = computed<string | null>(() => (symRef.value ? `mgi:${symRef.value}` : null));
  return useResource<MgiPayload | null>(
    key,
    async (signal) => {
      try {
        const res = await axios.get(`${apiBase}/api/external/mgi/phenotypes/${symRef.value}`, {
          withCredentials: true,
          signal,
        });
        return res.data ?? null;
      } catch (err) {
        if (axios.isAxiosError(err) && err.response?.status === 404) return null;
        throw err;
      }
    },
    { ttlMs: 5 * 60_000 },
  );
}
