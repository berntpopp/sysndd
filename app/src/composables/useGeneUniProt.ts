// app/src/composables/useGeneUniProt.ts
import { computed, isRef, type ComputedRef, type Ref } from 'vue';
import { isApiError } from '@/api/client';
import { getUniprotDomains, type UniProtData } from '@/api/external';
import { useResource, type ResourceState } from './useResource';

export function useGeneUniProt(
  symbol: string | Ref<string | null> | ComputedRef<string | null>,
): ResourceState<UniProtData | null> {
  const symRef = computed<string | null>(() => {
    if (typeof symbol === 'string') return symbol || null;
    if (isRef(symbol)) return symbol.value;
    return null;
  });
  const key = computed<string | null>(() => (symRef.value ? `uniprot:${symRef.value}` : null));
  return useResource<UniProtData | null>(
    key,
    async () => {
      try {
        const data = await getUniprotDomains(symRef.value!);
        return data?.domains ? data : null;
      } catch (err) {
        if (isApiError(err) && err.response?.status === 404) return null;
        throw err;
      }
    },
    { ttlMs: 5 * 60_000 },
  );
}
