// app/src/composables/useEntityMappings.ts
//
// SWR composable for cross-ontology disease mapping data.
//
// Mirrors the pattern of useEntityPublications.ts: wrap useResource with a
// stable per-entity key so multiple component mounts sharing the same entity
// deduplicate the fetch and share the cached result.

import { computed, isRef, type ComputedRef, type Ref } from 'vue';
import { getEntityMappings } from '@/api/disease-mappings';
import type { DiseaseMappingResponse } from '@/api/disease-mappings';
import { useResource, type ResourceState } from './useResource';

/**
 * Fetch and cache cross-ontology disease mappings for the given entity.
 *
 * Accepts a plain value, a Vue `Ref`, or a `ComputedRef`. Passing `null`
 * (or a ref whose value is `null`) disables the fetch and returns idle state.
 *
 * @example
 * ```ts
 * const { data, loading, error } = useEntityMappings(entityId);
 * ```
 */
export function useEntityMappings(
  entityId: string | number | Ref<string | number | null> | ComputedRef<string | number | null>
): ResourceState<DiseaseMappingResponse | null> {
  const idRef = computed<string | null>(() => {
    let v: string | number | null;
    if (isRef(entityId)) v = entityId.value;
    else v = entityId as string | number;
    return v === null || v === undefined || v === '' ? null : String(v);
  });

  const key = computed<string | null>(() =>
    idRef.value ? `entity-mappings:${idRef.value}` : null
  );

  return useResource<DiseaseMappingResponse | null>(
    key,
    async (signal) =>
      (await getEntityMappings(idRef.value!, {
        signal,
      })) as DiseaseMappingResponse,
    { ttlMs: 60_000 }
  );
}
