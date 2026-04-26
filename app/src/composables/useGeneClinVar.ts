// app/src/composables/useGeneClinVar.ts
import axios from 'axios';
import { computed, isRef, type ComputedRef, type Ref } from 'vue';
import { useResource, type ResourceState } from './useResource';
import type { ClinVarVariant } from '@/types';

const apiBase = import.meta.env.VITE_API_URL ?? '';

export function useGeneClinVar(
  symbol: string | Ref<string | null> | ComputedRef<string | null>,
): ResourceState<ClinVarVariant[] | null> {
  const symRef = computed<string | null>(() => {
    if (typeof symbol === 'string') return symbol || null;
    if (isRef(symbol)) return symbol.value;
    return null;
  });
  const key = computed<string | null>(() => (symRef.value ? `clinvar:${symRef.value}` : null));
  return useResource<ClinVarVariant[] | null>(
    key,
    async (signal) => {
      try {
        const res = await axios.get(`${apiBase}/api/external/gnomad/variants/${symRef.value}`, {
          withCredentials: true,
          signal,
        });
        return res.data?.variants ?? null;
      } catch (err) {
        if (axios.isAxiosError(err) && err.response?.status === 404) return null;
        throw err;
      }
    },
    { ttlMs: 5 * 60_000 },
  );
}
