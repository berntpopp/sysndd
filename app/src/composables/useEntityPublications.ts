// app/src/composables/useEntityPublications.ts
import { computed, isRef, type ComputedRef, type Ref } from 'vue';
import { getEntityPublications } from '@/api/entity';
import { useResource, type ResourceState } from './useResource';

// Returns the FULL publications array. Consumers split by publication_type
// (additional_references vs gene_review) on the client side.
export function useEntityPublications(
  entityId: string | number | Ref<string | number | null> | ComputedRef<string | number | null>
): ResourceState<unknown[]> {
  const idRef = computed<string | null>(() => {
    let v: string | number | null;
    if (isRef(entityId)) v = entityId.value;
    else v = entityId as string | number;
    return v === null || v === undefined || v === '' ? null : String(v);
  });
  const key = computed<string | null>(() => (idRef.value ? `entity-pubs:${idRef.value}` : null));
  return useResource<unknown[]>(
    key,
    async (signal) => (await getEntityPublications(idRef.value!, {}, { signal })) as unknown[],
    { ttlMs: 60_000 }
  );
}
