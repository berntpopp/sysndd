// app/src/composables/useGeneRGD.ts
import axios from 'axios';
import { computed, isRef, type ComputedRef, type Ref } from 'vue';
import { useResource, type ResourceState } from './useResource';

const apiBase = import.meta.env.VITE_API_URL ?? '';

export interface RgdPayload {
  source: 'rgd';
  gene_symbol: string;
  phenotypes: unknown[];
}

export function useGeneRGD(
  symbol: string | Ref<string | null> | ComputedRef<string | null>,
): ResourceState<RgdPayload | null> {
  const symRef = computed<string | null>(() => {
    if (typeof symbol === 'string') return symbol || null;
    if (isRef(symbol)) return symbol.value;
    return null;
  });
  const key = computed<string | null>(() => (symRef.value ? `rgd:${symRef.value}` : null));
  return useResource<RgdPayload | null>(
    key,
    async (signal) => {
      try {
        const res = await axios.get(`${apiBase}/api/external/rgd/phenotypes/${symRef.value}`, {
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
